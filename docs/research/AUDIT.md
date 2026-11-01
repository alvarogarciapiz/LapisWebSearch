# Phase 2 audit — 2026-11-01

Reference: `65f8a8aa4497b1c073a21376a16cd9c016370d86`. Working tree was clean. No application code is in scope.

| Severity | Finding | Remediation / evidence required |
|---|---|---|
| High | One slow provider can consume the entire overall deadline, leaving no fallback time. | Add an optional per-provider budget, bounded by the overall deadline; cancellation tests. |
| High | Concurrent unrelated queries to a provider fail as busy rather than being bounded and scheduled. | Introduce configurable admission limits and cancellation-aware waiting, with deadlines including queue time. |
| Medium | Identical simultaneous searches repeat work or fail busy. | Coalesce identical in-flight requests, isolate subscriber cancellation, cancel upstream when the final subscriber leaves. No persistent cache. |
| Medium | URLSession is created/invalidated per request, discarding connection reuse. | Own a reusable ephemeral session per transport; stream bounded chunks and cancel individual tasks, not the whole session. Measure before/after. |
| Medium | Byte-at-a-time accumulation and cancellation checks add avoidable per-byte overhead. | Use bounded URLSessionDataDelegate chunks; verify decoded byte limits and cancellation. |
| Medium | No opt-in latency strategy for independent providers. | Compare sequential and bounded first-success race; cancel losers and retain their diagnostics. Do not assume relevance improves. |
| Medium | Firecrawl region/date controls are not represented; 3-result evaluation hides coverage. | Add explicit country/date options only where officially supported; assess at five results without rewriting queries. |
| Medium | Original quality grades are query-level judgments without per-result relevance labels. | Version a 50-query corpus, annotate a quota-bounded subset with a documented 0/1/2 rubric; compute retrieval metrics only from explicit labels. |
| Medium | Partial provider failures and caller configuration cannot be exported as a research summary. | Add sanitized configuration diagnostics and versioned benchmark output, excluding query text by default. |
| Medium | Only one usable provider, commercial authorization unresolved. | Rank primary-source-supported candidates and evaluate an officially documented alternative without equating evaluation access with commercial rights. |
| Low | Test named shared deadline asserts timeout but not its remaining budget. | Strengthen deadline regression evidence without tight flaky wall-clock thresholds. |
| Low | Repo lacks PR template and focused research entry point. | Add concise templates, research methods/results/limitations and a revised execution brief. |

Preserve: Swift 6 Sendable boundaries, original provider protocol conformances, immutable result invariants, no redirects/cookies/credentials, synthetic offline fixtures, conservative normalization, cancellation/error taxonomy, no hidden backend, no AI dependencies, and the Bing permission gate. HTML scraping, speculative ranking, persistent caching, and stylistic rewrites are not justified by current evidence.

## Prompt review

The assignment correctly prioritizes native requests, legal/service constraints, reproducibility and honest readiness gates. Changes to its execution brief:

- Two independent providers is conditional on permitted access; adapters are not redundancy evidence.
- Fifty public benchmark queries is a corpus requirement, not a quota-spending obligation. Run a declared subset and preserve failures.
- The original 13/20 useful grade cannot be converted to Precision@5 or nDCG@5; create fresh paired measurements where possible.
- Parallel first-success optimizes latency, not relevance. Fusion waits for more results and consumes more quota; defer it until relevance evidence justifies it.
- Define per-provider admission limits, queue deadlines, identical-request sharing and subscriber cancellation before increasing fan-out.
- Distinguish warm connection reuse from cache hits, provider latency from client latency, and request count from completed search count.
- Physical-device and multiple-network tests depend on availability. Publish exact pending commands rather than claiming they happened.
- A default provider is not commercially authorized by a Swift initializer. Preserve source compatibility while explicitly documenting evaluation-only configuration.

## Disposition

The selected remediations are implemented: retained sessions/chunks, configurable provider budgets, bounded admission/sharing/racing, explicit filters, structured Parallel search, sanitized observations and research/PR tooling. Provider budgets and racing remain opt-in to preserve conservative behavior; callers that need reserved fallback time must set providerTimeout. Fusion, permanent caching and speculative HTML ports were deferred. Commercial/mobile/multiple-network/real-outage gates remain open and are not counted as closed software defects. See RESULTS.md for native evidence and LIMITATIONS.md for pending work.
