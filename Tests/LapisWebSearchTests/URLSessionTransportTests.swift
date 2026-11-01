import Foundation
import Testing

@testable import LapisWebSearch

/// URLProtocol is installed only in this test's session; no global registration or mutable handlers.
private final class FixtureProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let route = request.url!.lastPathComponent
        if route == "offline" {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        if route == "stall" { return }
        let status = route == "rate" ? 429 : 200
        let headers = [
            "Content-Type": "application/json", "Retry-After": "90",
            "Content-Length": route == "declared-large" ? "1000" : "-1",
        ]
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if route == "header-stall" { return }
        let count = route == "stream-large" ? 11 : 10
        client?.urlProtocol(self, didLoad: Data(repeating: 32, count: count))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Suite struct URLSessionTransportTests {
    let transport = URLSessionTransport(protocolClasses: [FixtureProtocol.self])
    func request(_ route: String) -> URLRequest { URLRequest(url: URL(string: "https://example.invalid/\(route)")!) }

    @Test func exactByteLimit() async throws {
        let response = try await transport.send(request("exact"), maximumResponseBytes: 10)
        #expect(response.data.count == 10)
        #expect(response.status == 200)
    }

    @Test(arguments: ["declared-large", "stream-large"])
    func boundedNativeResponse(_ route: String) async throws {
        do {
            _ = try await transport.send(request(route), maximumResponseBytes: 10)
            Issue.record("Expected size error")
        } catch let error as SearchError { #expect(error.code == .responseTooLarge) }
    }

    @Test func nativeNetworkFailure() async throws {
        do {
            _ = try await transport.send(request("offline"), maximumResponseBytes: 10)
            Issue.record("Expected network error")
        } catch let error as SearchError { #expect(error.code == .networkUnavailable) }
    }

    @Test func rateLimitWithoutReadingBody() async throws {
        let response = try await transport.send(request("rate"), maximumResponseBytes: 1)
        #expect(response.status == 429)
        #expect(response.data.isEmpty)
        #expect(response.retryAfter == "90")
    }

    @Test func cancellationOfNativeSession() async throws {
        let transport = transport
        let request = request("stall")
        let task = Task { try await transport.send(request, maximumResponseBytes: 10) }
        try await Task.sleep(for: .milliseconds(20))
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch let error as SearchError { #expect(error.code == .cancelled) }
    }

    @Test func redirectPolicyRejectsAllDestinations() async throws {
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let source = URL(string: "https://example.invalid/search")!
        let response = HTTPURLResponse(url: source, statusCode: 302, httpVersion: nil, headerFields: nil)!
        for destination in ["https://example.invalid/other", "https://other.invalid/", "http://example.invalid/"] {
            let redirected: URLRequest? = await withCheckedContinuation { continuation in
                RedirectPolicy().urlSession(
                    session, task: session.dataTask(with: source), willPerformHTTPRedirection: response,
                    newRequest: URLRequest(url: URL(string: destination)!)
                ) { continuation.resume(returning: $0) }
            }
            #expect(redirected == nil)
        }
    }
    @Test(arguments: ["stall", "header-stall"]) func nativeTransportEnforcesWholeRequestDeadline(_ route: String)
        async throws
    {
        var request = request(route)
        request.timeoutInterval = 0.04
        do {
            _ = try await transport.send(request, maximumResponseBytes: 10)
            Issue.record("Expected timeout")
        } catch let error as SearchError {
            #expect(error.code == .timeout)
            #expect(error.httpStatus == (route == "header-stall" ? 200 : nil))
        }
        #expect(try await transport.send(self.request("exact"), maximumResponseBytes: 10).data.count == 10)
    }

}
