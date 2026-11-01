import Foundation
import Testing

@testable import LapisWebSearch

@Suite struct ConcurrencyTests {
    @Test func identicalSearchesShareOneRequest() async throws {
        let provider = StubProvider(response: .results([try result()]), delay: .milliseconds(80))
        let client = LapisWebSearch(providers: [provider])
        async let a = client.search("same", options: .init())
        async let b = client.search("same", options: .init())
        let responses = try await [a, b]
        #expect(await provider.calls == 1)
        #expect(responses.filter(\.wasCoalesced).count == 1)
        #expect(responses.allSatisfy { $0.results.count == 1 })
        _ = try await client.search("same")
        #expect(await provider.calls == 2)  // No completed-result cache.
    }

    @Test func cancellingOneSubscriberPreservesTheOther() async throws {
        let provider = StubProvider(response: .results([try result()]), delay: .milliseconds(150))
        let client = LapisWebSearch(providers: [provider])
        let first = Task { try await client.search("same") }
        while await provider.calls == 0 { await Task.yield() }
        let second = Task { try await client.search("same") }
        try await Task.sleep(for: .milliseconds(20))
        first.cancel()
        do {
            _ = try await first.value
            Issue.record("Expected cancellation")
        } catch let error as SearchError { #expect(error.code == .cancelled) }
        #expect(try await second.value.count == 1)
        #expect(await provider.calls == 1)
        #expect(await provider.cancellations == 0)
    }

    @Test func lastSubscriberCancellationReleasesCapacity() async throws {
        let provider = StubProvider(delay: .seconds(20))
        let client = LapisWebSearch(providers: [provider])
        let first = Task { try await client.search("same") }
        while await provider.calls == 0 { await Task.yield() }
        first.cancel()
        _ = await first.result
        let response = await Task { try await client.search("new", options: .init(timeout: 0.1)) }.result
        if case .failure(let error) = response {
            #expect((error as? SearchError)?.code == .timeout)
        } else {
            Issue.record("Expected timeout")
        }
        #expect(await provider.calls == 2)
        #expect(await provider.cancellations == 2)
    }

    @Test func perProviderTimeoutLeavesFallbackBudget() async throws {
        let slow = StubProvider("slow", delay: .seconds(20))
        let fast = StubProvider("fast", response: .results([try result("fast")]))
        let response = try await LapisWebSearch(providers: [slow, fast]).search(
            "sample", options: .init(timeout: 2, providerTimeout: 0.05))
        #expect(response.results.first?.provider == "fast")
        #expect(response.attempts[0].error == .timeout)
        #expect(await slow.cancellations == 1)
    }

    @Test func raceReturnsFastProviderAndCancelsLoser() async throws {
        let slow = StubProvider("slow", response: .results([try result("slow")]), delay: .seconds(20))
        let fast = StubProvider("fast", response: .results([try result("fast")]), delay: .milliseconds(20))
        let response = try await LapisWebSearch(providers: [slow, fast]).search(
            "sample", options: .init(strategy: .firstSuccess))
        #expect(response.results.first?.provider == "fast")
        #expect(response.attempts.count == 2)
        #expect(response.attempts.first?.error == .cancelled)
        #expect(response.attempts.allSatisfy { !$0.wasFallback })
        #expect(await slow.cancellations == 1)
        #expect(response.configuration?.strategy == .firstSuccess)
    }

    @Test func raceAdvancesAfterFailuresAndIsBounded() async throws {
        let first = StubProvider("first", failure: SearchError(.blocked))
        let slow = StubProvider("slow", delay: .seconds(20))
        let third = StubProvider("third", response: .results([try result("third")]))
        let unused = StubProvider("unused", delay: .seconds(20))
        let response = try await LapisWebSearch(providers: [first, slow, third, unused]).search(
            "sample", options: .init(strategy: .firstSuccess))
        #expect(response.results.first?.provider == "third")
        #expect(await unused.calls == 0)
        #expect(response.attempts.count == 3)
        #expect(await slow.cancellations == 1)
    }

    @Test func differentOptionsNeverCoalesce() async throws {
        let provider = StubProvider(response: .results([try result()]), delay: .milliseconds(30))
        let client = LapisWebSearch(providers: [provider])
        async let a = client.search("same", limit: 1)
        async let b = client.search("same", limit: 2)
        _ = try await [a, b]
        #expect(await provider.calls == 2)
    }

    @Test func queuedRequestDeadlineIncludesWait() async throws {
        let provider = StubProvider(delay: .seconds(20))
        let client = LapisWebSearch(providers: [provider], configuration: .init(maximumConcurrentSearches: 1))
        let first = Task { try await client.search("first") }
        while await provider.calls == 0 { await Task.yield() }
        do {
            _ = try await client.search("queued", options: .init(timeout: 0.03))
            Issue.record("Expected timeout")
        } catch let error as SearchError { #expect(error.code == .timeout) }
        #expect(await provider.calls == 1)
        first.cancel()
        _ = await first.result
    }

    @Test func queuedCancellationDoesNotConsumePermit() async throws {
        let gate = AsyncGate(limit: 1)
        let first = Task { try await gate.withPermit { try await Task.sleep(for: .milliseconds(100)) } }
        try await Task.sleep(for: .milliseconds(10))
        let queued = Task { try await gate.withPermit { 1 } }
        try await Task.sleep(for: .milliseconds(10))
        queued.cancel()
        _ = await queued.result
        _ = try await first.value
        #expect(try await gate.withPermit { 2 } == 2)
    }

    @Test func pendingSubscriberLimitIsBounded() async throws {
        let provider = StubProvider(delay: .seconds(20))
        let client = LapisWebSearch(providers: [provider], configuration: .init(maximumPendingSearches: 1))
        let first = Task { try await client.search("first") }
        while await provider.calls == 0 { await Task.yield() }
        do {
            _ = try await client.search("first")
            Issue.record("Expected capacity error")
        } catch let error as SearchError { #expect(error.code == .providerBusy) }
        first.cancel()
        _ = await first.result
    }

    @Test func disablingCoalescingPreservesIndependentRequests() async throws {
        let provider = StubProvider(response: .results([try result()]), delay: .milliseconds(20))
        let client = LapisWebSearch(providers: [provider], configuration: .init(coalesceIdenticalRequests: false))
        async let a = client.search("same")
        async let b = client.search("same")
        _ = try await [a, b]
        #expect(await provider.calls == 2)
    }

    @Test func invalidConcurrencyConfigurationFailsBeforeNetworking() async throws {
        let provider = StubProvider()
        let client = LapisWebSearch(providers: [provider], configuration: .init(maximumConcurrentSearches: 0))
        await #expect(throws: SearchError.self) { try await client.search("sample") }
        #expect(await provider.calls == 0)
    }

    @Test func queuedRequestsObserveNewRateLimit() async throws {
        let provider = StubProvider(failure: SearchError(.rateLimited, httpStatus: 429), delay: .milliseconds(50))
        let client = LapisWebSearch(providers: [provider])
        let first = Task { try? await client.search("first") }
        while await provider.calls == 0 { await Task.yield() }
        let second = Task { try? await client.search("second") }
        _ = await first.value
        _ = await second.value
        #expect(await provider.calls == 1)
    }

    @Test func newOptionsValidate() throws {
        #expect(throws: SearchError.self) {
            try SearchRequest(query: "sample", options: .init(fallback: false, strategy: .firstSuccess))
        }
        #expect(throws: SearchError.self) { try SearchRequest(query: "sample", options: .init(providerTimeout: .nan)) }
        #expect(throws: SearchError.self) { try SearchRequest(query: "sample", options: .init(country: "España")) }
        #expect(try SearchRequest(query: "café", options: .init(country: "es")).options.country == "ES")
    }
}

private actor ActiveProvider: SearchProvider {
    nonisolated let identifier = "active"
    var active = 0
    var peak = 0
    func search(_ request: SearchRequest) async throws -> ProviderResponse {
        active += 1
        peak = max(peak, active)
        defer { active -= 1 }
        try await Task.sleep(for: .milliseconds(50))
        return .results([try result(identifier)])
    }
}

@Suite struct AdmissionTests {
    @Test(arguments: [1, 2]) func perProviderLimitIsEnforced(_ limit: Int) async throws {
        let provider = ActiveProvider()
        let client = LapisWebSearch(
            providers: [provider], configuration: .init(maximumConcurrentRequestsPerProvider: limit))
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<4 { group.addTask { _ = try await client.search("query \(index)") } }
            try await group.waitForAll()
        }
        #expect(await provider.peak == limit)
        #expect(await provider.active == 0)
    }

    @Test func globalLimitAlsoBoundsAdmittedSearches() async throws {
        let provider = ActiveProvider()
        let client = LapisWebSearch(
            providers: [provider],
            configuration: .init(maximumConcurrentSearches: 1, maximumConcurrentRequestsPerProvider: 4))
        async let a = client.search("one")
        async let b = client.search("two")
        _ = try await [a, b]
        #expect(await provider.peak == 1)
    }

    @Test func cancelledQueuedProviderDoesNotBlockNextSearch() async throws {
        let provider = ActiveProvider()
        let client = LapisWebSearch(providers: [provider])
        let first = Task { try await client.search("first") }
        while await provider.active == 0 { await Task.yield() }
        let queued = Task { try await client.search("queued") }
        queued.cancel()
        _ = await queued.result
        _ = try await first.value
        #expect(try await client.search("last").count == 1)
        #expect(await provider.active == 0)
    }

    @Test func coalescedDiagnosticsDoNotExposeQuery() async throws {
        let provider = ActiveProvider()
        let client = LapisWebSearch(providers: [provider])
        let response = try await client.search("sensitive-text-never-in-diagnostics", options: .init())
        let diagnostics = try JSONEncoder().encode(response.configuration)
        #expect(!String(decoding: diagnostics, as: UTF8.self).contains("sensitive-text"))
        #expect(response.configuration?.providers == ["active"])
    }
}
