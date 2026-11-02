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
        do {
            _ = try await LapisWebSearch().search("never transmitted")
            throw SearchError(.invalidResponse)
        } catch let error as SearchError {
            guard error.code == .noEligibleProviders else { throw error }
        }
        do {
            _ = try await LapisWebSearch(
                providers: [ExampleProvider()], configuration: .init(providerPolicy: .requireCommercialClearance)
            ).search("never transmitted")
            throw SearchError(.invalidResponse)
        } catch let error as SearchError {
            guard error.code == .providerNotPermitted else { throw error }
        }
        guard FreeSerpProvider().usage.status == .unverified else { throw SearchError(.invalidConfiguration) }
        print("Independent consumer imported LapisWebSearch and passed offline API and policy checks.")
    }
}
