import Foundation
import Testing

@testable import LapisWebSearch

@Suite struct ProviderPolicyTests {
    @Test func defaultDoesNotSelectAnExternalService() async throws {
        do {
            _ = try await LapisWebSearch().search("not transmitted")
            Issue.record("Expected no eligible provider")
        } catch let error as SearchError {
            #expect(error.code == .noEligibleProviders)
            #expect(error.attempts.isEmpty)
        }
    }

    @Test func customProvidersAreUnverifiedByDefault() {
        #expect(StubProvider().usage.status == .unverified)
        #expect(!StubProvider().usage.permitsCommercialDeployment)
    }

    @Test func bundledAdaptersHaveNoCommercialClearance() {
        let providers: [any SearchProvider] = [
            FirecrawlProvider(), ParallelSearchProvider(), FreeSerpProvider(), BingRSSProvider(),
        ]
        for provider in providers {
            #expect(!provider.usage.permitsCommercialDeployment)
            #expect(!provider.usage.evidence.isEmpty)
        }
    }

    @Test(arguments: [SearchStrategy.sequential, .firstSuccess])
    func strictPolicyValidatesAllFallbacksBeforeAnyCall(_ strategy: SearchStrategy) async throws {
        let first = DeclaredProvider(status: .commerciallyCleared)
        let second = StubProvider("unverified")
        do {
            _ = try await LapisWebSearch(
                providers: [first, second], configuration: .init(providerPolicy: .requireCommercialClearance)
            ).search("not transmitted", options: .init(strategy: strategy))
            Issue.record("Expected policy rejection")
        } catch let error as SearchError {
            #expect(error.code == .providerNotPermitted)
            #expect(error.attempts.isEmpty)
            #expect(error.configuration?.providerPolicy == .requireCommercialClearance)
            #expect(!String(decoding: try JSONEncoder().encode(error), as: UTF8.self).contains("not transmitted"))
        }
        #expect(await first.calls == 0)
        #expect(await second.calls == 0)
    }

    @Test(arguments: [CommercialUseStatus.unverified, .restricted, .conditionallyPermitted, .technicallyUnavailable])
    func nonClearedStatusesAreRejected(_ status: CommercialUseStatus) async throws {
        let provider = DeclaredProvider(status: status)
        await #expect(throws: SearchError.self) {
            try await LapisWebSearch(
                providers: [provider], configuration: .init(providerPolicy: .requireCommercialClearance)
            ).search("test")
        }
        #expect(await provider.calls == 0)
    }

    @Test func clearanceNeedsEvidence() {
        #expect(!ProviderUsage(status: .commerciallyCleared).permitsCommercialDeployment)
        #expect(
            !ProviderUsage(status: .commerciallyCleared, evidence: [URL(string: "http://example.org/terms")!])
                .permitsCommercialDeployment)
        #expect(
            !ProviderUsage(
                status: .commerciallyCleared, evidence: [URL(string: "https://user:pass@example.org/terms")!]
            ).permitsCommercialDeployment)
    }

    @Test func explicitlyClearedCustomProviderCanRun() async throws {
        let provider = DeclaredProvider(status: .commerciallyCleared)
        let response = try await LapisWebSearch(
            providers: [provider], configuration: .init(providerPolicy: .requireCommercialClearance)
        ).search("test", options: .init())
        #expect(response.results.count == 1)
        #expect(response.configuration?.providerPolicy == .requireCommercialClearance)
        #expect(await provider.calls == 1)
    }

    @Test func explicitEvaluationRemainsAvailable() async throws {
        let provider = StubProvider(response: .results([try result()]))
        #expect(try await LapisWebSearch(providers: [provider]).search("test").count == 1)
        #expect(await provider.calls == 1)
    }
}

/// Synthetic clearance is only a policy test; it is not evidence that an external service is cleared.
private actor DeclaredProvider: SearchProvider {
    nonisolated let identifier = "declared"
    nonisolated let usage: ProviderUsage
    var calls = 0
    init(status: CommercialUseStatus) {
        usage = .init(status: status, evidence: [URL(string: "https://example.org/terms")!])
    }
    func search(_ request: SearchRequest) async throws -> ProviderResponse {
        calls += 1
        return .results([try result(identifier)])
    }
}
