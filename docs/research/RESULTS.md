# Phase 2 results — 2026-11-01

**Verdict: research preview.** Native discovery, concurrency and reproducibility improved; unrestricted commercial keyless production remains unproven. No stable release is justified. [Methodology](METHODOLOGY.md) and [limitations](LIMITATIONS.md) are part of these results.

## Implemented changes

- Reusable ephemeral URLSession transport, bounded delegate chunks, per-request overall timeout and cancellation isolation. No redirects, cookies, credentials, persistent cache or result-page fetching.
- FIFO bounded admission at client/provider levels, queue-inclusive overall deadlines, optional per-provider budgets, queued-request rate-limit rechecks and bounded pending subscribers.
- Sharing of identical in-flight requests, with independent subscriber cancellation and upstream cancellation after the last subscriber leaves. Completed results are not cached.
- Opt-in bounded first-success racing, cancellation/diagnostics for losing attempts, and unchanged sequential defaults.
- Documented Parallel keyless MCP adapter, explicit Firecrawl country/month/week/day/year options, single-pass deduplication before truncation and query-free configuration/queue diagnostics.
- Fifty-query versioned corpus, native retained-client benchmark CLI, source-compatible paired consumer harness, per-rank labels, offline scoring, PR template and CI checks.

## Before / after

| Measurement | Reference implementation | Phase 2 | Interpretation |
|---|---:|---:|---|
| Usable general providers for limited keyless evaluation | Firecrawl | Firecrawl + opt-in Parallel | Different service operators; independent upstream indexes and production rights not established |
| Default deterministic test functions | 49 | 78 | Includes native URLSession, protocol, queue/deadline/cancellation and sharing regressions |
| Matched Q07–Q10 native searches | 4/4 valid nonempty | 4/4 valid nonempty | Four pairs only, same network and five-result limit |
| Matched median client latency | 0.518 s | 0.490 s | Faster in two pairs, slower in two; insufficient causal/statistical evidence of general Internet speedup |
| Matched Success@5 / Precision@5 | 0.75 / 0.70 | 0.75 / 0.70 | Ranked URLs identical on the four pairs; no client-ranking improvement claimed |
| Matched pooled nDCG@5 | 0.800 | 0.800 | Uses the frozen observed pool, not an exhaustive web ideal |
| Eight identical simultaneous consumers | 1 success, 7 busy failures, 1 HTTP send | 8 successes, 0 failures, 1 HTTP send | Measured native sharing improvement; seven consumers coalesced |
| Synthetic 1 MiB body-processing median, three samples | 17.457 ms | 0.357 ms | About 49× lower local transport processing time in this fixture; **not a live-search speedup** |

Raw sanitized timings/counts are in [performance observations](../../benchmarks/v1/performance-2026-11-01.json). The local throughput fixture validates bytes through URLProtocol; it is not live provider evidence. The native burst's success duration changed from 0.420 s to about 0.125 s, but connection/cache/order confounding prevents attributing that timing change solely to coalescing. Its request count and subscriber outcomes are the meaningful result.

## Retrieval quality, Q01–Q10

| Current provider | Valid nonempty sets | Success@5 | Precision@5 | Pooled nDCG@5 | Median / sample p95 |
|---|---:|---:|---:|---:|---:|
| Firecrawl | 10/10 | 0.50 | 0.38 | 0.702 | 0.525 / 0.740 s |
| Parallel | 10/10 | 0.80 | 0.50 | 0.828 | 0.813 / 1.560 s |

These are descriptive scores from one unblinded agent-assisted review of ten public queries per provider, five returned results each, including provider-supplied snippets/dates. The ten-observation nearest-rank p95 is the sample maximum. Firecrawl’s cohort combines six CLI job durations with four outer-call harness durations; the matched before/after table uses outer-call measurements for both revisions. No independent human adjudication, factual webpage validation or population reliability claim is implied. Full per-rank grades/reasons/resource hashes are in [observations](../../benchmarks/v1/observations-2026-11-01.json); [scoring definitions](BENCHMARKS.md) explain the limitations.

Parallel helped the recent small-model and on-device-research intents, while its MLX release query confused the Python project with the requested Swift project. Firecrawl was strong on basic RAG, local iPhone models and Swift cancellation, but remained weak on the recent-research queries. Both had localization/currentness weaknesses. A better score on this subset is not a universally better search engine.

Three explicit Firecrawl filter experiments all returned valid five-result lists, but produced **0/3 Success@5 and Precision@5 of 0** for the strict research/release intent. More dated material did not reliably mean the right research or latest release. Country/time controls are useful caller capabilities, not a quality cure or automatic query-rewriting policy.

The original 13/20 useful, 4/20 partial and 3/20 failed grades remain in [historical validation](../VALIDATION.md). Different cohorts, limits and rubrics make comparison to this table invalid. Those old grades were not reverse-engineered into missing relevance labels.

## Latency versus relevance

Two Parallel-first cases compared identical provider order under sequential and first-success strategies:

| Query ID | Sequential / winner | First success / winner | Search send attempts | Observation |
|---|---|---|---:|---|
| Q03 | 1.253 s / Parallel | 0.387 s / Firecrawl | 1 → 2 | Faster winner returned the weaker small-model-research results |
| Q04 | 1.237 s / Parallel | 0.167 s / Firecrawl | 1 → 2 | Faster documentation discovery; both services were relevant |

The first sequential call used three HTTP exchanges including MCP setup; its next call used one. The corresponding races used four then two HTTP exchanges. Both cancelled Parallel attempts entered the search transport. Counters measure send invocations, not confirmed server receipt, work or billing; cancellation is not a quota-refund guarantee. Order was sequential-then-race, not counterbalanced, so these two cases demonstrate a tradeoff rather than establish a general speedup. They do **not** justify racing by default or claiming relevance improves. No RRF or result fusion was implemented.

## Native validation and resources

- macOS: final 78-test suite passed, strict-concurrency/warnings-as-errors build, release and independent consumers passed.
- Thread Sanitizer: 25 concurrency/admission/native-transport test functions passed with no reported races. This is targeted synthetic coverage, not proof of all possible interleavings.
- iPhone 17 Simulator, iOS 27.0: genuine native Firecrawl search, five results, 0.406 s; 76-test suite passed before the last added rate-limit regression.
- iPad Pro 11-inch (M5) Simulator, iOS 27.0: genuine native Parallel search, five results, 1.113 s; final 78-test suite passed. The live timing is retained in the sanitized execution evidence.
- Unsigned iOS/iPadOS device SDK and Simulator CLI/library builds passed. These are SDK/simulator checks, not physical-device tests.
- `devicectl` listed only simulated devices. Physical iPhone/iPad and a second ordinary network were unavailable; commands for later validation are in LIMITATIONS.md.
- A single optimized five-result Mac search measured 16,400,384 bytes maximum RSS (15.64 MiB), 5,030,632 bytes peak footprint (4.80 MiB), and 0.99 s process time. Phase 1 used three results and different runtime state; no memory improvement or sustained leak/energy claim is made.

**41 native query-bearing transport attempts were made in Phase 2:** 23 Firecrawl (including reference-version runs), 17 Parallel and one Exa research probe. Of these, 39 completed with genuine network responses; two Parallel race attempts were cancelled, with wire delivery/server acceptance unconfirmed. Exa's probe yielded text rather than an adopted normalized adapter. Main current-provider relevance cohorts had 20/20 valid nonempty result sets; do not use all 41 as an invented 100% success denominator. MCP initialization/notification/tool-list research probes are additional protocol requests, not searches. No new Bing or You.com searches were made.

No live 429, real provider outage or actual outage-triggered fallback was observed. Cooldowns, outages and deadline-triggered fallback are deterministic test evidence; live failover success rate remains unmeasured. Both new and previous failures are retained. CI status for the final published revision is linked in the handoff; local checks alone are not a CI claim.

## Publication check correction

The first Phase-2 [CI run 41298303112](https://github.com/alvarogarciapiz/LapisWebSearch/actions/runs/41298303112) failed in the CLI release build under Xcode 16.4/Swift 6.1: a multi-file executable used `@main` inside the specially treated `main.swift`. The local Swift 6.4 build accepted it. Renaming that source to `SearchCLI.swift` fixes the entry-point configuration without changing library/query behavior. The library compiled in the failed run; subsequent skipped steps were not counted as passed. This tooling failure is retained as part of the validation record.
