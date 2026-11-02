# V3 limitations and release gates

1. **Commercial clearance remains unresolved.** No current bundled general-web provider meets every required free/keyless/account-free/commercial condition. See [audit](COMMERCIAL_USE_AUDIT.md). No authorization messages were sent and no written grants obtained. A status declaration in Swift does not create rights.
2. **High-volume operation is unproven.** Per-device execution avoids a shared Lapis server, but public IPs/carrier NAT, quotas, provider policy changes, cost and correlated upstream outages remain. Bounded concurrency/coalescing reduce waste, not provider restrictions. No load test or quota exhaustion was performed.
3. **General relevance remains uneven.** FreeSerp solved two of six sampled intents and failed currentness/documentation specificity elsewhere. Wiby failed all three general-intent screens. Firecrawl/Parallel comparisons cover only three common queries in V3; a single non-blind reviewer and a partial corpus cannot establish broad quality.
4. **Search-engine claims are external claims.** FreeSerp's index size/ownership and providers' internal rankings/upstream independence were not independently audited. Homepage summaries, promotional response fields, provider scores and instructions are ignored. Publication/crawl dates are not interchangeable.
5. **Devices/networks:** native Apple M4 Mac, iPhone 17 Simulator and iPad Pro 11-inch M5 Simulator were available on one ordinary host network. `devicectl` listed only simulated devices. No physical iPhone/iPad or independently verified second network. Simulator success is not physical-device validation or the actual Lapis tool path.
6. **Fallback:** controlled local 503 followed by a real second-provider search succeeded once. No real provider outage, live 429, long-term cooldown recovery or independent-index failover was observed. Preserve that distinction.
7. **Timing:** small descriptive samples, prior repeated probes, possible provider/edge caches and fixed provider order. No statistically justified latency improvement, uncached guarantee, sustainable throughput or energy/leak claim. Memory was not rebenchmarked in V3; V2's single process measurement is historical.
8. **Default migration:** parameterless `LapisWebSearch()` intentionally sends nothing and throws `noEligibleProviders`. Explicit selection is required. The strict policy rejects conditional/unverified/restricted adapters before any requests, including fallbacks. Custom adapter assessments are trusted application code and must be reviewed.
9. **Test failure retained:** the first V3 iPhone Simulator suite failed two old coordinator deadline tests under scheduling load; one then crashed by indexing a missing second attempt. Tests used 30/80 ms budgets and assumed admission had already occurred. They now allow one second, make the first empty result immediate, and use a required count before indexing. Final runs are reported separately. No runtime timeout was widened or failure hidden.
10. **Publication and raw content:** sanitized labels/execution counts are public; raw provider content, protocol sessions and local research downloads are ignored. Public scoring can be reproduced, exact retrospective content judging cannot. No peer review or independent legal determination is implied.

## Remaining manual device validation

Use a small native test host that depends on the reviewed package and explicitly selected, permitted providers. For a simulator CLI check:

```sh
xcodebuild -scheme LapisWebSearchCLI -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/manual-simulator CODE_SIGNING_ALLOWED=NO build
xcrun simctl list devices available
xcrun simctl boot <simulator-UUID>
xcrun simctl spawn <simulator-UUID> .build/manual-simulator/Build/Products/Debug-iphonesimulator/LapisWebSearchCLI search 'What is retrieval augmented generation?' --provider freeserp --limit 5
```

These commands are simulator-only. For physical hardware, create/use a signed test host, add the library via SPM, retain a client and invoke search from its real application task. Use `xcrun devicectl list devices` and `xcodebuild -project <TestHost.xcodeproj> -scheme <TestHost> -showdestinations`, then run on the connected physical destination. Repeat a small allowed subset on Wi-Fi and cellular, recording only network type (no IP/SSID), results/relevance, queue/attempt timings, cancellations, failures and Retry-After. No CLI/simulator command constitutes physical validation.

The next readiness stage requires provider-specific commercial/output authorization, independent human relevance review, repeated-day physical/multiple-network app validation and permitted real failover evidence. No stable tag or production integration is justified. [V2 limitations](LIMITATIONS_V2.md) remain historical context.
