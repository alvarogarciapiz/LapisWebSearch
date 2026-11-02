import Foundation
import Testing

@testable import LapisWebSearch

@Suite struct ProviderTests {
    @Test func firecrawlFixtureAndEncoding() async throws {
        let transport = StubTransport(try fixture("firecrawl", "json"))
        let provider = FirecrawlProvider(transport: transport)
        let query = "Últimas novedades + Swift & 日本語?"
        let response = try await provider.search(SearchRequest(query: query, options: .init(safeSearch: true)))
        guard case .results(let rows, let status) = response else {
            Issue.record("Expected results")
            return
        }
        #expect(status == 200)
        #expect(rows.count == 2)
        #expect(rows[0].title == "Swift concurrency")
        #expect(rows[0].snippet.contains("日本語"))
        #expect(rows[1].originalPosition == 4)
        #expect(rows.allSatisfy { $0.publishedAt == nil })
        let request = try #require(await transport.requests.first)
        #expect(request.url?.absoluteString == "https://api.firecrawl.dev/v2/search")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        let bodyData = try #require(request.httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        #expect(body["query"] as? String == query)
        #expect(body["sources"] as? [String] == ["web"])
        #expect(body["scrapeOptions"] == nil)
        #expect(body["safe"] as? Bool == true)
        #expect(body["highlights"] as? Bool == false)
    }

    @Test(arguments: [
        "", "{", "{}", "{\"success\":false}", "{\"success\":true,\"data\":{}}",
        "{\"success\":true,\"data\":{\"web\":[{}]}}",
    ])
    func invalidFirecrawl(_ text: String) async throws {
        let provider = FirecrawlProvider(transport: StubTransport(Data(text.utf8)))
        await #expect(throws: SearchError.self) { try await provider.search(SearchRequest(query: "sample")) }
    }

    @Test func explicitEmptyFirecrawl() async throws {
        let provider = FirecrawlProvider(transport: StubTransport(Data(#"{"success":true,"data":{"web":[]}}"#.utf8)))
        guard case .noResults = try await provider.search(SearchRequest(query: "sample")) else {
            Issue.record("Expected noResults")
            return
        }
    }

    @Test func localeUnsupportedWithoutNetwork() async throws {
        let transport = StubTransport()
        await #expect(throws: SearchError.self) {
            try await FirecrawlProvider(transport: transport).search(
                SearchRequest(query: "sample", options: .init(locale: "es-ES")))
        }
        #expect(await transport.requests.isEmpty)
    }

    @Test func bingRestrictionsBeforeNetwork() async throws {
        let transport = StubTransport()
        await #expect(throws: SearchError.self) {
            try await BingRSSProvider(transport: transport).search(SearchRequest(query: "sample"))
        }
        await #expect(throws: SearchError.self) {
            try await BingRSSProvider(hasSeparatePermission: true, transport: transport)
                .search(SearchRequest(query: "sample", options: .init(safeSearch: true)))
        }
        #expect(await transport.requests.isEmpty)
    }

    @Test func bingXMLAndQueryEncoding() async throws {
        let transport = StubTransport(try fixture("bing", "xml"), type: "text/xml; charset=utf-8")
        let query = "electricidad España & 日本 + 100% #RSS"
        let response = try await BingRSSProvider(hasSeparatePermission: true, transport: transport)
            .search(SearchRequest(query: query, options: .init(locale: "es-ES")))
        guard case .results(let rows, _) = response else {
            Issue.record("Expected results")
            return
        }
        #expect(rows.count == 2)
        #expect(rows[0].title == "Swift & español")
        #expect(rows[0].snippet == "Hello 日本語 world")
        #expect(rows[1].originalPosition == 3)
        #expect(rows[0].publishedAt == nil)
        #expect(rows[0].metadata?["rssPubDate"] != nil)
        let request = try #require(await transport.requests.first)
        let url = try #require(request.url)
        let parts = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(parts.queryItems?.first(where: { $0.name == "q" })?.value == query)
        #expect(formQueryValue(url, name: "q") == query)
        #expect(parts.queryItems?.first(where: { $0.name == "mkt" })?.value == "es-ES")
    }

    @Test(arguments: [
        "", "<rss>", "<html><body>Blocked</body></html>", "<rss/>",
        "<rss><channel><item><title>Missing URL</title></item></channel></rss>",
        "<!DOCTYPE rss [<!ENTITY x SYSTEM 'file:///etc/passwd'>]><rss><channel>&x;</channel></rss>",
        "<!DOCTYPE rss [<!ENTITY x 'boom'>]><rss><channel>&x;</channel></rss>",
    ])
    func unsafeOrMalformedXML(_ xml: String) {
        #expect(throws: SearchError.self) { try RSSDecoder.decode(Data(xml.utf8), provider: "bing-rss") }
    }

    @Test func zeroRSS() throws {
        #expect(try RSSDecoder.decode(Data("<rss><channel/></rss>".utf8), provider: "bing-rss").isEmpty)
    }

    @Test func nonUTF8CannotBypassEntityGuard() throws {
        let xml =
            "<?xml version=\"1.0\" encoding=\"UTF-16\"?><!DOCTYPE rss [<!ENTITY x 'expanded'>]><rss><channel>&x;</channel></rss>"
        let data = try #require(xml.data(using: .utf16LittleEndian))
        #expect(throws: SearchError.self) { try RSSDecoder.decode(data, provider: "bing-rss") }
    }

    @Test func excessiveXMLNesting() {
        let xml =
            "<rss><channel>" + String(repeating: "<x>", count: 40) + String(repeating: "</x>", count: 40)
            + "</channel></rss>"
        #expect(throws: SearchError.self) { try RSSDecoder.decode(Data(xml.utf8), provider: "bing-rss") }
    }

    @Test func mixedMalformedRowsAreSkipped() async throws {
        let body =
            #"{"success":true,"data":{"web":[null,7,"x",{"url":"https://example.org","title":"Good","position":-1}]}}"#
        let response = try await FirecrawlProvider(transport: StubTransport(Data(body.utf8))).search(
            SearchRequest(query: "sample"))
        guard case .results(let rows, _) = response else {
            Issue.record("Expected results")
            return
        }
        #expect(rows.count == 1)
        #expect(rows[0].originalPosition == 4)
    }
}
