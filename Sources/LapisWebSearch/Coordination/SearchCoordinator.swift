import Foundation

/// Small ordered registry and coordinator. Shared actor state contains only busy flags and cooldowns.
/// Searches use at most one request per provider, stop at the first usable result set, and never top up.
public actor SearchCoordinator {
    private let providers: [any SearchProvider]
    private var busy: Set<String> = []
    private var cooldowns: [String: Date] = [:]

    public init(providers: [any SearchProvider]) { self.providers = providers }

    public func search(_ request: SearchRequest) async throws -> SearchResponse {
        guard !providers.isEmpty, providers.count <= 8,
            Set(providers.map(\.identifier)).count == providers.count,
            providers.allSatisfy({ !$0.identifier.isEmpty })
        else { throw SearchError(.invalidConfiguration) }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(request.options.timeout))
        var attempts: [ProviderAttempt] = []
        var onlyNoResults = true
        for (index, provider) in providers.enumerated() {
            if Task.isCancelled { throw SearchError(.cancelled, attempts: attempts) }
            let start = Date()
            let instant = clock.now
            var status: Int?
            var failure: SearchError?
            var skipped = false
            var results: [SearchResult] = []
            if instant >= deadline { throw SearchError(.timeout, attempts: attempts) }
            if let until = cooldowns[provider.identifier], until > start {
                failure = SearchError(.rateLimited, retryAfter: until)
                skipped = true
            } else if busy.contains(provider.identifier) {
                failure = SearchError(.providerBusy)
                skipped = true
            } else if (request.options.locale != nil && !provider.capabilities.locale)
                || (request.options.safeSearch != nil && !provider.capabilities.safeSearch)
            {
                failure = SearchError(.unsupportedOperation)
                skipped = true
            } else {
                busy.insert(provider.identifier)
                do {
                    let response = try await withinDeadline(deadline) { try await provider.search(request) }
                    try Task.checkCancellation()
                    switch response {
                    case .results(let candidates, let code):
                        status = code
                        var seen: Set<URL> = []
                        results = Array(
                            candidates.filter { seen.insert($0.url).inserted }.prefix(request.options.limit))
                        if results.isEmpty || results.contains(where: { $0.provider != provider.identifier }) {
                            results = []
                            failure = SearchError(.invalidResponse, httpStatus: code)
                        }
                    case .noResults(let code):
                        status = code
                        failure = SearchError(.noResults, httpStatus: code)
                    }
                } catch { failure = SearchError.classify(error) }
                busy.remove(provider.identifier)
            }
            if let failure, failure.code == .rateLimited, !skipped {
                // No retry within a search. A missing or expired Retry-After gets a conservative 60s cooldown.
                cooldowns[provider.identifier] = max(failure.retryAfter ?? start, Date().addingTimeInterval(60))
            }
            let elapsed = instant.duration(to: clock.now).components
            attempts.append(
                ProviderAttempt(
                    provider: provider.identifier, startedAt: start, completedAt: Date(),
                    duration: Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18,
                    httpStatus: status ?? failure?.httpStatus, validResultCount: results.count,
                    error: failure?.code, wasFallback: index > 0, skipped: skipped, retryAfter: failure?.retryAfter
                ))
            if Task.isCancelled || failure?.code == .cancelled { throw SearchError(.cancelled, attempts: attempts) }
            if !results.isEmpty { return SearchResponse(results: results, attempts: attempts) }
            if failure?.code != .noResults { onlyNoResults = false }
            if clock.now >= deadline { throw SearchError(.timeout, attempts: attempts) }
            if !request.options.fallback { break }
        }
        throw SearchError(onlyNoResults ? .noResults : .allProvidersUnavailable, attempts: attempts)
    }
}
