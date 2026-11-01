import Foundation
import Testing

@testable import LapisWebSearch

@Suite struct NetworkingTests {
    @Test(arguments: [401, 402, 403, 408, 429, 451, 500, 502, 504, 301, 400])
    func statusClassification(_ status: Int) throws {
        let expected: SearchError.Code
        switch status {
        case 401: expected = .unauthorized
        case 402, 429: expected = .rateLimited
        case 403, 451: expected = .blocked
        case 408, 504: expected = .timeout
        case 500...599: expected = .serverError
        default: expected = .invalidResponse
        }
        do {
            try HTTPResponse(data: Data(), status: status, contentType: "application/json", retryAfter: "120").validate(
                types: ["application/json"], maximumBytes: 100)
            Issue.record("Expected failure")
        } catch let error as SearchError {
            #expect(error.code == expected)
            #expect(error.httpStatus == status)
            if status == 429 || status == 402 { #expect(error.retryAfter != nil) }
        }
    }

    @Test(arguments: ["text/html", "application/octet-stream", "", "text/plain"])
    func invalidContentTypes(_ type: String) {
        #expect(throws: SearchError.self) {
            try HTTPResponse(data: Data(), status: 200, contentType: type).validate(
                types: ["application/json"], maximumBytes: 10)
        }
    }

    @Test func responseBounds() {
        #expect(throws: SearchError.self) {
            try HTTPResponse(data: Data(repeating: 0, count: 11), status: 200, contentType: "application/json")
                .validate(types: ["application/json"], maximumBytes: 10)
        }
        #expect(throws: Never.self) {
            try HTTPResponse(
                data: Data(repeating: 0, count: 10), status: 200, contentType: "Application/JSON; charset=UTF-8"
            ).validate(types: ["application/json"], maximumBytes: 10)
        }
    }

    @Test func injectedTransportCannotBypassProviderSizeCheck() async throws {
        let transport = StubTransport(Data(repeating: 32, count: 2 * 1024 * 1024 + 1))
        do {
            _ = try await FirecrawlProvider(transport: transport).search(SearchRequest(query: "sample"))
            Issue.record("Expected failure")
        } catch let error as SearchError { #expect(error.code == .responseTooLarge) }
    }

    @Test func retryAfterVariants() throws {
        let now = Date(timeIntervalSince1970: 0)
        #expect(RetryAfter.parse("120", now: now) == now.addingTimeInterval(120))
        #expect(RetryAfter.parse("Sun, 01 Nov 2026 08:00:00 GMT") != nil)
        #expect(RetryAfter.parse("-5") == nil)
        #expect(RetryAfter.parse("nan") == nil)
        #expect(RetryAfter.parse("infinity") == nil)
        #expect(RetryAfter.parse("nonsense") == nil)
        #expect(RetryAfter.parse(nil) == nil)
    }

    @Test func urlSessionErrorClassification() {
        #expect(SearchError.classify(URLError(.notConnectedToInternet)).code == .networkUnavailable)
        #expect(SearchError.classify(URLError(.timedOut)).code == .timeout)
        #expect(SearchError.classify(URLError(.cancelled)).code == .cancelled)
        #expect(SearchError.classify(CancellationError()).code == .cancelled)
    }

    @Test func httpsOnlyTransport() async {
        await #expect(throws: SearchError.self) {
            try await URLSessionTransport().send(
                URLRequest(url: URL(string: "http://example.org")!), maximumResponseBytes: 100)
        }
    }

    @Test func providerPropagatesTransportFailure() async throws {
        let transport = StubTransport(error: SearchError(.networkUnavailable))
        do {
            _ = try await FirecrawlProvider(transport: transport).search(SearchRequest(query: "sample"))
            Issue.record("Expected failure")
        } catch let error as SearchError { #expect(error.code == .networkUnavailable) }
    }
}
