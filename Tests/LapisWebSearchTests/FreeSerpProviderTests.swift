import Foundation
import Testing

@testable import LapisWebSearch

@Suite struct FreeSerpProviderTests {
    @Test func nativeJSONNormalizationAndProvenance() async throws {
        let transport = StubTransport(try fixture("freeserp", "json"))
        let response = try await FreeSerpProvider(transport: transport).search(.init(query: "café 日本語"))
        guard case .results(let results, let status) = response else {
            Issue.record("Expected results")
            return
        }
        #expect(status == 200)
        #expect(results.count == 2)
        #expect(results[0].title == "Investigación española 日本語")
        #expect(results[0].snippet == "Café & Swift")
        #expect(results[0].metadata == ["language": "es"])
        #expect(results[0].publishedAt == ISO8601DateFormatter().date(from: "2026-10-30T00:00:00Z"))
        #expect(results[1].publishedAt == nil)
        #expect(results[1].originalPosition == 4)
        #expect(results.allSatisfy { $0.provider == "freeserp" })
        #expect(await transport.requests.count == 1)
    }

    @Test func encodingLanguageAndNoExtraContentRequests() async throws {
        let transport = StubTransport(try fixture("freeserp", "json"))
        let query = "café + C++ & #日本語?"
        _ = try await FreeSerpProvider(transport: transport).search(
            .init(query: query, options: .init(limit: 2, timeout: 3, locale: "es")))
        let http = try #require(await transport.requests.first)
        let parts = try #require(URLComponents(url: http.url!, resolvingAgainstBaseURL: false))
        let values = Dictionary(uniqueKeysWithValues: parts.queryItems!.map { ($0.name, $0.value!) })
        #expect(http.url?.scheme == "https")
        #expect(http.url?.host == "freeserp.ai")
        #expect(http.url?.path == "/api.php")
        #expect(http.timeoutInterval == 3)
        #expect(http.httpBody == nil)
        #expect(values == ["index": "web", "q": query, "size": "2", "lang": "es"])
        #expect(formQueryValue(http.url!, name: "q") == query)
        #expect(http.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test(arguments: [
        SearchOptions(locale: "es-ES"), SearchOptions(locale: "EN"), SearchOptions(safeSearch: true),
        SearchOptions(country: "ES"), SearchOptions(timeRange: .month),
    ]) func unsupportedOptionsDoNotContactProvider(_ options: SearchOptions) async throws {
        let transport = StubTransport()
        do {
            _ = try await FreeSerpProvider(transport: transport).search(.init(query: "test", options: options))
            Issue.record("Expected unsupported option")
        } catch let error as SearchError { #expect(error.code == .unsupportedOperation) }
        #expect(await transport.requests.isEmpty)
    }

    @Test(arguments: [
        #"{"ok":true,"index":"sites","total":0,"results":[]}"#,
        #"{"ok":true,"index":"web","engine_fallback":true,"total":0,"results":[]}"#,
        #"{"ok":false,"index":"web","total":0,"results":[]}"#,
        #"{"ok":true,"index":"web","total":5,"results":[]}"#,
        #"{"ok":true,"index":"web","total":1,"results":[{"url":"file:///tmp/a","title":"Bad"}]}"#,
    ]) func invalidSetsAreNotSuccessful(_ body: String) async throws {
        do {
            _ = try await FreeSerpProvider(transport: StubTransport(Data(body.utf8))).search(.init(query: "test"))
            Issue.record("Expected invalid response")
        } catch let error as SearchError {
            #expect(error.code == .invalidResponse)
            #expect(error.httpStatus == 200)
        }
    }

    @Test func explicitZeroResults() async throws {
        let transport = StubTransport(Data(#"{"ok":true,"index":"web","total":0,"results":[]}"#.utf8))
        guard
            case .noResults(let status) = try await FreeSerpProvider(transport: transport).search(.init(query: "test"))
        else {
            Issue.record("Expected noResults")
            return
        }
        #expect(status == 200)
    }

    @Test(arguments: ["{}", "[1,2]", "", "{", #"{"ok":true,"index":"web","results":[]}"#])
    func malformedResponse(_ body: String) async throws {
        do {
            _ = try await FreeSerpProvider(transport: StubTransport(Data(body.utf8))).search(.init(query: "test"))
            Issue.record("Expected parsing failure")
        } catch let error as SearchError { #expect(error.code == .parsingFailure) }
    }

    @Test(arguments: [403, 429, 500]) func httpFailures(_ status: Int) async throws {
        let transport = StubTransport(status: status, retry: "120")
        do {
            _ = try await FreeSerpProvider(transport: transport).search(.init(query: "test"))
            Issue.record("Expected HTTP failure")
        } catch let error as SearchError {
            #expect(error.httpStatus == status)
            #expect(error.code == (status == 403 ? .blocked : status == 429 ? .rateLimited : .serverError))
            if status == 429 { #expect(error.retryAfter != nil) }
        }
    }

    @Test func challengePageIsBlocked() async throws {
        let transport = StubTransport(Data("<html><title>CAPTCHA challenge</title></html>".utf8), type: "text/html")
        do {
            _ = try await FreeSerpProvider(transport: transport).search(.init(query: "test"))
            Issue.record("Expected blocked")
        } catch let error as SearchError { #expect(error.code == .blocked) }
    }

    @Test func wrongContentType() async throws {
        let transport = StubTransport(Data("<html>Not JSON</html>".utf8), type: "text/html")
        do {
            _ = try await FreeSerpProvider(transport: transport).search(.init(query: "test"))
            Issue.record("Expected invalid response")
        } catch let error as SearchError { #expect(error.code == .invalidResponse) }
    }

    @Test func oversizedResponse() async throws {
        let transport = StubTransport(Data(repeating: 32, count: 2 * 1024 * 1024 + 1))
        do {
            _ = try await FreeSerpProvider(transport: transport).search(.init(query: "test"))
            Issue.record("Expected responseTooLarge")
        } catch let error as SearchError { #expect(error.code == .responseTooLarge) }
    }

    @Test(arguments: [SearchError.Code.timeout, .cancelled, .networkUnavailable])
    func transportFailurePropagation(_ code: SearchError.Code) async throws {
        do {
            _ = try await FreeSerpProvider(transport: StubTransport(error: SearchError(code))).search(
                .init(query: "test"))
            Issue.record("Expected failure")
        } catch let error as SearchError { #expect(error.code == code) }
    }

    @Test func fallbackAfterRejectedIndexRetainsDiagnostics() async throws {
        let first = FreeSerpProvider(
            transport: StubTransport(Data(#"{"ok":true,"index":"sites","total":0,"results":[]}"#.utf8)))
        let second = StubProvider(response: .results([try result()]))
        let response = try await LapisWebSearch(providers: [first, second]).search("test", options: .init())
        #expect(response.attempts[0].error == .invalidResponse)
        #expect(response.attempts[1].wasFallback)
        #expect(response.results.first?.provider == "stub")
    }
}
