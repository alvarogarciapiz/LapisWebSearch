/// Native keyless search. The default Firecrawl adapter is experimental and subject to service terms.
/// Keep an instance alive to preserve per-provider rate-limit cooldowns. No cache or history is persisted.
public struct LapisWebSearch: Sendable {
    private let coordinator: SearchCoordinator

    public init(providers: [any SearchProvider] = [FirecrawlProvider()]) {
        coordinator = SearchCoordinator(providers: providers)
    }

    public func search(_ query: String, limit: Int = 5) async throws -> [SearchResult] {
        try await search(query, options: SearchOptions(limit: limit)).results
    }

    /// Includes local diagnostics on success. On failure, inspect SearchError.attempts.
    public func search(_ query: String, options: SearchOptions) async throws -> SearchResponse {
        try await coordinator.search(SearchRequest(query: query, options: options))
    }
}
