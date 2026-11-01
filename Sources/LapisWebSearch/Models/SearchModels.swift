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
public struct SearchOptions: Sendable {
    public let limit: Int
    /// Overall deadline, including fallback, in seconds. Must be 0 < timeout <= 300.
    public let timeout: TimeInterval
    /// BCP-47 market identifier, such as es-ES. Only providers advertising locale support accept it.
    public let locale: String?
    public let safeSearch: Bool?
    public let fallback: Bool

    public init(
        limit: Int = 5, timeout: TimeInterval = 20, locale: String? = nil,
        safeSearch: Bool? = nil, fallback: Bool = true
    ) {
        self.limit = limit
        self.timeout = timeout
        self.locale = locale
        self.safeSearch = safeSearch
        self.fallback = fallback
    }
}

/// Passed to independent provider implementations. Providers must cooperate with task cancellation.
public struct SearchRequest: Sendable {
    public let query: String
    public let options: SearchOptions

    public init(query: String, options: SearchOptions = .init()) throws {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, query.count <= 500,
            !query.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
            (1...100).contains(options.limit), options.timeout.isFinite,
            options.timeout > 0, options.timeout <= 300
        else { throw SearchError(.invalidInput) }
        if let locale = options.locale {
            guard locale.count <= 35, !locale.isEmpty,
                locale.unicodeScalars.allSatisfy({
                    CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-")
                        .contains($0)
                })
            else { throw SearchError(.invalidInput) }
        }
        self.query = query
        self.options = options
    }
}

public struct ProviderCapabilities: Sendable {
    public let locale: Bool
    public let safeSearch: Bool
    public init(locale: Bool = false, safeSearch: Bool = false) {
        self.locale = locale
        self.safeSearch = safeSearch
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
    func search(_ request: SearchRequest) async throws -> ProviderResponse
}

extension SearchProvider {
    public var capabilities: ProviderCapabilities { .init() }
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
}

public struct SearchResponse: Sendable, Encodable {
    public let results: [SearchResult]
    public let attempts: [ProviderAttempt]
}
