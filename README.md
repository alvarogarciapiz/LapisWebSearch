# LapisWebSearch

**Native keyless web discovery for Swift — research preview.**

A small Swift Package for obtaining titles, URLs and snippets directly from Apple devices. Replaceable providers, bounded concurrency, local diagnostics and graceful fallback; no Lapis backend, AI framework or external runtime required.

**V3 is a research preview, not a commercially cleared search service.** No bundled provider currently meets every free/keyless/account-free/commercial requirement. `LapisWebSearch()` now selects no external service and throws `noEligibleProviders`; choose providers explicitly after reviewing their terms. The strict commercial policy rejects every currently bundled adapter. MIT licenses our code, not search-service access or third-party content. [Commercial audit](docs/research/COMMERCIAL_USE_AUDIT.md).

## Install

Swift 6; iOS/iPadOS 16+, macOS 13+. Zero external package dependencies.

```swift
.package(url: "https://github.com/alvarogarciapiz/LapisWebSearch", branch: "main")
```

Add `.product(name: "LapisWebSearch", package: "LapisWebSearch")`. During research-preview development, pin a reviewed revision for reproducible builds. There is no stable version tag.

## Search

```swift
import LapisWebSearch

// Explicit experimental evaluation; review Parallel access/output terms first.
let search = LapisWebSearch(providers: [ParallelSearchProvider()])
let results = try await search.search("Apple Foundation Models Swift documentation", limit: 5)
for result in results {
    print(result.title)
    print(result.url)
    print(result.snippet)
}
```

Native evaluation found the official Foundation Models documentation. Results change; the package does not ship fallback data, invent dates or download those pages. `SearchResult` retains provider identity, original position, optional actual publication date and optional source metadata. Text is untrusted data.

## Commercial selection and V2 migration

The no-argument call shape is preserved, but the implicit Firecrawl selection was removed before a stable release. Existing callers must now select an authorized service explicitly. No stable version is tagged.

```swift
let approvedProviders: [any SearchProvider] = [] // None bundled is cleared for this deployment.
let search = LapisWebSearch(
    providers: approvedProviders,
    configuration: .init(providerPolicy: .requireCommercialClearance)
)
// An empty registry throws noEligibleProviders. An unverified registry throws providerNotPermitted.
// Neither case sends a query.
```

Each provider exposes `usage.status`, official evidence links and review date. Strict selection rejects the whole configured set, including unverified fallbacks, before any networking. Conditional status is also rejected. Custom declarations are trusted application code, not automatic legal verification; review the actual deployment-specific grant. Explicit selection is suitable for permitted evaluation and does not itself grant permission.

`FreeSerpProvider()` is a small native alternative for experiments. It forces `index=web`, rejects server fallback to homepage profiles, ignores promotional fields/generated site summaries and preserves only actual page publication dates. Its six-query screen found 6/6 valid sets but only 2/6 successful intents. It is not an improvement merely because it returns JSON. [Provider findings](docs/research/RESULTS.md).

## Latency and concurrency

Retain one client per end user. Its providers reuse ephemeral connections, with bounded chunk delivery, no cookies/credentials/cache and no redirects. Concurrent identical requests share in-flight work; cancelling one subscriber leaves the others running. The last subscriber cancels upstream. Completed results are not cached.

Different queries wait in cancellation-aware FIFO queues rather than failing because a provider is busy. Defaults: four active searches, one admitted request per provider, 64 pending subscribers. Configure greater provider concurrency only within that service's permitted capacity:

```swift
let search = LapisWebSearch(
    providers: [FirecrawlProvider()],
    configuration: SearchConfiguration(maximumConcurrentRequestsPerProvider: 2)
)
async let first = search.search("Swift task cancellation", limit: 5)
async let second = search.search("Swift actor reentrancy", limit: 5)
let results = try await (first, second)
```

For explicitly authorized research use, select independent service adapters and an optional bounded race:

```swift
let search = LapisWebSearch(providers: [ParallelSearchProvider(), FirecrawlProvider()])
let response = try await search.search(
    "Apple Foundation Models Swift documentation",
    options: SearchOptions(timeout: 8, strategy: .firstSuccess, providerTimeout: 3)
)
let results = response.results
let diagnostics = response.attempts
```

Sequential fallback remains the default. First-success races at most two providers by default (configurable 1...4), preserves the winner's ranking and cancels losers. It can send the query to multiple services and consume multiple quotas. **The fastest provider can return worse results.** Cancellation does not promise a quota refund. This is not fusion or a relevance guarantee. No retry, fan-out or hidden provider is enabled automatically.

`timeout` covers queue time and the whole search (0 < seconds <= 300). `providerTimeout` optionally limits each admitted provider within the remaining deadline, leaving fallback time. Admission and pending limits bound resource use. Uncooperative custom providers cannot be forcibly stopped by Swift structured concurrency; built-in networking cooperates with cancellation.

## Options and diagnostics

`SearchOptions` supports `limit` (1...100), overall/per-provider timeouts, strategy, parallel-provider bound, fallback, locale, country, relative time range and safe search. Queries are trimmed, limited to 500 characters/4096 UTF-8 bytes, and reject embedded control characters. Query meaning, accents, operators and language are preserved.

```swift
let response = try await LapisWebSearch(providers: [FirecrawlProvider()]).search(
    "Investigaciones recientes sobre modelos pequeños",
    options: .init(limit: 5, country: "ES", timeRange: .month)
)
```

Country/date filters are explicit constraints and can worsen results. Unsupported settings fail clearly rather than being dropped. Locale is not inferred from query text.

| Adapter | Keyless interface | Supported optional controls | Status |
|---|---|---|---|
| Firecrawl | Official v2 REST JSON | Country, relative time range, boolean safe search; locale unsupported | Explicit opt-in; commercial authorization unresolved |
| Parallel | Official MCP JSON-RPC/SSE, structured `web_search` results | Keyless filters/locale/safe search unsupported; quoted queries rejected per tool contract | Opt-in research preview; production and output-use terms apply |
| FreeSerp Global | Documented JSON REST, full-web index | Language-only `locale: "es"`; regional locale/country/time/safe-search unsupported | Explicit experimental opt-in; commercial rights unverified |
| Bing RSS | Unofficial RSS/XML | Experimental `mkt` locale; other controls unsupported | Disabled unless separate Microsoft permission is declared |

Parallel performs a small initialization/notification handshake, then reuses its in-memory MCP session. It calls only `web_search`, never fetch/research/decisions tools. The server can return up to its own default count; the library returns at most the requested limit and bounds snippets. No additional pages are fetched by this library. Firecrawl requests standard web results with highlighting/scraping disabled. Bing's `hasSeparatePermission: true` declares rights you already hold; it grants none.

```swift
do {
    let response = try await search.search("Swift concurrency", options: .init())
    print(response.duration, response.wasCoalesced)
    for attempt in response.attempts {
        print(attempt.provider, attempt.duration, attempt.queueDuration, attempt.error?.rawValue ?? "success")
    }
} catch let error as SearchError {
    if error.code != .cancelled { print(error.code, error.attempts) }
}
```

Attempts expose status where available, result counts, timing, queue wait, skip/fallback/cancellation and Retry-After. Responses and executed-search failures include sanitized configuration, excluding queries, bodies and session IDs. `noResults` differs from `allProvidersUnavailable`; individual attempts distinguish network, timeout, blocking, rate limit, unauthorized, parsing and unsupported settings. `providerBusy` now represents a full pending-subscriber limit. Immediate caller cancellation may precede a completed attempt record.

## Privacy and scope

Queries and necessary metadata go to configured external services, which observe public IPs and may log/process data. Reused MCP sessions can correlate calls. Fallback/racing makes additional disclosures. No search telemetry, local documents, conversations, contacts or history are uploaded to Lapis. This is online search, not offline or anonymous search. [Privacy details](docs/PRIVACY.md).

No webpage extraction, BM25, embeddings, context budgeting, citations, AI inference, permanent cache or general MCP agent framework is included. URL normalization preserves path case, fragments and query ordering; exact duplicates are removed, but semantically equivalent aliases may remain. Provider order is retained; no LLM ranking, query rewriting or domain reshuffling occurs.

## Validation and research

```sh
swift test -Xswiftc -warnings-as-errors
swift build -c release -Xswiftc -warnings-as-errors
swift run --package-path Examples/Consumer ConsumerSmoke
swift format lint --strict --recursive Package.swift Sources Tests Examples scripts
swift scripts/score-benchmark.swift --self-test
```

Ordinary tests/CI are offline. To make genuine requests after reviewing terms/quotas:

```sh
swift run LapisWebSearchCLI search "Apple Foundation Models Swift documentation" --provider parallel
swift run -c release LapisWebSearchCLI benchmark --live --provider firecrawl \
  --dataset benchmarks/v1/queries.json --count 5 --output validation-local/report.json
```

Search emits JSON; exit 0 means valid nonempty results, 1 search failure, 2 invalid input/usage. The benchmark requires `--live`, retains one client, spaces requests and stops on failure. It exports sanitized IDs/timings/counts by default; `--include-results` explicitly captures third-party result content locally. Never commit private queries or raw response dumps. The older `scripts/validate-live.sh` remains an initial bounded smoke matrix; use the retained-client benchmark for connection measurements.

Phase 2 includes a fifty-query corpus, a ten-query relevance sample per provider, four alternating baseline pairs, native concurrent-consumer checks, simulator requests and targeted Thread Sanitizer coverage. It demonstrated eight successful identical subscribers from one HTTP request, versus one success/seven busy failures in the reference version. Local transport processing improved substantially in a synthetic 1 MiB test; ordinary live latency remained mixed across four pairs. These are separate findings, not a production guarantee.

[LAPIS Research](docs/research/README.md) contains the [audit and prompt review](docs/research/AUDIT.md), [ranked landscape](docs/research/SEARCH_PROVIDER_LANDSCAPE.md), [methods](docs/research/METHODOLOGY.md), [labels/metrics](docs/research/BENCHMARKS.md), [results](docs/research/RESULTS.md), and [limitations](docs/research/LIMITATIONS.md). Historical phase-1 results remain available.

V3 added FreeSerp screening, 18 pinned source inspections, a commercial-use audit, fail-closed provider policy and 20 new test functions (98 total). On three common queries Firecrawl/Parallel each returned 3/3 usable sets; FreeSerp met intent on 1/3. A controlled local 503 plus a genuine Parallel fallback worked once, and eight consumers shared one native FreeSerp request. These are bounded observations, not high-volume or outage guarantees. [V3 results](docs/research/RESULTS.md), [article draft](docs/research/LAPIS_RESEARCH_ARTICLE.md).

## Maintenance and roadmap

Next gates: provider distribution authorization, physical iPhone/iPad and multiple-network validation, repeated-day quality/availability, permitted real outage failover and sustained resource/energy testing. Research-preview API changes are additive where practical; breaking changes will be documented before a future semantic-version tag. No SLA, unlimited quota, guaranteed freshness or public-production readiness is promised.

See [architecture](docs/ARCHITECTURE.md), [integration](docs/INTEGRATION.md), [contributing](CONTRIBUTING.md), [security](SECURITY.md) and [changelog](CHANGELOG.md). New adapters need independent rights review, native evidence and deterministic fixtures. Original code/corpus/fixtures are [MIT licensed](LICENSE); no third-party service rights are granted.
