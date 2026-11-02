# Application integration

Add the SPM library product to an iOS/iPadOS 16+ or macOS 13+ target. Use Swift 6 concurrency checking. Pin a reviewed revision during experimental development. No AI or UI framework is required. Sandboxed macOS apps need the outgoing network client entitlement; the package cannot grant app entitlements.

```swift
import LapisWebSearch

let search = LapisWebSearch(providers: [FirecrawlProvider()]) // Explicit, permitted evaluation only.
let response = try await search.search(
    "Apple Foundation Models Swift documentation",
    options: SearchOptions(limit: 5, timeout: 15, safeSearch: true)
)
for item in response.results {
    print(item.title, item.url, item.snippet)
}
```

Keep a client for the lifetime of a search feature to preserve cooldowns. Cancellation of the calling task cancels native requests; handle `SearchError.code == .cancelled`. Use `SearchError.attempts` for failure diagnostics, and `SearchResponse.attempts` on success. Different queries queue within the client/provider bounds. An overall deadline includes that queue; a full pending limit produces providerBusy.

The independent executable package in `Examples/Consumer` imports only the public module and supplies a synthetic provider for an offline smoke check:

```sh
swift run --package-path Examples/Consumer ConsumerSmoke
```

## Custom provider

This complete offline example demonstrates the contract without fabricating a live result:

```swift
import LapisWebSearch

struct EmptyExampleProvider: SearchProvider {
    let identifier = "empty-example"
    func search(_ request: SearchRequest) async throws -> ProviderResponse {
        try Task.checkCancellation()
        return .noResults()
    }
}

let custom = LapisWebSearch(providers: [EmptyExampleProvider(), FirecrawlProvider()])
```

A real adapter must construct genuine results with its own provider identifier and original position. Return `.noResults` only when the upstream response explicitly represents a valid empty search. Throw `SearchError` for blocking, quota exhaustion and malformed responses. Cap payloads, honor cancellation and assess service rights independently. Advertise capabilities only when implemented. Built-in endpoints cannot be redirected or overridden to arbitrary hosts; custom providers own their destinations.

## Later Lapis replacement task

Do not integrate automatically while the commercial authorization and device/network validation gates remain open. This repository has made no application edits.

When those gates are resolved, the later task should:

1. Add the pinned SPM product to both native application targets. Keep Lapis's existing tool registry, MLX/Foundation Models tool execution and user search consent controls.
2. Implement a thin adapter at the existing discovery-provider seam. Retain one `LapisWebSearch` instance and call `search(_:options:)` with the explicitly authorized query, application result bound and remaining retrieval deadline. Do not forward conversation history or attachments. Do not set a locale on Firecrawl; preserve the query language. Do not enable Bing without separate written permission.
3. Map `title`, `url`, `snippet`, `provider`, `originalPosition` and optional actual publication date into Lapis's existing discovery/evidence models. Preserve order and source provenance. Bing `rssPubDate` is raw feed metadata, not evidence of publication time.
4. Keep page fetching, PublicWebTransport safeguards, SwiftReadability, relevance/BM25, Context Engine budgeting, citation receipts and source UI in Lapis. Do not duplicate them in this package or fetch pages through Firecrawl search options.
5. Map `cancelled` to a quiet cancelled state; `noResults` to an empty-search explanation; and `allProvidersUnavailable` plus attempts to actionable unavailable/rate-limited/blocked UI. Preserve failures and Retry-After locally; do not log full queries. Do not retry automatically around this library's cooldown.
6. Reuse existing search progress UI around the single awaited discovery operation. This initial API provides final attempt diagnostics, not a streaming progress callback. Keep feature enablement gated until real app requests on physical target hardware and ordinary networks pass.
7. Add application-level tests for this mapping and cancellation, then explicitly authorized live requests through the real tool path. A package unit test or curl response is insufficient to enable production search.

An AI application can expose the returned discovery records to its existing tool pipeline as untrusted source data. The package does not build prompts, rank extracted passages, manage a context window or produce citations.

## Phase 2 concurrency and provider choices

The original public search/provider contract remains usable. New initializer configuration and SearchOptions arguments have defaults. Retain one client per end user; copies share its coordinator. Concurrent identical calls now share a job, and different queries queue within bounded limits rather than being refused as provider-busy. Apps can opt out with `SearchConfiguration(coalesceIdenticalRequests: false)` or explicitly allow more requests per provider within its quotas. Keep output sharing within one end-user scope, consistent with service terms.

A safe latency budget for an explicitly authorized experiment can use `SearchOptions(timeout: 8, providerTimeout: 3)`: queue time consumes the overall budget, and an admitted slow provider cannot consume the full eight seconds. `strategy: .firstSuccess` races up to `maximumParallelProviders` configured services, cancels losers and can return a faster, weaker result set. Avoid wrapping it in another automatic retry loop. Cancellation is surfaced as SearchError.cancelled; cancelling one subscriber does not cancel other identical subscribers.

`ParallelSearchProvider()` is an explicit documented keyless research option; it is not silently selected by the default initializer. It rejects locale/country/time-range/safe-search overrides in keyless mode and quoted queries rather than rewriting or dropping them. Firecrawl now accepts `country: "ES"` and `timeRange: .month` while still rejecting locale. These options do not guarantee freshness. The later Lapis adapter should pass them only when the user's/tool's explicit request calls for them.

For local development, the package and thin discovery mapping are ready to exercise. Opt-in experimental integration is technically feasible subject to applicable provider evaluation permission and clear query-disclosure controls. Public production replacement remains blocked on service/distribution authorization, physical/multiple-network and real app-tool-path validation. This phase performs no Lapis edits. The existing seven-step replacement procedure above still applies; page extraction, BM25, context budgeting, citation receipts and tool execution remain in Lapis.


## V3 selection migration

Parameterless `LapisWebSearch()` now returns `noEligibleProviders` without contacting any service. Select adapters explicitly; `FreeSerpProvider()` adds a documented full-web JSON experiment, accepts language-only `locale: "es"` and rejects regional `es-ES`, safe search, country and relative-date options. It is not silently substituted for a failed service. Returned page publication dates never use a crawl/discovery date as a substitute.

For a commercial app, use `SearchConfiguration(providerPolicy: .requireCommercialClearance)` with a reviewed, authorized provider set. It checks every fallback before making requests. All bundled `usage` assessments currently fail this policy; conditional permission is also insufficient. Do not declare a provider cleared merely to bypass this check. If written authorization is obtained, a thin forwarding SearchProvider can expose its deployment-scoped assessment and evidence while delegating search/capabilities to the existing adapter. Keep confidential agreement text out of public source.

Map `noEligibleProviders` to feature unavailable/configuration required and `providerNotPermitted` to deployment policy rejection. Neither initial rejection is a provider outage or reason to retry. Keep provider/query consent visible at the application level. No global Lapis server, shared credentials or hidden paid fallback should be introduced.

The later Lapis task should use the existing discovery seam and the seven steps above. Local development and opt-in permitted experiments are possible; production integration remains blocked on the [commercial audit](research/COMMERCIAL_USE_AUDIT.md) and physical/app-path validation. This repository does not integrate or modify Lapis.
