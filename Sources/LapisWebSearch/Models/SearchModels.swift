import Foundation

/// A normalized discovery result. The library never downloads this URL.
public struct SearchResult: Sendable, Equatable, Encodable {
    public let title: String
    public let url: URL
    public let snippet: String
    public let provider: String
    /// One-based position in the provider's original response, before filtering.
    public let originalPosition: Int
    /// Only a provider-confirmed publication date; feed retrieval dates are not publication dates.
    public let publishedAt: Date?
    public let metadata: [String: String]?

    public init(
        title: String, url: URL, snippet: String, provider: String, originalPosition: Int,
        publishedAt: Date? = nil, metadata: [String: String]? = nil
    ) throws {
        guard let normalized = URLNormalizer.normalize(url), !TextCleanup.clean(title).isEmpty,
            !provider.isEmpty, originalPosition > 0
        else { throw SearchError(.invalidResponse) }
        self.title = TextCleanup.clean(title)
        self.url = normalized
        self.snippet = TextCleanup.clean(snippet)
        self.provider = provider
        self.originalPosition = originalPosition
        self.publishedAt = publishedAt
        self.metadata = metadata
    }
}

/// Immutable per-search settings. Unsupported settings fail explicitly at the provider.
public enum SearchStrategy: String, Sendable, Codable {
    case sequential
    /// Race a bounded number of configured providers and return the first usable set; cancel losers.
    case firstSuccess
}

public enum SearchTimeRange: String, Sendable, Codable {
    case day, week, month, year
}

/// Concurrency limits apply per client/coordinator, including identical-request sharing.
public struct SearchConfiguration: Sendable {
    public let maximumConcurrentSearches: Int
    public let maximumConcurrentRequestsPerProvider: Int
    public let maximumPendingSearches: Int
    public let coalesceIdenticalRequests: Bool
    /// Requires explicit evidence in each provider's deployment-specific usage assessment.
    public let providerPolicy: SearchProviderPolicy
    public init(
        maximumConcurrentSearches: Int = 4, maximumConcurrentRequestsPerProvider: Int = 1,
        maximumPendingSearches: Int = 64, coalesceIdenticalRequests: Bool = true,
        providerPolicy: SearchProviderPolicy = .explicitSelection
    ) {
        self.maximumConcurrentSearches = maximumConcurrentSearches
        self.maximumConcurrentRequestsPerProvider = maximumConcurrentRequestsPerProvider
        self.maximumPendingSearches = maximumPendingSearches
        self.coalesceIdenticalRequests = coalesceIdenticalRequests
        self.providerPolicy = providerPolicy
    }
}

public struct SearchOptions: Sendable, Hashable {
    public let limit: Int
    /// Overall deadline, including fallback, in seconds. Must be 0 < timeout <= 300.
    public let timeout: TimeInterval
    /// BCP-47 market identifier, such as es-ES. Only providers advertising locale support accept it.
    public let locale: String?
    public let safeSearch: Bool?
    public let fallback: Bool
    public let strategy: SearchStrategy
    public let maximumParallelProviders: Int
    /// Optional budget for each admitted provider, bounded by the remaining overall deadline.
    public let providerTimeout: TimeInterval?
    /// ISO 3166-1 alpha-2 country. Distinct from language/locale; never inferred from the query.
    public let country: String?
    public let timeRange: SearchTimeRange?

    public init(
        limit: Int = 5, timeout: TimeInterval = 20, locale: String? = nil,
        safeSearch: Bool? = nil, fallback: Bool = true, strategy: SearchStrategy = .sequential,
        maximumParallelProviders: Int = 2, providerTimeout: TimeInterval? = nil,
        country: String? = nil, timeRange: SearchTimeRange? = nil
    ) {
        self.limit = limit
        self.timeout = timeout
        self.locale = locale
        self.safeSearch = safeSearch
        self.fallback = fallback
        self.strategy = strategy
        self.maximumParallelProviders = maximumParallelProviders
        self.providerTimeout = providerTimeout
        self.country = country?.uppercased()
        self.timeRange = timeRange
    }
}

/// Passed to independent provider implementations. Providers must cooperate with task cancellation.
public struct SearchRequest: Sendable, Hashable {
    public let query: String
    public let options: SearchOptions

    public init(query: String, options: SearchOptions = .init()) throws {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, query.utf8.count <= 4096, query.count <= 500,
            !query.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
            (1...100).contains(options.limit), options.timeout.isFinite,
            options.timeout > 0, options.timeout <= 300,
            (1...4).contains(options.maximumParallelProviders),
            options.strategy != .firstSuccess || options.fallback,
            options.providerTimeout.map({ $0.isFinite && $0 > 0 && $0 <= 300 }) ?? true
        else { throw SearchError(.invalidInput) }
        if let locale = options.locale {
            guard locale.count <= 35, !locale.isEmpty,
                locale.unicodeScalars.allSatisfy({
                    CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-")
                        .contains($0)
                })
            else { throw SearchError(.invalidInput) }
        }
        if let country = options.country {
            guard country.utf8.count == 2, country.utf8.allSatisfy({ (65...90).contains($0) })
            else { throw SearchError(.invalidInput) }
        }
        self.query = query
        self.options = options
    }
}

public struct ProviderCapabilities: Sendable {
    public let locale: Bool
    public let safeSearch: Bool
    public let country: Bool
    public let timeRange: Bool
    public init(locale: Bool = false, safeSearch: Bool = false, country: Bool = false, timeRange: Bool = false) {
        self.locale = locale
        self.safeSearch = safeSearch
        self.country = country
        self.timeRange = timeRange
    }
}

/// Explicit zero-result responses are distinct from a malformed or empty result list.
public enum ProviderResponse: Sendable {
    case results([SearchResult], httpStatus: Int? = nil)
    case noResults(httpStatus: Int? = nil)
}

public protocol SearchProvider: Sendable {
    var identifier: String { get }
    var capabilities: ProviderCapabilities { get }
    var usage: ProviderUsage { get }
    func search(_ request: SearchRequest) async throws -> ProviderResponse
}

extension SearchProvider {
    public var capabilities: ProviderCapabilities { .init() }
    /// Custom adapters are unverified unless their author supplies an assessment and evidence.
    public var usage: ProviderUsage { .init(status: .unverified) }
}

/// Local, query-free diagnostics. No provider body or transport error text is retained.
public struct ProviderAttempt: Sendable, Encodable {
    public let provider: String
    public let startedAt: Date
    public let completedAt: Date
    public let duration: TimeInterval
    public let httpStatus: Int?
    public let validResultCount: Int
    public let error: SearchError.Code?
    public let wasFallback: Bool
    public let skipped: Bool
    public let retryAfter: Date?
    /// Admission wait, already included in duration.
    public internal(set) var queueDuration: TimeInterval = 0
}

/// Sanitized execution settings, excluding query text, headers and endpoint/session identifiers.
public struct SearchDiagnostics: Sendable, Encodable {
    public let limit: Int
    public let timeout: TimeInterval
    public let providerTimeout: TimeInterval?
    public let strategy: SearchStrategy
    public let maximumParallelProviders: Int
    public let locale: String?
    public let country: String?
    public let timeRange: SearchTimeRange?
    public let safeSearch: Bool?
    public let providers: [String]
    public let providerPolicy: SearchProviderPolicy
    init(_ options: SearchOptions, providers: [String], policy: SearchProviderPolicy = .explicitSelection) {
        limit = options.limit
        timeout = options.timeout
        providerTimeout = options.providerTimeout
        strategy = options.strategy
        maximumParallelProviders = options.maximumParallelProviders
        locale = options.locale
        country = options.country
        timeRange = options.timeRange
        safeSearch = options.safeSearch
        self.providers = providers
        providerPolicy = policy
    }
}

public struct SearchResponse: Sendable, Encodable {
    public let results: [SearchResult]
    public let attempts: [ProviderAttempt]
    public internal(set) var configuration: SearchDiagnostics? = nil
    public internal(set) var duration: TimeInterval = 0
    public internal(set) var wasCoalesced: Bool = false
}
