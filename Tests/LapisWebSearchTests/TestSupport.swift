import Foundation

@testable import LapisWebSearch

func fixture(_ name: String, _ ext: String) throws -> Data {
    try Data(contentsOf: Bundle.module.url(forResource: name, withExtension: ext)!)
}

actor StubTransport: HTTPTransport {
    let response: HTTPResponse
    let error: SearchError?
    var requests: [URLRequest] = []
    init(
        _ data: Data = Data(), status: Int = 200, type: String? = "application/json", retry: String? = nil,
        error: SearchError? = nil
    ) {
        response = HTTPResponse(data: data, status: status, contentType: type, retryAfter: retry)
        self.error = error
    }
    func send(_ request: URLRequest, maximumResponseBytes: Int) async throws -> HTTPResponse {
        requests.append(request)
        if let error { throw error }
        return response
    }
}

actor StubProvider: SearchProvider {
    nonisolated let identifier: String
    let response: ProviderResponse
    let failure: SearchError?
    let delay: Duration
    var calls = 0
    var cancellations = 0
    init(
        _ identifier: String = "stub", response: ProviderResponse = .noResults(), failure: SearchError? = nil,
        delay: Duration = .zero
    ) {
        self.identifier = identifier
        self.response = response
        self.failure = failure
        self.delay = delay
    }
    func search(_ request: SearchRequest) async throws -> ProviderResponse {
        calls += 1
        do { try await Task.sleep(for: delay) } catch {
            cancellations += 1
            throw error
        }
        if let failure { throw failure }
        return response
    }
}

func result(_ provider: String = "stub", _ url: String = "https://example.org/", position: Int = 1) throws
    -> SearchResult
{
    try SearchResult(
        title: "Example", url: URL(string: url)!, snippet: "A useful snippet", provider: provider,
        originalPosition: position)
}

/// Models standard server-side application/x-www-form-urlencoded query decoding, including plus-as-space.
func formQueryValue(_ url: URL, name: String) -> String? {
    let parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
    for item in (parts?.percentEncodedQuery ?? "").split(separator: "&") {
        let pair = item.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        guard pair.count == 2 else { continue }
        let key = String(pair[0]).replacingOccurrences(of: "+", with: " ").removingPercentEncoding
        if key == name {
            return String(pair[1]).replacingOccurrences(of: "+", with: " ").removingPercentEncoding
        }
    }
    return nil
}
