# V3 results — 2026-11-02

**Verdict: research preview. The mandatory free, keyless, account-free, commercially cleared general search configuration was not established.** V3 adds one honest experimental adapter and prevents implicit or commercially unverified provider selection. No stable release/tag or Lapis application integration was performed.

## Delivered

- Inspected actual code in all 16 requested repositories plus Mwmbl and SearXNG, with pinned [source evidence](GITHUB_SOURCE_AUDIT.md). Investigated 20+ underlying engines/services and separated code, endpoint, commercial, content, attribution and capacity rights in the [commercial audit](COMMERCIAL_USE_AUDIT.md).
- Added original native **FreeSerp Global** adapter: fixed documented HTTPS JSON endpoint, exact query encoding, explicit language-only option, real provider date parsing, bounded transport, cancellation, error/challenge classification, provenance, deduplication and rejection of silent fallback to homepage profiles. No generated-summary, page extraction, cloud inference, browser or runtime dependency added.
- Added `ProviderUsage`, `CommercialUseStatus` and `SearchProviderPolicy.requireCommercialClearance`. Strict selection rejects the whole unsafe registry before networking, including experimental fallbacks. Custom assessments need reviewed HTTPS evidence; this is author-supplied policy metadata, not legal verification.
- Removed implicit Firecrawl selection. `LapisWebSearch()` still compiles but throws `noEligibleProviders` with no query sent. Explicitly configured V2 adapters and custom conformances remain available. This is a documented behavioral migration, not a stable version.
- Final encoding review found URLComponents preserves literal plus signs, which form-query servers can decode as spaces. FreeSerp/Bing now encode literal plus as %2B; tests model server form decoding rather than only URLComponents round trips. Recorded live queries contain no plus signs, so no benchmark replay or changed result claim was needed.
- Extended CLI benchmark choices and added explicitly opt-in sanitized native validation commands. Retained V2's bounded concurrency/coalescing/connection reuse and conservative sequential default. No unsupported fusion/routing or quota multiplication added.
- **98 tests, zero final failures**, up from 78, including policy and provider fixtures/error regressions. Independent public-API consumer, release/strict builds, format checks and Apple SDK checks pass. Final iPhone/iPad Simulator suites each passed 98 tests. An initial iPhone test failure/crash was corrected and is retained below.

## Current-provider comparison: same three IDs

Queries Q01/Q04/Q07, original v1 corpus, five results, one agent-assisted non-blind review. These are retrieval-intent measurements, not factual correctness.

| Provider | Valid nonempty | Success@5 | Precision@5 | Pooled nDCG@5 | Median / nearest-rank sample p95 |
|---|---:|---:|---:|---:|---:|
| Firecrawl | 3/3 | 1.00 | 0.60 | 0.744 | 0.693 / 1.511 s |
| Parallel | 3/3 | 1.00 | 0.733 | 0.844 | 1.031 / 1.853 s |
| FreeSerp Global | 3/3 | 0.333 | 0.333 | 0.519 | 0.072 / 0.307 s |

FreeSerp's first three benchmark queries repeat its earlier screening probes; connection/provider/edge caching and order strongly confound those short timings. They are not uncached latency guarantees or evidence of a V3 networking speedup. Parallel's first call includes MCP setup. Three-sample p95 is just the maximum. Parallel returned two path-case variants of an Apple reference and two forms of a RAG survey: exact URL deduplication does not eliminate semantic duplicates, which can inflate per-position relevance metrics.

### Expanded FreeSerp screen

Six IDs Q01/Q04/Q07/Q08/Q09/Q10: **6/6 normalized valid sets, 2/6 Success@5 (33.3%), Precision@5 0.20, pooled nDCG@5 0.494; median 0.535 s, sample p95/max 4.657 s.** RAG and an offline-mobile guide met intent. Current Spanish AI reporting, official Foundation Models documentation, specific Swift cancellation reference and November on-device research did not. Fast/valid responses are not broad quality success. This did not justify making FreeSerp the default or expanding to all 50 queries.

### Rejected screen

Wiby: three genuine standalone native JSON probes, 3/3 parseable nonempty sets but **0/3 useful general-query sets** for Q01/Q04/Q07. Spanish text survived; result intent did not. Its classic-web purpose may be useful in a specialized product, but no adapter was added just for provider count. These are screening results, not library-adapter performance statistics.

## V2 versus V3

| Item | V2 | V3 | Interpretation |
|---|---|---|---|
| Deterministic test functions | 78 | 98 | New provider/policy coverage and safer deadline-test assertions |
| Implicit external default | Experimental Firecrawl | None; explicit selection required | Behavioral migration prevents accidental unverified service use |
| General experimental native adapters | Firecrawl, Parallel | Firecrawl, Parallel, FreeSerp Global | More discovery options; no new cleared commercial provider |
| Commercially cleared bundled set | None | None; explicit policy enforces rejection | Central blocker remains unresolved, now observable before any query |
| Eight identical native consumers | 8 successes / 1 send | 8 successes / 1 send | V2 sharing retained; seven coalesced subscribers in V3 check |
| Fallback evidence | Offline faults, no live failover | Local injected 503 + one genuine Parallel fallback | Improved reproducibility; still not real outage recovery |

Historical Q01/Q04/Q07 can be recomputed from the V2 labels: Firecrawl Success@5 2/3, Precision@5 0.533, median 0.534 s; Parallel Success@5 3/3, Precision@5 0.933, median 1.004 s. V3 observed 3/3/0.60/0.693 s and 3/3/0.733/1.031 s respectively. **Both median timings worsened, and Parallel's per-position precision declined in this small repeat.** Sources/date/order changed; some V2 Firecrawl timing used an outer-call harness. No causal improvement/regression in the client or statistical significance is established. Pooled nDCG ideals differ, so no cross-file nDCG delta is claimed. V2's overall 50%/80% Success@5 used ten queries and cannot be compared directly to this three-query sample.

## Genuine networking and operational results

**22 completed native query-bearing responses in V3:** 12 FreeSerp, 3 Wiby, 3 Firecrawl, 4 Parallel. Breakdown: six standalone screening probes, twelve compiled-library benchmark searches, two Simulator library searches, one live second-provider search after local fault injection, and one native request shared by eight consumers. Additional MCP setup/notifications and documentation fetches are not searches. The injected 503 is not a real HTTP response and is excluded from these counts.

- Controlled fallback: local FreeSerp transport throws 503; real Parallel returns five results in **1.353 s** attempt duration, with three native protocol/search exchanges. This proves integration of a fault with a genuine fallback response once, not an observed provider outage.
- Concurrent check: eight same-query consumers received five results each, **one native request**, seven coalesced; attempt duration **0.236 s**. No sustained different-query/high-volume claim.
- iPhone 17 Simulator / iOS 27: genuine native FreeSerp Q09, five normalized results, **0.391 s** whole-call duration. Its relevance limitations remain the same; five results do not mean a useful answer.
- iPad Pro 11-inch M5 Simulator / iOS 27: genuine native FreeSerp Q07, five results, **0.284 s**. Neither simulator is a physical device.
- Physical host: Apple M4 Mac mini, 16 GiB, macOS 27.0.1, local Swift 6.4/Xcode 27.1; one ordinary connection. `devicectl` listed only simulated devices. Second network and physical iPhone/iPad tests unavailable.
- No live 429, exhausted quota, CAPTCHA bypass, real outage, geolocation comparison, energy/leak test or sustained throughput test. Memory was not remeasured in V3.

## Validation failure preserved

The first iPhone Simulator suite failed `deadlineCancelsProviderAndPreventsFallback` and `fallbackSharesOverallDeadline` under scheduling load: tiny 30/80 ms deadlines expired before assumed provider admission. The second test then indexed a nonexistent attempt and crashed; the automatic runner restart reported zero tests, which was **not** accepted as a pass. One-second budgets, an immediate first no-result response and `#require` before indexing corrected the tests. Final macOS/iPhone/iPad suites each passed all 98. No production timeout was widened to conceal the issue. SDK bookkeeping warnings about an OS-build string remain Xcode diagnostics, not failed assertions.

See [raw sanitized observations](../../benchmarks/v3/observations-2026-11-02.json), [execution](../../benchmarks/v3/execution-2026-11-02.json), [screening/operations](../../benchmarks/v3/screening-and-operations-2026-11-02.json), [methodology](METHODOLOGY.md) and [limitations/manual validation](LIMITATIONS.md). Full V2 findings remain in [RESULTS_V2.md](RESULTS_V2.md). Final public CI status is verified at the published commit and linked in the handoff, not inferred from local tests.
