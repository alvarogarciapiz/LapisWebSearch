# LapisWebSearch

**Native, keyless web search for Swift — experimental.**

A lightweight Swift Package for searching the web directly from Apple devices, with replaceable providers, structured results and bounded fallback. No application backend is required. The library discovers URLs, titles and snippets; it does not fetch result pages or prepare AI context.

**Readiness:** no stable release is available. Firecrawl keyless is the experimental default, subject to daily IP limits and service terms. Commercial deployment needs express Firecrawl authorization. Bing RSS is disabled unless the caller declares separate Microsoft permission. Neither adapter is approved here for unrestricted commercial production. See [provider evaluation](docs/PROVIDERS.md) and [measured validation](docs/VALIDATION.md).

## Features and requirements

- Swift 6 language mode and strict concurrency; async/await and native URLSession.
- iOS/iPadOS 16+, macOS 13+. No external package dependencies.
- Firecrawl v2 JSON search and a restricted, permission-gated Bing RSS adapter using XMLParser.
- An extensible `SearchProvider` contract and ordered sequential fallback.
- Conservative URL normalization, exact deduplication and international text preservation.
- Overall deadlines, cancellation, response bounds and rate-limit cooldowns.
- Local diagnostics without query logging, telemetry, cookies or persistent history.

No Python, Node, Rust, AI framework, hosted Lapis proxy, account or API key is required by the library's default configuration. Internet access and permission to use the selected external service are required.

## Installation

Add the package in Xcode using `https://github.com/alvarogarciapiz/LapisWebSearch`, or add:

```swift
.package(url: "https://github.com/alvarogarciapiz/LapisWebSearch", branch: "main")
```

Then depend on `.product(name: "LapisWebSearch", package: "LapisWebSearch")`. During experimental development, pin a reviewed commit with `.revision(...)` for reproducible application builds. There is no stable version tag.

## Search

```swift
import LapisWebSearch

let search = LapisWebSearch() // Experimental Firecrawl keyless; review its terms first.
let results = try await search.search(
    "Apple Foundation Models Swift documentation",
    limit: 5
)
for result in results {
    print(result.title)
    print(result.url)
    print(result.snippet)
}
```

The native initial probe returned a result titled `Foundation Models` at `https://developer.apple.com/documentation/foundationmodels`. Results change over time; that example is an observed result, not a guarantee or fallback fixture.

## Configuration and diagnostics

```swift
let response = try await search.search(
    "Modelos de lenguaje locales para iPhone",
    options: SearchOptions(limit: 3, timeout: 15, safeSearch: true, fallback: true)
)
let results = response.results
let attempts = response.attempts // Local timings, result counts and error classifications.
```

`SearchOptions` supports a result limit (1...100), overall timeout (0 < seconds <= 300), optional BCP-47 locale, optional safe search and fallback on/off. Queries must contain 1...500 characters after trimming and no embedded control characters. Unsupported settings fail explicitly. Firecrawl supports the boolean safe-search option; it does not advertise a locale parameter, so this adapter rejects `locale`. Spanish queries work without forcing a locale. Bing's `mkt` mapping is experimental and its safe-search setting is unsupported.

Providers are supplied in preference order:

```swift
let search = LapisWebSearch(providers: [FirecrawlProvider(), MyPermittedProvider()])
```

`MyPermittedProvider` represents your own implementation of `SearchProvider`; see [integration](docs/INTEGRATION.md). A successful nonempty provider stops the search. There is no automatic top-up, parallel fan-out or same-provider retry. Empty/malformed lists fail; an explicit zero-result response is recorded separately. At most eight unique providers may be configured. Only configured providers receive the query, including during fallback.

Bing is intentionally absent from default fallback. `BingRSSProvider(hasSeparatePermission: true)` declares permission you already hold; it does not obtain or grant rights. Leave the default `false` unless separately authorized by Microsoft for your use.

Keep a client alive to preserve cooldowns and prevent overlapping requests to a provider. Concurrent calls encountering a busy provider skip it and may fall back; they are not queued. After HTTP 429/402, the client observes `Retry-After` and waits at least 60 seconds before using that provider again. It never sleeps and retries automatically. There is no cache policy: local caching is deliberately unimplemented and disabled in the built-in transport.

## Errors

```swift
do {
    let results = try await search.search("Swift structured concurrency")
    print(results.count)
} catch let error as SearchError {
    switch error.code {
    case .cancelled: break
    case .noResults: print("No results found")
    case .allProvidersUnavailable:
        for attempt in error.attempts {
            print(attempt.provider, attempt.error?.rawValue ?? "unknown")
        }
    default: print(error.code.rawValue)
    }
}
```

Individual attempts distinguish network failure, timeout, cancellation, rate limiting, blocking, unauthorized access, invalid responses, parsing failures, unsupported options, server errors and oversized responses. Aggregate errors retain every attempted/skipped provider. Provider HTTP success does not imply relevant results or fresh information.

## Providers, privacy and limits

| Provider | Default | Access | Status |
|---|---|---|---|
| Firecrawl | Yes, experimental | Official keyless REST; daily request and credit caps per public IP, exact numeric caps not published in reviewed docs | Experimental; commercial authorization unresolved |
| Bing RSS | No | Unofficial RSS interface; separate permission required for this adapter | Disabled due to restrictions; weak relevance in initial probe |

Standard Firecrawl web results are requested without scraping, highlighting, news or images. No account configuration or Authorization header was used in native validation. Shared IPs, VPNs, geographic differences, quotas, outages and service changes can affect availability. See [PROVIDERS.md](docs/PROVIDERS.md) for sources and review dates.

Searches send your query to external services, which see your public IP and may retain data or use upstream services. Processing is local after the response. This is online search, not anonymous or offline search. No Lapis server, telemetry, uploaded history or local document access exists in this package. Fallback discloses the query to additional configured providers. [Privacy details](docs/PRIVACY.md).

## Build, test and native live checks

```sh
swift build
swift test
swift run --package-path Examples/Consumer ConsumerSmoke
swift format lint --strict --recursive Package.swift Sources Tests Examples
swift run LapisWebSearchCLI search "Apple Foundation Models Swift documentation" --provider firecrawl
```

Ordinary tests are deterministic and offline. The last command makes a real request. The CLI emits JSON with results and attempts; exits 0 for nonempty results, 1 for search failure, and 2 for invalid input/usage. It never echoes queries in diagnostics. Results themselves may contain query terms.

An opt-in matrix uses public developer queries and stops on its first failure:

```sh
LAPIS_LIVE=1 ./scripts/validate-live.sh 20
```

It performs at most 20 searches, spaced at least three seconds apart after each completes. Raw outputs stay in ignored `validation-local/`. Review quota and terms before running it. Never run it automatically on public pull requests. Hardware, native validation, quality failures, timings and exact reproduction commands are in [VALIDATION.md](docs/VALIDATION.md).

## Scope, limitations and roadmap

There is no guaranteed free production backend, service SLA, completeness, currentness or commercial reuse permission. Bing RSS feed dates are preserved as raw `rssPubDate` metadata rather than asserted publication dates. Missing publication dates stay `nil`. URL normalization preserves fragments, path case and query ordering; it does not strip tracking parameters or rewrite provider redirects. Ranking is preserved; no domain-diversity reshuffle, BM25, embedding, page extraction or RAG is performed.

Release work: resolve commercial provider authorization, validate on a physical iPhone and more networks, accumulate longitudinal quality evidence, and add independently reviewed permitted providers. Categories, cache, health persistence and parallel searching are deferred.

Read [architecture](docs/ARCHITECTURE.md), [integration](docs/INTEGRATION.md), [performance](docs/PERFORMANCE.md), [contributing](CONTRIBUTING.md), [security](SECURITY.md) and [changelog](CHANGELOG.md).

## License

Original code and synthetic test fixtures are [MIT licensed](LICENSE). No third-party implementation or asset is incorporated. This license grants no rights to external search services or their returned content.
