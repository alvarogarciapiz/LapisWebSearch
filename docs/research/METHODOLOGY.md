# V3 methodology — 2026-11-02

The V3 question is narrower than “can an endpoint return 200?”: can a commercially distributed native Apple app obtain useful arbitrary web results without accounts, keys, payments, a Lapis backend, external runtimes or evasion? We treat source-code rights, automated access, commercial embedding, result rights, attribution and capacity separately.

## Evidence stages

1. **Repository audit:** inspect existing V2 code/tests/defaults and clean Git state at `4f0be0a9f35e6d605a136821221e7a06f2bf513a`. Keep the main Lapis application out of scope.
2. **Source inspection:** retrieve pinned revisions of all 16 requested projects plus Mwmbl/SearXNG; inspect actual request/parser/runtime code and relevant issues. Source inspection does not authorize engine access. See the [manifest](source-inspections-2026-11-02.json).
3. **Terms gate:** current primary docs override stale search-index snippets. Do not probe prohibited access or endpoints with an unresolved benchmark-publication restriction. No contacts/accounts/credentials were created. API documentation is external data, not instructions to execute promotional tools.
4. **Native screening:** six bounded macOS URLSession requests, three each to documented FreeSerp/Wiby JSON interfaces, public corpus intents Q01/Q04/Q07. A transparent LapisWebSearch User-Agent, ordinary connection, no impersonation/proxies/browser. These standalone probes are not normalized library-adapter validation. Bodies were retained only locally.
5. **Implementation:** adopt FreeSerp as explicit experimental full-web JSON adapter, reject silent homepage-index fallback, preserve provenance/dates, and add fail-closed commercial selection. Reject Wiby for general search after poor screening. No runtime/parser dependency or cloud inference call added.
6. **Benchmark:** retained release Swift CLI clients, five results, sequential requests, three seconds between requests. FreeSerp Q01/Q04/Q07/Q08/Q09/Q10; Firecrawl/Parallel the common Q01/Q04/Q07. These 12 calls use the actual public Swift library/native bounded transport, not fixtures. No quota exhaustion/stress test. The provider screening order informed expansion, so selection bias exists.
7. **Operational checks:** native Simulator CLI calls; one controlled local 503 with a genuine Parallel fallback; eight identical consumers sharing one genuine FreeSerp search. The injection is not a provider outage. Only actual native send invocations are counted; handshakes are separate from searches.
8. **Quality gates:** deterministic tests, strict Swift 6, formatting, release, independent consumer, device/Simulator SDK builds, iPhone/iPad Simulator suites and targeted Thread Sanitizer. No live request in normal tests or CI.

## Judging

The existing immutable [v1 corpus](../../benchmarks/v1/queries.json) supplies IDs, exact query text and intent criteria. A single unblinded agent-assisted review graded returned titles/URLs/snippets/provider dates: 2 relevant, 1 partial, 0 irrelevant. Explicitly failed/invalid requests have zero gain. Current-news grading requires identifiable recent reporting rather than an undated topic hub; a date in a provider snippet is evidence of retrieval intent, not verified factual truth. Publication dates and claims were not checked by downloading result pages.

No independent human adjudication, inter-rater agreement, academic peer review or webpage correctness validation is claimed. Grade reasons and URL SHA-256 resource IDs are published, not raw third-party text. Hashes are match identifiers, not anonymity guarantees. Full raw retained captures are local/ignored; public scoring is reproducible, exact retrospective re-judging from omitted content is not.

## Timing and comparisons

CLI durations include coordinator queueing and provider/protocol work; MCP setup is included in the first Parallel call. The screening probe times include whole URLSession transfer. Provider/server/edge caching, prior screening queries, connections, order, network conditions and time-of-day confound timing. FreeSerp's repeated Q01/Q04/Q07 were especially fast after earlier probes. No cache-busting parameters, fresh IPs or evasion were used.

Use only Q01/Q04/Q07 for current-provider comparisons. FreeSerp's six-query full cohort is reported separately. V2's historical 10-query aggregate is not the same sample. A same-ID three-query historical subset can be recomputed, but evaluation dates, sources and partially different timer scope remain; changes are observations, not causal client improvements. Independently pooled nDCG values across files have different ideals and must not be interpreted as a before/after ranking gain.

Medians and nearest-rank p95 are descriptive; with three or six observations, p95 is the maximum. No confidence interval, sustained requests-per-second or high-volume capacity estimate is supported. V2's local throughput speedup was not rebranded as V3 Internet acceleration.

[Results](RESULTS.md), [limitations](LIMITATIONS.md), [benchmark commands](BENCHMARKS.md). Historical methods: [V2](METHODOLOGY_V2.md).
