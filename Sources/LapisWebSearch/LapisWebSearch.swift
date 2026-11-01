/// Native keyless search. The compatible default Firecrawl adapter is for experimental evaluation.
/// Default selection grants no commercial service authorization; select providers permitted for your deployment.
/// Keep an instance alive to preserve per-provider rate-limit cooldowns. No cache or history is persisted.
public struct LapisWebSearch: Sendable {
    private let coordinator: SearchCoordinator

    public init(providers: [any SearchProvider] = [FirecrawlProvider()], configuration: SearchConfiguration = .init()) {
        coordinator = SearchCoordinator(providers: providers, configuration: configuration)
    }

    public func search(_ query: String, limit: Int = 5) async throws -> [SearchResult] {
        try await search(query, options: SearchOptions(limit: limit)).results
    }

    /// Includes local diagnostics on success. On failure, inspect SearchError.attempts.
    public func search(_ query: String, options: SearchOptions) async throws -> SearchResponse {
        try await coordinator.search(SearchRequest(query: query, options: options))
    }
}
