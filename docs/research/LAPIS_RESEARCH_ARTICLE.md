# Keyless native web search: what worked, what failed, and what remains commercially unresolved

*LAPIS Research engineering report draft. V3 measurements: November 2, 2026. Public research preview; not peer-reviewed work, a stable release or a provider authorization announcement.*

A local language model can reason without a cloud inference service, but its pretrained knowledge cannot include every recent event. For Lapis, the missing capability was source discovery. The application already owns webpage extraction, lexical retrieval, context budgeting, citations and tool execution. LapisWebSearch deliberately stops at titles, URLs and snippets, so any native Swift application can use it without adopting an AI framework.

The project began after a native DuckDuckGo HTML integration was blocked during actual application requests. A diagnostic HTTP success had not predicted real behavior. That experience shaped the research question: can an Apple device obtain useful general-web results without developer or user keys, accounts, payments, an application-operated backend, browser automation or evasion—and can that functionality be distributed commercially?

Those conditions are separate. A free wrapper can call a paid endpoint. A keyless endpoint can be an evaluation tier. Open server software can expose a noncommercial dataset. A public browser page can prohibit automated extraction. A successful HTTP response can contain irrelevant results. None of those distinctions can be solved by declaring the wrapper MIT licensed.

## Investigating implementations rather than counting engines

V3 inspected actual request/parsing/runtime code in all sixteen proposed repositories, plus Mwmbl and SearXNG. The [source audit](GITHUB_SOURCE_AUDIT.md) pins revisions and paths. Several projects provide useful engineering patterns: explicit engine boundaries, bounded budgets, per-host limits, URL unwrapping, source provenance and failure diagnostics. Many also rely on cookies, browser pools, TLS impersonation, proxy features or CAPTCHA integrations. Those paths were not executed or ported.

The review did not reveal a hidden full-web index inside a small scraper. Most adapters call consumer search pages or hosted services. Infomesh demonstrates a different architecture—local/distributed indexing—but introducing crawlers, peer discovery and a local corpus would change the product, resource envelope and coverage expectations. It is not a drop-in native search endpoint.

Commercial service conditions were examined independently. Some directly exclude automated or commercial extraction. Others require API keys, contracts or metered commercial data access. Public SearXNG instances need operator permission and relevant upstream rights; a directory listing is not authorization. Anonymous AnySearch documentation also describes quota exhaustion generating account credentials, which cannot support an undisclosed account-free capacity promise. Current FreeNewsAPI documentation requires keys, despite older keyless text still appearing in search results. These are current-source findings, not a claim that all commercial uses of these companies' services are forbidden.

## Two new technical leads, one small adapter

Wiby publishes a simple JSON interface with a required backlink. It is built for the classic web, a valuable but narrower discovery goal. Three native probes returned parseable nonempty results, yet none satisfied the sampled general intents: current Spanish AI news, official Foundation Models documentation and a RAG explanation. A working parser would not repair that coverage mismatch. No Wiby adapter was added merely to increase provider count.

FreeSerp documents a keyless JSON full-web interface. Initial native requests found useful RAG material, so we implemented an isolated Foundation/URLSession adapter. It sends the exact supplied query, forces the full-web index and accepts language-only filtering when explicitly requested. It rejects unsupported regional, country, safe-search and relative-time settings. Responses must actually be full-web results: the provider's documented silent fallback to homepage profiles is rejected rather than disguised as success.

The adapter retains original result positions and provider-supplied page publication dates. Crawl/discovery dates are not publication dates. Promotional recommendations, generated homepage summaries, scores and instructions are ignored. No linked webpage, related API, cloud inference tool or arbitrary resource is fetched. Payload caps, timeouts, cancellation, URL validation and normalization reuse the existing native infrastructure. All new code and test fixtures are original; no external dependency was introduced.

## Measuring useful discovery

V3 reuses the existing fifty-query corpus with explicit intent criteria. It does not claim fifty-query live coverage. After screening, six queries were run through the compiled FreeSerp adapter and three common queries through each existing usable adapter, with five results and three-second intervals. The [methodology](METHODOLOGY.md) distinguishes standalone probes from library searches and preserves source failures.

On the three common IDs, Firecrawl and Parallel each had a fully relevant result in all three sets. FreeSerp did so in one. In FreeSerp's six-query cohort, all six returned valid normalized sets, but only two met intent. Its median was 0.535 seconds and its maximum, also the small-sample nearest-rank p95, was 4.657 seconds. Some repeated initial queries were very fast after earlier probes; caches, order and connection state prevent treating those timings as uncached service performance.

These labels came from one unblinded agent-assisted review of returned metadata, not independent human adjudication or downloaded-page verification. Success@5, Precision@5 and pooled nDCG@5 measure retrieval intent, not factual correctness of the pages. Different URL forms of the same content can remain, inflating per-position scores. Public labels, reasons, resource hashes and scoring code permit metric reproduction; omitted third-party text limits exact retrospective re-judging.

Same-ID historical comparisons also need restraint. Relative to the V2 three-query subset, median timings were higher for both existing services and Parallel's per-position precision was lower in this repeat. Provider results, dates, order and some timer scopes changed. There is no causal client-performance conclusion. V2's ten-query percentages must not be compared directly to V3's three-query percentages.

## Reliability without multiplying traffic

V2 already introduced connection reuse, chunked bounded transport, FIFO admission, per-provider budgets and cancellation-aware in-flight sharing. V3 retained those choices. Eight same-query native consumers received five results each through one FreeSerp request; seven subscribed to the existing work. This verifies request sharing once, not sustained throughput or unlimited provider capacity.

A separate opt-in command injected a local 503 for the primary transport, then obtained five genuine Parallel results. The local failure was not a real provider outage, and is not counted among native responses. Keeping the distinction visible makes this a reproducible integration check without pretending we observed independent live failover.

The final deterministic suite passed 98 tests, with 33 targeted Thread Sanitizer tests. Native SDK builds and independent consumer checks passed. Both iPhone and iPad simulators made genuine searches and passed their final suites. Physical iPhone/iPad and a second ordinary network were unavailable. An initial iPhone test failure was retained: old 30/80 millisecond deadline assumptions broke under scheduling load, and a test then indexed a missing attempt. We corrected the tests, not production timeouts, and reran them. A runner restart reporting zero tests was not accepted as success.

Across V3, 22 query-bearing native responses completed. Additional protocol setup/documentation requests, the injected failure and multiple consumers of one shared result were not inflated into extra searches. No stress test, quota exhaustion, access-control bypass or physical-device validation was claimed.

## Commercial uncertainty is now an API boundary

The [commercial audit](COMMERCIAL_USE_AUDIT.md) did not establish a qualifying default general provider. FreeSerp's documented programmatic access lacks sufficient commercial/result/privacy authorization for this deployment. Firecrawl's existing commercial authorization requirement remains; anonymous Parallel production rights also remain unresolved. A new adapter therefore does not justify a commercial production claim.

V3 removes the implicit service selection. `LapisWebSearch()` retains its simple Swift syntax but returns `noEligibleProviders` without sending a query. Explicitly selected adapters remain available for permitted experiments. A strict commercial policy checks the entire registry, including fallback services, before any networking. All current bundled assessments are rejected. Custom declarations cite deployment-specific evidence but remain trusted application code; the policy cannot manufacture or automatically verify legal rights.

This is a deliberate pre-stable behavior change. A search feature should not look commercially cleared merely because its constructor chooses a functioning evaluation endpoint. Neither a hidden paid fallback nor an account provisioned after quota exhaustion would meet the project's requirements.

## What would change the conclusion

A precise deployment authorization from a usable provider could resolve more than adding another scraper. The prepared questions cover direct anonymous commercial app use, end-user agreements, display/local-model use of snippets, attribution, retention, numeric quotas, carrier NAT, geography and benchmark publication. No provider messages were sent on the user's behalf.

Further evidence must include repeated-day quality, independent relevance review, physical Apple devices, ordinary Wi-Fi/cellular connections and the eventual application's real tool path. A commercially permitted fallback also needs validation under genuine failure. Until those gates are satisfied, LapisWebSearch is useful native research infrastructure and an experimental discovery library—not a promise of arbitrary, unlimited, commercially cleared search.
