import Foundation

/// Documented keyless FreeSerp Global JSON interface. Experimental; commercial rights are unverified.
/// Only the general-web index is accepted. Homepage summaries and silent engine fallback are rejected.
public struct FreeSerpProvider: SearchProvider {
    public let identifier = "freeserp"
    public var capabilities: ProviderCapabilities { .init(locale: true) }
    public var usage: ProviderUsage {
        .init(status: .unverified, evidence: [URL(string: "https://freeserp.ai/docs.php")!], reviewedOn: "2026-11-02")
    }
    private let transport: any HTTPTransport
    private let maximumBytes = 2 * 1024 * 1024

    public init(transport: any HTTPTransport = URLSessionTransport()) { self.transport = transport }

    public func search(_ request: SearchRequest) async throws -> ProviderResponse {
        try Task.checkCancellation()
        guard request.options.safeSearch == nil, request.options.country == nil, request.options.timeRange == nil
        else { throw SearchError(.unsupportedOperation) }
        // The endpoint offers language filtering, not regional market selection. Reject es-ES, rather than
        // silently discarding its region. The public locale contract accepts a language-only BCP-47 tag.
        if let locale = request.options.locale {
            guard locale.utf8.count == 2, locale.utf8.allSatisfy({ (97...122).contains($0) }) else {
                throw SearchError(.unsupportedOperation)
            }
        }
        var url = URLComponents(string: "https://freeserp.ai/api.php")!
        url.queryItems = [
            URLQueryItem(name: "index", value: "web"), URLQueryItem(name: "q", value: request.query),
            URLQueryItem(name: "size", value: String(request.options.limit)),
        ]
        if let language = request.options.locale { url.queryItems!.append(.init(name: "lang", value: language)) }
        // URLComponents preserves literal +, but form-query servers interpret it as a space.
        url.percentEncodedQuery = url.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        var http = URLRequest(url: url.url!)
        http.timeoutInterval = request.options.timeout
        http.setValue("application/json", forHTTPHeaderField: "Accept")
        http.setValue("LapisWebSearch/0.1 (experimental)", forHTTPHeaderField: "User-Agent")
        let response = try await transport.send(http, maximumResponseBytes: maximumBytes)
        if response.status == 200, response.contentType?.lowercased().contains("text/html") == true {
            let prefix = String(decoding: response.data.prefix(8192), as: UTF8.self).lowercased()
            if ["captcha", "cf-chl-", "challenge-platform"].contains(where: prefix.contains) {
                throw SearchError(.blocked, httpStatus: response.status)
            }
        }
        try response.validate(types: ["application/json"], maximumBytes: maximumBytes)
        let envelope: Envelope
        do { envelope = try JSONDecoder().decode(Envelope.self, from: response.data) } catch {
            throw SearchError(.parsingFailure, httpStatus: response.status)
        }
        guard envelope.ok, envelope.index == "web", envelope.engineFallback != true,
            envelope.total >= envelope.results.count, envelope.results.count <= 100
        else {
            throw SearchError(.invalidResponse, httpStatus: response.status)
        }
        if envelope.results.isEmpty {
            guard envelope.total == 0 else { throw SearchError(.invalidResponse, httpStatus: response.status) }
            return .noResults(httpStatus: response.status)
        }
        let results = envelope.results.enumerated().compactMap { index, row -> SearchResult? in
            guard let title = row.title, let rawURL = row.url, let url = URL(string: rawURL) else { return nil }
            return try? SearchResult(
                title: title, url: url, snippet: row.snippet ?? "", provider: identifier, originalPosition: index + 1,
                publishedAt: row.publishedAt.flatMap(parseCalendarDate), metadata: row.language.map { ["language": $0] }
            )
        }
        guard !results.isEmpty else { throw SearchError(.invalidResponse, httpStatus: response.status) }
        return .results(uniqueResults(results, limit: request.options.limit), httpStatus: response.status)
    }

    private struct Envelope: Decodable {
        let ok: Bool
        let index: String
        let total: Int
        let engineFallback: Bool?
        let results: [Row]
        enum CodingKeys: String, CodingKey {
            case ok, index, total, results
            case engineFallback = "engine_fallback"
        }
    }
    private struct Row: Decodable {
        let title: String?
        let url: String?
        let snippet: String?
        let publishedAt: String?
        let language: String?
        enum CodingKeys: String, CodingKey {
            case title, url, snippet, language
            case publishedAt = "published_at"
        }
        init(from decoder: any Decoder) throws {
            let values = try? decoder.container(keyedBy: CodingKeys.self)
            title = try? values?.decode(String.self, forKey: .title)
            url = try? values?.decode(String.self, forKey: .url)
            snippet = try? values?.decode(String.self, forKey: .snippet)
            publishedAt = try? values?.decode(String.self, forKey: .publishedAt)
            language = try? values?.decode(String.self, forKey: .language)
        }
    }
}

/// Strict provider-reported YYYY-MM-DD, never crawl/discovery time or a date inferred from text.
private func parseCalendarDate(_ value: String) -> Date? {
    let pieces = value.split(separator: "-", omittingEmptySubsequences: false)
    guard pieces.count == 3, pieces[0].count == 4, pieces[1].count == 2, pieces[2].count == 2,
        value.utf8.allSatisfy({ (48...57).contains($0) || $0 == 45 }),
        let year = Int(pieces[0]), year >= 1, let month = Int(pieces[1]), let day = Int(pieces[2])
    else { return nil }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let components = DateComponents(year: year, month: month, day: day)
    guard let date = calendar.date(from: components),
        calendar.dateComponents([.year, .month, .day], from: date) == components
    else { return nil }
    return date
}
