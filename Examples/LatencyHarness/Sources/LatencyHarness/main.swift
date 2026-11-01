import Foundation
import LapisWebSearch

/// Optional developer harness: the same source compiles against the phase-1 revision and the current package.
/// --live is mandatory. JSON-line input is explicit, never read from application histories.
actor CountingTransport: HTTPTransport {
    let underlying = URLSessionTransport()
    var calls = 0
    func send(_ request: URLRequest, maximumResponseBytes: Int) async throws -> HTTPResponse {
        calls += 1
        return try await underlying.send(request, maximumResponseBytes: maximumResponseBytes)
    }
}
struct Input: Decodable {
    let id: String
    let query: String
    let burst: Int
}
struct Outcome: Encodable {
    let duration: Double
    let response: SearchResponse?
    let error: SearchError?
}
struct Record: Encodable {
    let id: String
    let actualHTTPRequests: Int
    let outcomes: [Outcome]
}
@main struct LatencyHarness {
    static func main() async throws {
        guard CommandLine.arguments.contains("--live") else {
            print(
                "Use --live only after reviewing provider terms. Input: JSON lines with id, public query and burst (1...8)."
            )
            return
        }
        let counter = CountingTransport()
        let client = LapisWebSearch(providers: [FirecrawlProvider(transport: counter)])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        while let line = readLine() {
            let input = try JSONDecoder().decode(Input.self, from: Data(line.utf8))
            guard (1...8).contains(input.burst) else { throw SearchError(.invalidInput) }
            let before = await counter.calls
            let outcomes = await withTaskGroup(of: Outcome.self) { group in
                for _ in 0..<input.burst {
                    group.addTask {
                        let start = ContinuousClock.now
                        do {
                            let response = try await client.search(input.query, options: .init(limit: 5))
                            let time = start.duration(to: .now).components
                            return Outcome(
                                duration: Double(time.seconds) + Double(time.attoseconds) / 1e18, response: response,
                                error: nil)
                        } catch {
                            let time = start.duration(to: .now).components
                            return Outcome(
                                duration: Double(time.seconds) + Double(time.attoseconds) / 1e18, response: nil,
                                error: error as? SearchError ?? SearchError(.invalidResponse))
                        }
                    }
                }
                var values: [Outcome] = []
                for await value in group { values.append(value) }
                return values
            }
            let record = Record(id: input.id, actualHTTPRequests: await counter.calls - before, outcomes: outcomes)
            FileHandle.standardOutput.write(try encoder.encode(record) + Data("\n".utf8))
        }
    }
}
