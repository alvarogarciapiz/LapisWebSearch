import Foundation

/// This adapter is disabled unless the caller explicitly declares separate Microsoft permission.
/// The feed's own notice restricts use to personal, noncommercial RSS display; general search reuse
/// requires written permission. This type provides no such permission.
public struct BingRSSProvider: SearchProvider {
    public let identifier = "bing-rss"
    public var capabilities: ProviderCapabilities { .init(locale: true) }
    private let transport: any HTTPTransport
    private let hasSeparatePermission: Bool
    private let maximumBytes = 2 * 1024 * 1024

    public init(hasSeparatePermission: Bool = false, transport: any HTTPTransport = URLSessionTransport()) {
        self.hasSeparatePermission = hasSeparatePermission
        self.transport = transport
    }

    public func search(_ request: SearchRequest) async throws -> ProviderResponse {
        guard hasSeparatePermission, request.options.safeSearch == nil, request.options.country == nil,
            request.options.timeRange == nil
        else { throw SearchError(.unsupportedOperation) }
        var parts = URLComponents(string: "https://www.bing.com/search")!
        parts.queryItems = [.init(name: "q", value: request.query), .init(name: "format", value: "rss")]
        if let locale = request.options.locale { parts.queryItems?.append(.init(name: "mkt", value: locale)) }
        var http = URLRequest(url: parts.url!)
        http.timeoutInterval = request.options.timeout
        http.setValue("application/rss+xml, application/xml, text/xml", forHTTPHeaderField: "Accept")
        http.setValue("LapisWebSearch/0.1 (experimental)", forHTTPHeaderField: "User-Agent")
        let response = try await transport.send(http, maximumResponseBytes: maximumBytes)
        try response.validate(
            types: ["application/rss+xml", "application/xml", "text/xml"], maximumBytes: maximumBytes)
        do {
            let results = try RSSDecoder.decode(response.data, provider: identifier)
            if results.isEmpty { return .noResults(httpStatus: response.status) }
            return .results(Array(results.prefix(request.options.limit)), httpStatus: response.status)
        } catch { throw SearchError(SearchError.classify(error).code, httpStatus: response.status) }
    }
}

/// UTF-8 RSS only. DTDs, entities, external resolution and excessive nesting are rejected.
enum RSSDecoder {
    static func decode(_ data: Data, provider: String) throws -> [SearchResult] {
        guard let xml = String(data: data, encoding: .utf8),
            !xml.utf8.contains(0),
            xml.range(of: "<!DOCTYPE", options: .caseInsensitive) == nil,
            xml.range(of: "<!ENTITY", options: .caseInsensitive) == nil
        else { throw SearchError(.parsingFailure) }
        let delegate = RSSDelegate(provider: provider)
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse(), delegate.validChannel, !delegate.invalid else { throw SearchError(.parsingFailure) }
        guard delegate.itemCount == 0 || !delegate.results.isEmpty else { throw SearchError(.invalidResponse) }
        return delegate.results
    }
}

private final class RSSDelegate: NSObject, XMLParserDelegate {
    let provider: String
    var path: [String] = []
    var fields: [String: String] = [:]
    var results: [SearchResult] = []
    var validChannel = false
    var invalid = false
    var itemCount = 0
    init(provider: String) { self.provider = provider }

    func parser(
        _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
        qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]
    ) {
        path.append(elementName)
        if path.count > 32 {
            invalid = true
            parser.abortParsing()
        }
        if path.count == 1 && elementName != "rss" {
            invalid = true
            parser.abortParsing()
        }
        if path == ["rss", "channel"] { validChannel = true }
        if path == ["rss", "channel", "item"] {
            fields = [:]
            itemCount += 1
            if itemCount > 1000 {
                invalid = true
                parser.abortParsing()
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard path.count == 4, path.prefix(3).elementsEqual(["rss", "channel", "item"]),
            let field = path.last, ["title", "link", "description", "pubDate"].contains(field)
        else { return }
        fields[field, default: ""] += string
        if (fields[field]?.utf8.count ?? 0) > 32_768 {
            invalid = true
            parser.abortParsing()
        }
    }

    func parser(_ parser: XMLParser, foundCDATA cdataBlock: Data) {
        guard let value = String(data: cdataBlock, encoding: .utf8) else {
            invalid = true
            parser.abortParsing()
            return
        }
        self.parser(parser, foundCharacters: value)
    }

    func parser(
        _ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?
    ) {
        if path == ["rss", "channel", "item"], let link = fields["link"],
            let url = URL(string: TextCleanup.clean(link)),
            let result = try? SearchResult(
                title: fields["title"] ?? "", url: url, snippet: fields["description"] ?? "",
                provider: provider, originalPosition: itemCount,
                metadata: fields["pubDate"].map { ["rssPubDate": $0] }
            )
        {
            results.append(result)
        }
        path.removeLast()
    }

    func parser(
        _ parser: XMLParser, resolveExternalEntityName name: String, systemID: String?
    ) -> Data? {
        invalid = true
        parser.abortParsing()
        return nil
    }
}
