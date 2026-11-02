# Changelog

## V3 development iteration — unreleased research preview

- **Behavior change:** the parameterless client and CLI no longer choose Firecrawl implicitly. Select providers explicitly; empty selection returns noEligibleProviders with no request.
- Fix literal plus query encoding in FreeSerp/Bing for form-decoding servers, with server-style decoding regressions (C++/Unicode).
- Add original experimental FreeSerp Global native JSON adapter, language-only locale, publication-date validation and rejection of silent homepage-index fallback.
- Add provider usage assessments and a strict commercial policy rejecting unsafe registries before any request, including fallbacks. No bundled provider is commercially cleared for the required deployment.
- Add 20 test functions (98 total), public consumer policy checks, fault-injection/live-fallback and native coalescing CLI checks. Fix old deadline tests exposed by Simulator scheduling load, including a test-only out-of-bounds crash.
- Add 18 pinned source inspections, 20+ service/engine rights audit, public sanitized V3 measurements and LAPIS Research article draft. Preserve V2 records separately.
- No runtime dependencies, Lapis app edits, stable tag or release. Source-code MIT does not license provider access/content.

## Initial development — experimental

- Independent Swift 6 package for iOS/iPadOS 16+ and macOS 13+ with no external dependencies.
- Experimental official Firecrawl v2 keyless search; no scraping or Authorization header.
- Native RSS adapter disabled unless separate Microsoft permission is declared.
- Extensible provider contract, sequential fallback, normalized results and local diagnostics.
- Bounded ephemeral HTTPS transport, no redirects/cookies/cache, cancellation and cooldowns.
- Offline fixtures and URLSession tests, independent consumer, native CLI and opt-in live matrix.
- Provider rights/privacy evaluation, measured quality/latency evidence and Apple SDK CI.

No version has been tagged and no GitHub Release has been published. Commercial authorization, physical-device/multiple-network testing and broader quality validation remain release blockers.

## Phase 2 — unreleased research preview

- Retain ephemeral URLSession connection pools and read bounded body chunks; preserve per-request cancellation/timeout isolation and available HTTP error status.
- Add FIFO active/provider admission, bounded pending subscribers, queue-inclusive deadlines and optional provider budgets.
- Coalesce identical in-flight searches with independent subscriber cancellation; no completed-result cache.
- Add opt-in bounded first-success racing and local configuration/queue/coalescing diagnostics.
- Add documented Parallel keyless MCP web search for evaluation/light use, explicit Firecrawl country/time controls and deduplication before truncation.
- Preserve common public API calls, protocol conformances, experimental Firecrawl default and Bing permission gate. Busy-provider errors become bounded waiting; providerBusy now indicates full pending capacity.
- Add versioned fifty-query corpus, reviewed per-result labels/scorers, native paired harness, public research materials and PR/CI improvements.
- Retain unresolved commercial authorization, physical/multiple-network, freshness and real-outage failover gates. No stable release or unrestricted service rights.
