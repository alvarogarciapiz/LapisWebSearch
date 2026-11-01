# Limitations and pending gates

- **Rights:** keyless evaluation access is not a production authorization or SLA. Firecrawl still requires express commercial authorization. Parallel's production/account and output-use conditions need application-specific review. Bing remains gated. You.com's benchmark-publication restriction prevented its evaluation here. No legal clearance is asserted.
- **Independent services:** Firecrawl and Parallel are different operators, but underlying indexes, upstream dependencies and correlated outages were not independently established. No real outage-triggered live fallback was measured.
- **Sample size:** ten retrieval queries per current provider, four paired queries, two race cases and one burst cannot estimate broad availability, p95 tails, all languages or all intents. The corpus contains fifty entries; forty were not run in this relevance matrix.
- **Labels:** one unblinded agent-assisted reviewer, no independent human panel, no exhaustive qrels and no factual page audit. Partial relevance receives gain in pooled nDCG but does not count as a Success@5/Precision@5 hit. Dynamic pages/snippets and date errors can change grades. URL aliases may inflate precision without adding diversity.
- **Reproducibility:** public metadata, inputs and scorers reproduce the reported arithmetic. Original full provider responses remain local because output redistribution rights are not unrestricted. Exact retrospective content/grade reproduction therefore requires separate permission; authorized fresh reruns may return different results.
- **Timing:** same network, small samples, uncontrolled service/cache/load and partial warm/cold differences. Synthetic 1 MiB transport measurements isolate client overhead and do not predict Internet latency. No performance claim is based only on HTTP status.
- **Concurrency:** race mode can multiply disclosures and quota and return a faster, less relevant service. Default per-provider concurrency is one; applications can explicitly permit more within service limits. Sharing is within a client representing one end user, never a cross-customer cache. Custom providers must cooperate with cancellation; Swift cannot forcibly stop an uncooperative async operation.
- **Cancellation:** individual callers stop waiting promptly. The last subscriber cancels upstream asynchronously; immediate caller cancellation may not have a completed attempt record yet. Race responses wait for cooperative loser cleanup and retain loser attempts. Server-side billing/work may continue after local cancellation.
- **Privacy:** retained connections and MCP sessions can correlate calls at providers even without cookies or device identifiers. Query/IP disclosure remains. No ZDR, offline, anonymous or completely private claim is made.
- **Scope:** no AI generation, query rewriting, embeddings, browser/HTML runtime, page fetch, RAG, permanent cache, public-instance rotation or new Lapis integration. Fusion/domain reshuffling awaits measured justification.

## Physical-device and network validation still pending

No physical Apple mobile device was available in `xcrun devicectl list devices`. No second ordinary network was established. Do not substitute simulator evidence for either gate.

On an authorized host with a physical device, add the local/pinned package's library product to a minimal signed iOS test host. Use this native task (see the compilable library examples for the same API):

```swift
import LapisWebSearch

let client = LapisWebSearch(providers: [ParallelSearchProvider()])
let response = try await client.search(
    "Apple Foundation Models Swift documentation",
    options: .init(limit: 5, timeout: 12, providerTimeout: 8)
)
print(response.attempts) // Local diagnostics; avoid printing result text/private queries in an application.
```

Discover physical destinations and test using your own signed host scheme:

```sh
xcrun devicectl list devices
xcodebuild -project <TestHost.xcodeproj> -scheme <TestHost> -showdestinations
xcodebuild -project <TestHost.xcodeproj> -scheme <TestHost> \
  -destination 'platform=iOS,id=<physical-device-identifier>' test
```

There is deliberately no invented signed project, signing identity or device ID in this repository. Record model/OS/toolchain, provider configuration, network type, result validity/relevance, latency, cancellation and thermal/memory behavior. Repeat a small public-input cohort on an independently available ordinary connection, with provider permission and without bypassing IP limits. Do not change the user's active connection automatically. Physical-host/sandbox network entitlements belong to that test host.

## Next readiness stage

For a public beta candidate, resolve applicable commercial distribution/use and output terms, perform independent/mobile/multiple-network validation, accumulate repeated-day relevance/availability evidence and demonstrate an allowed live failover. Production candidate status additionally requires sustained resource/latency testing and the actual consuming application's native tool path. A stable release is not justified now.
