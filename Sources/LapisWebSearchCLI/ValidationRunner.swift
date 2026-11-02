import Foundation
import LapisWebSearch

/// Explicitly opt-in native checks. A controlled transport failure is never a real provider outage.
enum ValidationRunner {
    struct Report: Encodable {
        let mode: String
        let injectedPrimaryFailure: Bool
        let nativeHTTPInvocations: Int
        let successfulConsumers: Int
        let coalescedConsumers: Int
        let validResultsPerConsumer: [Int]
        let attempts: [[ProviderAttempt]]
    }
    static func run(_ args: [String]) async throws {
        guard args.count == 2, args[0] == "--live", ["fallback", "coalescing"].contains(args[1]) else {
            throw SearchCLI.CLIError.usage
        }
        let transport = ValidationTransport(injectFailure: args[1] == "fallback")
        let providers: [any SearchProvider] =
            args[1] == "fallback"
            ? [FreeSerpProvider(transport: transport), ParallelSearchProvider(transport: transport)]
            : [FreeSerpProvider(transport: transport)]
        let client = LapisWebSearch(providers: providers)
        let count = args[1] == "fallback" ? 1 : 8
        let responses = try await withThrowingTaskGroup(of: SearchResponse.self) { group in
            for _ in 0..<count {
                group.addTask {
                    try await client.search("What is retrieval augmented generation?", options: .init(timeout: 20))
                }
            }
            var values: [SearchResponse] = []
            for try await value in group { values.append(value) }
            return values
        }
        // Contains no query, result content or endpoint/session IDs.
        try SearchCLI.printJSON(
            Report(
                mode: args[1], injectedPrimaryFailure: args[1] == "fallback",
                nativeHTTPInvocations: await transport.nativeInvocations, successfulConsumers: responses.count,
                coalescedConsumers: responses.filter(\.wasCoalesced).count,
                validResultsPerConsumer: responses.map { $0.results.count }, attempts: responses.map(\.attempts)))
    }
}

private actor ValidationTransport: HTTPTransport {
    let underlying = URLSessionTransport()
    let injectFailure: Bool
    var nativeInvocations = 0
    init(injectFailure: Bool) { self.injectFailure = injectFailure }
    func send(_ request: URLRequest, maximumResponseBytes: Int) async throws -> HTTPResponse {
        if injectFailure && request.url?.host == "freeserp.ai" {
            // Deliberate local injection. No request to FreeSerp is made in this mode.
            throw SearchError(.serverError, httpStatus: 503)
        }
        nativeInvocations += 1
        return try await underlying.send(request, maximumResponseBytes: maximumResponseBytes)
    }
}
