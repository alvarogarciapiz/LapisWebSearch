import Foundation
import Testing

@testable import LapisWebSearch

/// Synthetic local URLProtocol throughput, never described as live-provider reliability.
private final class PayloadProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let size = 1024 * 1024
        let response = HTTPURLResponse(
            url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json", "Content-Length": String(size)])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        for _ in 0..<16 { client?.urlProtocol(self, didLoad: Data(repeating: 65, count: size / 16)) }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
@Suite struct TransportPerformanceTests {
    @Test func boundedMegabytePayloadThroughput() async throws {
        let transport = URLSessionTransport(protocolClasses: [PayloadProtocol.self])
        var samples: [Double] = []
        for _ in 0..<3 {
            let start = ContinuousClock.now
            let response = try await transport.send(
                URLRequest(url: URL(string: "https://example.invalid/payload")!), maximumResponseBytes: 2 * 1024 * 1024)
            let elapsed = start.duration(to: .now).components
            samples.append(Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18)
            #expect(response.data.count == 1024 * 1024)
            #expect(response.data.allSatisfy { $0 == 65 })
        }
        print("TRANSPORT_MICROBENCH_SECONDS=\(samples)")
    }
}
