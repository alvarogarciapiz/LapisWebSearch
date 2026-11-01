import Foundation

/// Documented keyless Parallel MCP web search for evaluation/light use. No model, research or fetch tool is invoked.
/// Commercial distribution and applicable provider agreements must be reviewed independently; never enabled implicitly.
public struct ParallelSearchProvider: SearchProvider {
    public let identifier = "parallel"
    private let connection: ParallelConnection
    public init(transport: any HTTPTransport = URLSessionTransport()) {
        connection = ParallelConnection(transport: transport)
    }

    public func search(_ request: SearchRequest) async throws -> ProviderResponse {
        guard request.options.locale == nil, request.options.country == nil,
            request.options.timeRange == nil, request.options.safeSearch == nil,
            !request.query.contains("\"")
        else { throw SearchError(.unsupportedOperation) }
        let response = try await connection.search(request)
        let rows = response.results
        if rows.isEmpty { return .noResults(httpStatus: 200) }
        var seen: Set<URL> = []
        let results = rows.enumerated().compactMap { index, row -> SearchResult? in
            guard let url = row.url.flatMap(URL.init(string:)), let title = row.title,
                let result = try? SearchResult(
                    title: title, url: url,
                    snippet: String((row.excerpts?.first ?? "").prefix(1600)), provider: identifier,
                    originalPosition: index + 1, publishedAt: Self.publicationDate(row.publishDate))
            else { return nil }
            return seen.insert(result.url).inserted ? result : nil
        }
        guard !results.isEmpty else { throw SearchError(.invalidResponse, httpStatus: 200) }
        return .results(Array(results.prefix(request.options.limit)), httpStatus: 200)
    }

    private static func publicationDate(_ value: String?) -> Date? {
        guard let value, value.utf8.count == 10 else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: value), formatter.string(from: date) == value else { return nil }
        return date
    }
}

private struct ParallelResults: Decodable, Sendable {
    let results: [Row]
    struct Row: Decodable, Sendable {
        let url: String?
        let title: String?
        let excerpts: [String]?
        let publishDate: String?
        enum CodingKeys: String, CodingKey {
            case url, title, excerpts
            case publishDate = "publish_date"
        }
    }
}

/// Minimal fixed-tool MCP connection, not a general agent or plugin client. Endpoint discovery is never followed.
private actor ParallelConnection {
    private struct Session: Sendable {
        let id: String?
        let version: String
    }
    private let transport: any HTTPTransport
    private let initializationGate = AsyncGate(limit: 1)
    private var session: Session?
    init(transport: any HTTPTransport) { self.transport = transport }

    func search(_ request: SearchRequest) async throws -> ParallelResults {
        let deadline = ContinuousClock.now.advanced(by: .seconds(request.options.timeout))
        try await initializationGate.withPermit(deadline: deadline) { try await self.initialize(deadline: deadline) }
        try Task.checkCancellation()
        guard let session else { throw SearchError(.invalidResponse) }
        let id = UUID().uuidString
        let body = Call(
            id: id, params: Call.Params(arguments: .init(objective: request.query, searchQueries: [request.query])))
        let response = try await send(body, session: session, deadline: deadline)
        // Session loss is reported without retrying a potentially billed search; next invocation reinitializes.
        if response.status == 404, self.session?.id == session.id { self.session = nil }
        try response.validate(types: ["application/json", "text/event-stream"], maximumBytes: 2 * 1024 * 1024)
        let envelope: RPCEnvelope<ToolResult> = try MCPDecoder.decode(response, id: id)
        guard let result = envelope.result, result.isError != true, let payload = result.structuredContent else {
            throw SearchError(.invalidResponse, httpStatus: response.status)
        }
        return payload
    }

    private func initialize(deadline: ContinuousClock.Instant) async throws {
        if session != nil { return }
        let id = UUID().uuidString
        let response = try await send(Initialize(id: id), session: nil, deadline: deadline)
        try response.validate(types: ["application/json", "text/event-stream"], maximumBytes: 2 * 1024 * 1024)
        let envelope: RPCEnvelope<Initialized> = try MCPDecoder.decode(response, id: id)
        guard let value = envelope.result, ["2025-03-26", "2025-06-18", "2025-11-25"].contains(value.protocolVersion),
            response.mcpSessionID.map({
                !$0.isEmpty && $0.utf8.count <= 512
                    && !$0.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
            }) ?? true
        else { throw SearchError(.invalidResponse, httpStatus: response.status) }
        let valueSession = Session(id: response.mcpSessionID, version: value.protocolVersion)
        let notification = try await send(Notification(), session: valueSession, deadline: deadline)
        if !(200...299).contains(notification.status) {
            try notification.validate(types: ["application/json", "text/event-stream"], maximumBytes: 2 * 1024 * 1024)
        }
        try Task.checkCancellation()
        session = valueSession
    }

    private func send(_ body: some Encodable, session: Session?, deadline: ContinuousClock.Instant) async throws
        -> HTTPResponse
    {
        let remaining = seconds(ContinuousClock.now.duration(to: deadline))
        guard remaining > 0 else { throw SearchError(.timeout) }
        var request = URLRequest(url: URL(string: "https://mcp.parallel.ai/mcp")!)
        request.httpMethod = "POST"
        request.timeoutInterval = remaining
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("LapisWebSearch/0.2 (research preview)", forHTTPHeaderField: "User-Agent")
        request.setValue(session?.version ?? "2025-03-26", forHTTPHeaderField: "MCP-Protocol-Version")
        if let id = session?.id { request.setValue(id, forHTTPHeaderField: "Mcp-Session-Id") }
        request.httpBody = try JSONEncoder().encode(body)
        let response = try await transport.send(request, maximumResponseBytes: 2 * 1024 * 1024)
        guard response.data.count <= 2 * 1024 * 1024 else {
            throw SearchError(.responseTooLarge, httpStatus: response.status)
        }
        return response
    }

    private struct Initialized: Decodable { let protocolVersion: String }
    private struct ToolResult: Decodable {
        let isError: Bool?
        let structuredContent: ParallelResults?
    }
    private struct Initialize: Encodable {
        let jsonrpc = "2.0"
        let method = "initialize"
        let id: String
        let params = Params()
        struct Params: Encodable {
            let protocolVersion = "2025-03-26"
            let capabilities: [String: String] = [:]
            let clientInfo = ClientInfo()
        }
        struct ClientInfo: Encodable {
            let name = "LapisWebSearch"
            let version = "0.2-research"
        }
    }
    private struct Notification: Encodable {
        let jsonrpc = "2.0"
        let method = "notifications/initialized"
    }
    private struct Call: Encodable {
        let jsonrpc = "2.0"
        let method = "tools/call"
        let id: String
        let params: Params
        struct Params: Encodable {
            let name = "web_search"
            let arguments: Arguments
        }
        struct Arguments: Encodable {
            let objective: String
            let searchQueries: [String]
            enum CodingKeys: String, CodingKey {
                case objective
                case searchQueries = "search_queries"
            }
        }
    }
}

struct RPCEnvelope<T: Decodable>: Decodable {
    let jsonrpc: String
    let id: String?
    let result: T?
    let error: RPCError?
    struct RPCError: Decodable { let code: Int }
}

enum MCPDecoder {
    static func decode<T>(_ response: HTTPResponse, id: String) throws -> RPCEnvelope<T> where T: Decodable {
        let decoder = JSONDecoder()
        var messages: [Data] = []
        if response.contentType?.lowercased().hasPrefix("text/event-stream") == true {
            guard let text = String(data: response.data, encoding: .utf8) else {
                throw SearchError(.parsingFailure, httpStatus: response.status)
            }
            var lines: [String] = []
            for line in text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
                if line.isEmpty {
                    if !lines.isEmpty {
                        messages.append(Data(lines.joined(separator: "\n").utf8))
                        lines = []
                    }
                } else if line.hasPrefix("data:") {
                    let value = line.dropFirst(5)
                    lines.append(String(value.first == " " ? value.dropFirst() : value))
                }
            }
            if !lines.isEmpty { messages.append(Data(lines.joined(separator: "\n").utf8)) }
        } else {
            messages = [response.data]
        }
        for message in messages {
            // Notifications/progress frames can have different shapes; only a matching response is accepted.
            guard let envelope = try? decoder.decode(RPCEnvelope<T>.self, from: message), envelope.id == id else {
                continue
            }
            guard envelope.jsonrpc == "2.0", envelope.error == nil else {
                throw SearchError(.invalidResponse, httpStatus: response.status)
            }
            return envelope
        }
        throw SearchError(.parsingFailure, httpStatus: response.status)
    }
}
