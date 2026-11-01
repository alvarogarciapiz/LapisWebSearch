import Foundation
import Testing

@testable import LapisWebSearch

actor MCPStub: HTTPTransport {
    enum Mode: Sendable { case valid, empty, toolError, wrongID, badProtocol, rateLimited, sessionLost }
    let mode: Mode
    var requests: [URLRequest] = []
    init(_ mode: Mode = .valid) { self.mode = mode }
    func send(_ request: URLRequest, maximumResponseBytes: Int) async throws -> HTTPResponse {
        requests.append(request)
        let object = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let method = object["method"] as! String
        if method == "notifications/initialized" {
            return .init(data: Data(), status: 202, contentType: "application/json")
        }
        let id = mode == .wrongID ? "wrong" : object["id"] as! String
        var result: [String: Any]
        if method == "initialize" {
            result = ["protocolVersion": mode == .badProtocol ? "1900-01-01" : "2025-03-26"]
        } else {
            if mode == .rateLimited {
                return .init(data: Data(), status: 429, contentType: "application/json", retryAfter: "120")
            }
            if mode == .sessionLost { return .init(data: Data(), status: 404, contentType: "application/json") }
            let payload =
                mode == .empty ? ["results": []] : try JSONSerialization.jsonObject(with: fixture("parallel", "json"))
            result = ["isError": mode == .toolError, "structuredContent": payload]
        }
        let bytes = try JSONSerialization.data(withJSONObject: ["jsonrpc": "2.0", "id": id, "result": result])
        let stream = Data("event: message\r\ndata: ".utf8) + bytes + Data("\r\n\r\n".utf8)
        return .init(data: stream, status: 200, contentType: "text/event-stream", mcpSessionID: "synthetic-session")
    }
}

@Suite struct ParallelProviderTests {
    @Test func nativeContractParsingAndSessionReuse() async throws {
        let transport = MCPStub()
        let provider = ParallelSearchProvider(transport: transport)
        let request = try SearchRequest(query: "Swift documentation español")
        let response = try await provider.search(request)
        guard case .results(let rows, _) = response else {
            Issue.record("Expected results")
            return
        }
        try #require(rows.count == 2)
        #expect(rows[0].title == "Swift documentation")
        #expect(rows[0].publishedAt != nil)
        #expect(rows[1].publishedAt == nil)
        #expect(rows[1].originalPosition == 4)
        _ = try await provider.search(request)
        let calls = await transport.requests
        #expect(calls.count == 4)  // Initialize, notification, search, search. No tools/list or fetch.
        #expect(calls.allSatisfy { $0.url?.absoluteString == "https://mcp.parallel.ai/mcp" })
        #expect(calls[2].value(forHTTPHeaderField: "Mcp-Session-Id") == "synthetic-session")
        let body = try JSONSerialization.jsonObject(with: #require(calls[2].httpBody)) as! [String: Any]
        let params = body["params"] as! [String: Any]
        let arguments = params["arguments"] as! [String: Any]
        #expect(params["name"] as? String == "web_search")
        #expect(arguments["objective"] as? String == request.query)
        #expect(arguments["search_queries"] as? [String] == [request.query])
        #expect(arguments["client_model"] == nil)
        #expect(arguments["session_id"] == nil)
    }

    @Test(arguments: [MCPStub.Mode.toolError, .wrongID, .badProtocol, .rateLimited, .sessionLost])
    func malformedAndRestrictedResponses(_ mode: MCPStub.Mode) async throws {
        let provider = ParallelSearchProvider(transport: MCPStub(mode))
        await #expect(throws: SearchError.self) { try await provider.search(SearchRequest(query: "public sample")) }
    }

    @Test func validEmptyResponse() async throws {
        let response = try await ParallelSearchProvider(transport: MCPStub(.empty)).search(
            SearchRequest(query: "public sample"))
        guard case .noResults = response else {
            Issue.record("Expected no results")
            return
        }
    }

    @Test func unsupportedOptionsAndQuotedQueriesDoNotContactService() async throws {
        let transport = MCPStub()
        let provider = ParallelSearchProvider(transport: transport)
        for options in [
            SearchOptions(locale: "es-ES"), .init(country: "ES"), .init(safeSearch: true), .init(timeRange: .day),
        ] {
            await #expect(throws: SearchError.self) {
                try await provider.search(SearchRequest(query: "sample", options: options))
            }
        }
        await #expect(throws: SearchError.self) { try await provider.search(SearchRequest(query: "\"exact phrase\"")) }
        #expect(await transport.requests.isEmpty)
    }

    @Test func simultaneousRequestsShareHandshake() async throws {
        let transport = MCPStub()
        let provider = ParallelSearchProvider(transport: transport)
        async let a = provider.search(SearchRequest(query: "first sample"))
        async let b = provider.search(SearchRequest(query: "second sample"))
        _ = try await [a, b]
        #expect(await transport.requests.count == 4)
    }

    @Test func sessionLossDoesNotRetrySearchAutomatically() async throws {
        let transport = MCPStub(.sessionLost)
        let provider = ParallelSearchProvider(transport: transport)
        _ = try? await provider.search(SearchRequest(query: "sample"))
        #expect(await transport.requests.count == 3)
        _ = try? await provider.search(SearchRequest(query: "sample"))
        #expect(await transport.requests.count == 6)
    }

    @Test func sseMultilineAndIDValidation() throws {
        struct Payload: Decodable { let value: Int }
        let text =
            ": heartbeat\n\nevent: message\ndata: {\"jsonrpc\":\"2.0\",\"id\":\"response-id\",\ndata: \"result\":{\"value\":42}}\n\n"
        let response = HTTPResponse(data: Data(text.utf8), status: 200, contentType: "text/event-stream")
        let envelope: RPCEnvelope<Payload> = try MCPDecoder.decode(response, id: "response-id")
        #expect(envelope.result?.value == 42)
        #expect(throws: SearchError.self) {
            let _: RPCEnvelope<Payload> = try MCPDecoder.decode(response, id: "different")
        }
    }

    @Test func firecrawlCountryTimeAndDuplicateCoverage() async throws {
        let transport = StubTransport(try fixture("firecrawl", "json"))
        let response = try await FirecrawlProvider(transport: transport).search(
            SearchRequest(query: "novedades", options: .init(country: "es", timeRange: .month)))
        guard case .results(let rows, _) = response else {
            Issue.record("Expected results")
            return
        }
        #expect(rows.count == 2)
        let request = try #require(await transport.requests.first)
        let body = try JSONSerialization.jsonObject(with: #require(request.httpBody)) as! [String: Any]
        #expect(body["country"] as? String == "ES")
        #expect(body["tbs"] as? String == "qdr:m")
    }
}
