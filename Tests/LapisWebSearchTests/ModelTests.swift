import Foundation
import Testing

@testable import LapisWebSearch

@Suite struct ModelTests {
    @Test(arguments: ["", "  \n ", String(repeating: "a", count: 501), "hello\u{0}", "bad\r\nheader"])
    func invalidQuery(_ query: String) {
        #expect(throws: SearchError.self) { try SearchRequest(query: query) }
    }

    @Test(arguments: [0, -1, 101]) func invalidLimit(_ limit: Int) {
        #expect(throws: SearchError.self) { try SearchRequest(query: "sample", options: .init(limit: limit)) }
    }

    @Test(arguments: [0.0, -1.0, Double.nan, Double.infinity, 301]) func invalidTimeout(_ timeout: Double) {
        #expect(throws: SearchError.self) { try SearchRequest(query: "sample", options: .init(timeout: timeout)) }
    }

    @Test(arguments: ["", "es_ES", "en\r\nHeader: x"]) func invalidLocale(_ locale: String) {
        #expect(throws: SearchError.self) { try SearchRequest(query: "sample", options: .init(locale: locale)) }
    }

    @Test(arguments: [
        "file:///etc/passwd", "javascript:alert(1)", "/relative", "https://user:pass@example.org",
        "mailto:a@example.org",
    ])
    func unsafeURLs(_ raw: String) {
        #expect(throws: SearchError.self) { try result("stub", raw) }
    }

    @Test func conservativeNormalization() throws {
        #expect(try result("stub", "https://EXAMPLE.org:443").url.absoluteString == "https://example.org/")
        #expect(
            try result("stub", "http://EXAMPLE.org:80/Path?b=2&a=1#chapter").url.absoluteString
                == "http://example.org/Path?b=2&a=1#chapter")
        #expect(try result("stub", "https://example.org/A").url != result("stub", "https://example.org/a").url)
        #expect(try result("stub", "https://example.org/#one").url != result("stub", "https://example.org/#two").url)
    }

    @Test func internationalTextAndNoInventedMetadata() throws {
        let result = try SearchResult(
            title: "  Últimas\n noticias 日本語 🪨", url: URL(string: "https://example.org")!, snippet: "  café\t中文  ",
            provider: "custom", originalPosition: 2)
        #expect(result.title == "Últimas noticias 日本語 🪨")
        #expect(result.snippet == "café 中文")
        #expect(result.metadata == nil)
        #expect(result.publishedAt == nil)
    }

    @Test func invalidResultFields() {
        #expect(throws: SearchError.self) {
            try SearchResult(
                title: " \n", url: URL(string: "https://example.org")!, snippet: "", provider: "stub",
                originalPosition: 1)
        }
        #expect(throws: SearchError.self) { try result(position: 0) }
    }
}
