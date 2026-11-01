import Foundation
import LapisWebSearch

/// An offline public-API smoke check, deliberately not a live-search validation.
struct ExampleProvider: SearchProvider {
    let identifier = "example"
    func search(_ request: SearchRequest) async throws -> ProviderResponse {
        .results([
            try SearchResult(
                title: "Synthetic example", url: URL(string: "https://example.org")!, snippet: "Offline smoke check",
                provider: identifier, originalPosition: 1
            )
        ])
    }
}

@main struct ConsumerSmoke {
    static func main() async throws {
        let client = LapisWebSearch(
            providers: [ExampleProvider()], configuration: .init(maximumConcurrentRequestsPerProvider: 2))
        let response = try await client.search(
            "sample", options: .init(limit: 1, strategy: .firstSuccess, providerTimeout: 2))
        guard response.results.count == 1, response.results[0].provider == "example" else {
            throw SearchError(.invalidResponse)
        }
        print("Independent consumer imported LapisWebSearch and passed the offline API check.")
    }
}
