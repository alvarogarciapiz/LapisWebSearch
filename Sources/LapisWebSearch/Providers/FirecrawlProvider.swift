import Foundation

/// Official v2 search endpoint, using keyless access. No scraping or extra content requests.
/// Experimental: commercial use requires express provider authorization; see docs/PROVIDERS.md.
public struct FirecrawlProvider: SearchProvider {
    public let identifier = "firecrawl"
    public var usage: ProviderUsage {
        .init(
            status: .restricted, evidence: [URL(string: "https://www.firecrawl.dev/terms-of-service")!],
            reviewedOn: "2026-11-02")
    }
    public var capabilities: ProviderCapabilities { .init(safeSearch: true, country: true, timeRange: true) }
    private let transport: any HTTPTransport
    private let maximumBytes = 2 * 1024 * 1024

    public init(transport: any HTTPTransport = URLSessionTransport()) { self.transport = transport }

    public func search(_ request: SearchRequest) async throws -> ProviderResponse {
        guard request.options.locale == nil else { throw SearchError(.unsupportedOperation) }
        var http = URLRequest(url: URL(string: "https://api.firecrawl.dev/v2/search")!)
        http.httpMethod = "POST"
        http.timeoutInterval = request.options.timeout
        http.setValue("application/json", forHTTPHeaderField: "Content-Type")
        http.setValue("application/json", forHTTPHeaderField: "Accept")
        http.setValue("LapisWebSearch/0.1 (experimental)", forHTTPHeaderField: "User-Agent")
        http.httpBody = try JSONEncoder().encode(
            Body(
                query: request.query, limit: request.options.limit, safe: request.options.safeSearch,
                country: request.options.country,
                tbs: request.options.timeRange.map { "qdr:" + String($0.rawValue.prefix(1)) }
            ))
        let response = try await transport.send(http, maximumResponseBytes: maximumBytes)
        try response.validate(types: ["application/json"], maximumBytes: maximumBytes)
        let envelope: Envelope
        do { envelope = try JSONDecoder().decode(Envelope.self, from: response.data) } catch {
            throw SearchError(.parsingFailure, httpStatus: response.status)
        }
        guard envelope.success, let rows = envelope.data?.web else {
            throw SearchError(.invalidResponse, httpStatus: response.status)
        }
        if rows.isEmpty { return .noResults(httpStatus: response.status) }
        let results = rows.enumerated().compactMap { index, row -> SearchResult? in
            guard let title = row.title, let rawURL = row.url, let url = URL(string: rawURL) else { return nil }
            return try? SearchResult(
                title: title, url: url, snippet: row.description ?? "", provider: identifier,
                originalPosition: row.position.flatMap { $0 > 0 ? $0 : nil } ?? index + 1
            )
        }
        guard !results.isEmpty else { throw SearchError(.invalidResponse, httpStatus: response.status) }
        return .results(uniqueResults(results, limit: request.options.limit), httpStatus: response.status)
    }

    private struct Body: Encodable {
        let query: String
        let limit: Int
        let safe: Bool?
        let country: String?
        let tbs: String?
        let sources = ["web"]
        let highlights = false
    }
    private struct Envelope: Decodable {
        let success: Bool
        let data: Payload?
    }
    private struct Payload: Decodable { let web: [Row]? }
    private struct Row: Decodable {
        let title: String?
        let url: String?
        let description: String?
        let position: Int?
        enum CodingKeys: String, CodingKey { case title, url, description, position }
        init(from decoder: any Decoder) throws {
            let values = try? decoder.container(keyedBy: CodingKeys.self)
            title = try? values?.decode(String.self, forKey: .title)
            url = try? values?.decode(String.self, forKey: .url)
            description = try? values?.decode(String.self, forKey: .description)
            position = try? values?.decode(Int.self, forKey: .position)
        }
    }
}
