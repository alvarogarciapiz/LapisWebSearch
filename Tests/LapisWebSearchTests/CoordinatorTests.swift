import Foundation
import Testing

@testable import LapisWebSearch

@Suite struct CoordinatorTests {
    @Test func fallbackKeepsFailureAndDeduplicates() async throws {
        let first = StubProvider("first", failure: SearchError(.blocked, httpStatus: 403))
        let second = StubProvider(
            "second",
            response: .results(
                [
                    try result("second"), try result("second", "https://EXAMPLE.org:443/", position: 2),
                    try result("second", "https://example.net", position: 3),
                ], httpStatus: 200))
        let unused = StubProvider("unused")
        let response = try await LapisWebSearch(providers: [first, second, unused]).search("sample", options: .init())
        #expect(response.results.count == 2)
        #expect(response.results[1].originalPosition == 3)
        #expect(response.attempts.count == 2)
        #expect(response.attempts[0].error == .blocked)
        #expect(response.attempts[0].httpStatus == 403)
        #expect(response.attempts[1].wasFallback)
        #expect(await unused.calls == 0)
    }

    @Test func emptyArrayIsInvalidAndFallsBack() async throws {
        let first = StubProvider("first", response: .results([]))
        let second = StubProvider("second", response: .results([try result("second")]))
        let response = try await LapisWebSearch(providers: [first, second]).search("sample", options: .init())
        #expect(response.attempts[0].error == .invalidResponse)
    }

    @Test func noResultsIsDistinct() async throws {
        do {
            _ = try await LapisWebSearch(providers: [StubProvider()]).search("sample")
            Issue.record("Expected failure")
        } catch let error as SearchError {
            #expect(error.code == .noResults)
            #expect(error.attempts.first?.error == .noResults)
        }
    }

    @Test func mixedFailureIsNotNoResults() async throws {
        do {
            _ = try await LapisWebSearch(providers: [
                StubProvider("empty"), StubProvider("failed", failure: SearchError(.unauthorized)),
            ]).search("sample")
            Issue.record("Expected failure")
        } catch let error as SearchError {
            #expect(error.code == .allProvidersUnavailable)
            #expect(error.attempts.count == 2)
        }
    }

    @Test func fallbackDisabled() async throws {
        let next = StubProvider("next")
        await #expect(throws: SearchError.self) {
            try await LapisWebSearch(providers: [StubProvider(), next]).search(
                "sample", options: .init(fallback: false))
        }
        #expect(await next.calls == 0)
    }

    @Test func maximumResultsAndSimpleAPI() async throws {
        let provider = StubProvider(response: .results([try result(), try result("stub", "https://example.net")]))
        #expect(try await LapisWebSearch(providers: [provider]).search("sample", limit: 1).count == 1)
    }

    @Test func duplicateProviderIDsRejected() async throws {
        let provider = StubProvider()
        do {
            _ = try await LapisWebSearch(providers: [provider, provider]).search("sample")
            Issue.record("Expected failure")
        } catch let error as SearchError { #expect(error.code == .invalidConfiguration) }
        #expect(await provider.calls == 0)
    }

    @Test func emptyRegistryRejected() async throws {
        await #expect(throws: SearchError.self) { try await LapisWebSearch(providers: []).search("sample") }
    }

    @Test func spoofedProviderIdentityRejected() async throws {
        let provider = StubProvider(response: .results([try result("different")]))
        do {
            _ = try await LapisWebSearch(providers: [provider]).search("sample")
            Issue.record("Expected failure")
        } catch let error as SearchError { #expect(error.attempts.first?.error == .invalidResponse) }
    }

    @Test func deadlineCancelsProviderAndPreventsFallback() async throws {
        let slow = StubProvider("slow", delay: .seconds(20))
        let next = StubProvider("next")
        let start = ContinuousClock.now
        do {
            _ = try await LapisWebSearch(providers: [slow, next]).search("sample", options: .init(timeout: 1))
            Issue.record("Expected timeout")
        } catch let error as SearchError {
            #expect(error.code == .timeout)
            #expect(error.attempts.first?.error == .timeout)
        }
        #expect(start.duration(to: .now) < .seconds(2))
        #expect(await slow.cancellations == 1)
        #expect(await next.calls == 0)
    }

    @Test func cancellationDoesNotFallback() async throws {
        let slow = StubProvider("slow", delay: .seconds(20))
        let next = StubProvider("next")
        let client = LapisWebSearch(providers: [slow, next])
        let task = Task { try await client.search("sample") }
        while await slow.calls == 0 { await Task.yield() }
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch let error as SearchError { #expect(error.code == .cancelled) }
        #expect(await next.calls == 0)
        try await withinDeadline(ContinuousClock.now.advanced(by: .seconds(2))) {
            while await slow.cancellations == 0 { try await Task.sleep(for: .milliseconds(1)) }
        }
        #expect(await slow.cancellations == 1)
    }

    @Test func preCancelledTaskDoesNotRequest() async throws {
        let provider = StubProvider()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await LapisWebSearch(providers: [provider]).search("sample")
        }
        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch let error as SearchError { #expect(error.code == .cancelled) }
        #expect(await provider.calls == 0)
    }

    @Test func fallbackSharesOverallDeadline() async throws {
        // Keep the first result immediate; this test concerns the shared deadline, not timer ordering.
        let first = StubProvider("first")
        let second = StubProvider("second", delay: .seconds(20))
        do {
            _ = try await LapisWebSearch(providers: [first, second]).search("sample", options: .init(timeout: 1))
            Issue.record("Expected timeout")
        } catch let error as SearchError {
            #expect(error.code == .timeout)
            try #require(error.attempts.count == 2)
            #expect(error.attempts[0].error == .noResults)
            #expect(error.attempts[1].error == .timeout)
        }
        #expect(await second.cancellations == 1)
    }

    @Test func rateLimitCooldownAndInstanceIsolation() async throws {
        let retry = Date().addingTimeInterval(3600)
        let provider = StubProvider(failure: SearchError(.rateLimited, httpStatus: 429, retryAfter: retry))
        let client = LapisWebSearch(providers: [provider])
        for _ in 0..<2 { _ = try? await client.search("sample") }
        #expect(await provider.calls == 1)
        do {
            _ = try await client.search("another")
            Issue.record("Expected cooldown")
        } catch let error as SearchError {
            #expect(error.attempts.first?.skipped == true)
            #expect(error.attempts.first?.retryAfter == retry)
        }
        _ = try? await LapisWebSearch(providers: [provider]).search("sample")
        #expect(await provider.calls == 2)
    }

    @Test func concurrentSearchesQueueInsteadOfFailingBusy() async throws {
        let provider = StubProvider(response: .results([try result()]), delay: .milliseconds(80))
        let client = LapisWebSearch(providers: [provider])
        let first = Task { try await client.search("one") }
        while await provider.calls == 0 { await Task.yield() }
        let second = Task { try await client.search("two", options: .init()) }
        _ = try await first.value
        let response = try await second.value
        #expect(response.results.count == 1)
        #expect(await provider.calls == 2)
        #expect(response.attempts[0].queueDuration > 0)
    }

    @Test func diagnosticsDoNotContainQuery() async throws {
        let secret = "private-query-should-not-appear"
        do { _ = try await LapisWebSearch(providers: [StubProvider()]).search(secret) } catch let error as SearchError {
            let data = try JSONEncoder().encode(error)
            #expect(!String(decoding: data, as: UTF8.self).contains(secret))
            #expect(!error.localizedDescription.contains(secret))
        }
    }
}
