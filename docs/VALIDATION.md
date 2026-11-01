# Historical Phase 1 validation — 2026-11-01

This record describes reference revision `65f8a8a` and its implementation predecessor. For current counts, concurrency, providers and measurements, see [Phase 2 results](research/RESULTS.md).

**Package: unreleased and experimental. No stable tag, release or production-readiness claim.** This record separates deterministic correctness, actual native network behavior, manual discovery quality and third-party usage rights.

## Environment and isolation

- Physical host: Apple M4 Mac mini, 16 GB RAM, macOS 27.0.1, arm64.
- Toolchain: Xcode 27.1 (27A9275), Apple Swift 6.4, package in Swift 6 language mode.
- Simulator runtime: iOS 27.0; iPhone 17 and iPad Pro 11-inch (M5). These are simulators, not physical devices.
- One ordinary host Internet connection. ISP, egress location, public IP and VPN status were not independently established or recorded. No proxy rotation, CAPTCHA bypass or browser impersonation was used. Multiple independent networks were not available for this validation.
- This is a separate Git repository beside `lapis-app` in the workspace. No main Lapis application source was used as a dependency, copied or integrated. Existing application working-tree changes were preserved.

No hardware identifiers, credentials, public IPs, raw search histories or raw third-party response dumps are published. The matrix uses only the public sample queries in `scripts/validate-live.sh`; local outputs are ignored by Git.

## Deterministic and build checks

The final suite has **49 test functions in five suites**, including parameterized cases. All 49 passed on the Mac and iPad Simulator, with zero failing tests. Default tests make no Internet requests. Mock providers, synthetic original JSON/RSS fixtures and session-local URLProtocol cover input validation, normalization, Unicode, query encoding, malformed/empty responses, invalid URLs, content types, response sizes with/without declared lengths, HTTP 401/402/403/408/429/451/5xx, network failure, timeout, cancellation, sequential fallback, shared deadlines, deduplication, cooldowns, registry validation, concurrency isolation and redirect policy.

```sh
swift test -Xswiftc -warnings-as-errors
swift build -c release -Xswiftc -warnings-as-errors
swift run --package-path Examples/Consumer ConsumerSmoke
swift format lint --strict --recursive Package.swift Sources Tests Examples
xcodebuild -scheme LapisWebSearch -destination 'generic/platform=iOS' \
  -derivedDataPath .build/ios CODE_SIGNING_ALLOWED=NO \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES build
xcodebuild -scheme LapisWebSearch -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/simulator CODE_SIGNING_ALLOWED=NO \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES build
```

The independent `Examples/Consumer` is a separate Swift Package importing only the public library product. Its synthetic result is an offline API check, not live evidence. After publication, a separate temporary consumer also fetched revision `ce7319d07d1b355f4f30b06f11850c0dbf8b051f` from the public GitHub URL and successfully compiled an import of `LapisWebSearch` without any Lapis application dependency or search request.

Simulator unit tests use the **aggregate package scheme**, not the library-only build scheme:

```sh
xcrun simctl list devices available
# Boot an available iOS simulator; substitute its UUID below.
xcodebuild -scheme LapisWebSearch-Package \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' \
  -derivedDataPath .build/simulator-tests CODE_SIGNING_ALLOWED=NO test
```

An initial `xcodebuild test -scheme LapisWebSearch` invocation failed before running tests because that generated library scheme had no test action. Switching to `LapisWebSearch-Package` succeeded. Xcode emitted simulator OS-build bookkeeping diagnostics after the successful test run; they were not Swift compiler or test failures. No failed assertion is suppressed.

CI uses public macOS runners with Xcode 16.4/Swift 6 and no secrets, builds release, runs offline tests and the independent consumer, lints, and compiles iOS device/Simulator SDKs. No live quota is consumed on pull requests. Actual GitHub run status must be checked for the published commit; local success alone is not CI evidence.

The published implementation revision `ce7319d07d1b355f4f30b06f11850c0dbf8b051f` passed [GitHub Actions run 41292863649](https://github.com/alvarogarciapiz/LapisWebSearch/actions/runs/41292863649), including all 49 tests, release build, independent consumer, formatting and both Apple SDK builds. Its deprecated checkout-action warning was subsequently addressed by pinning the official v7.0.1 release (Node 24) to an immutable commit. The runner's capacity notice concerns queue availability rather than code correctness.

## Actual live requests

**25 external searches total:** 24 Firecrawl and one Bing RSS.

| Native run | Requests | Outcome | Timing |
|---|---:|---|---|
| Initial standalone URLSession probe, Mac | 1 Firecrawl | HTTP 200, three relevant documentation discovery results | 1.488 s wall time |
| Initial standalone URLSession probe, Mac | 1 Bing | HTTP 200, ten parsed RSS items; poor query relevance and restrictive feed notice | 0.790 s wall time |
| Actual package CLI, Mac matrix | 20 Firecrawl | All HTTP 200, three normalized results each; quality failures retained below | Median 0.908 s; sample p95 1.346 s |
| Actual package CLI, iPhone Simulator native process | 1 Firecrawl | HTTP 200, three results, framework documentation found | 0.426 s attempt |
| Actual package CLI, iPad Simulator native process | 1 Firecrawl | HTTP 200, three results for a Spanish local-model query | 0.439 s attempt |
| Optimized actual package CLI, Mac memory sample | 1 Firecrawl | HTTP 200, three RAG discovery results | 0.470 s attempt; 0.76 s whole process |

The initial probes preceded implementation and are excluded from package matrix statistics. They were genuine Swift URLSession calls, not curl. Simulator checks ran the compiled iOS CLI using `simctl spawn`; they exercised native library networking without a SwiftUI app or the main Lapis tool path. SDK compilation alone was not counted as a live request.

The 20-search matrix ran at 09:10:00–09:11:16 UTC, according to the recorded first/last attempt timestamps. All had 200 statuses, valid nonempty results and no observed transport/parser error or 429. That is 100% transport/normalization success in this sample, **not 100% relevant-search success**. No quota exhaustion or deliberate provider overload was attempted.

## Quality review

The maintainer reviewed all returned titles, URLs and snippets, without downloading destination pages. A “useful” grade means the requested discovery intent was served by at least one credible-looking source without an obvious major intent mismatch. “Partial” means the topic was found but recency, specificity or authority was insufficient. “Failed” means intent/freshness clearly failed despite valid URLs. This is a manual, unblinded engineering rubric, not a scientific relevance benchmark, publication verification or factual audit of snippets.

IDs below map in order to the public queries in the live script. Three results were returned for every row.

| ID | Query intent | Attempt seconds | Grade and observed limitations |
|---:|---|---:|---|
| 1 | Latest AI developments, Spanish | 0.935 | Partial: news-topic hubs; publication recency not demonstrated |
| 2 | Today's Spanish electricity prices | 0.778 | Useful discovery: two titles/snippets explicitly matched 1 November 2026; actual prices not independently verified |
| 3 | Recent small-model research, Spanish | 0.782 | Failed: a 2023 research retrospective plus unrelated education/social material |
| 4 | Foundation Models Swift documentation | 1.970 | Useful: official framework documentation and overview; one generic Foundation result |
| 5 | Latest MLX Swift LM release | 0.742 | Partial: correct repository/index plus WWDC25; latest release/version not established |
| 6 | Valladolid technology news | 0.964 | Partial: relevant news hubs mixed with an old social video |
| 7 | RAG definition, English | 1.072 | Useful: relevant explanatory sources |
| 8 | Local language models for iPhone | 0.717 | Useful discovery: on-topic apps/discussion; no app recommendation or capability verification |
| 9 | Swift cancellation documentation | 0.896 | Useful: official Swift concurrency documentation |
| 10 | Latest on-device AI research, November 2026 | 0.831 | Failed: general AI index and market forecasts did not satisfy current research intent |
| 11 | Sculpture museum opening hours | 0.995 | Useful: official museum page found; snippets disagreed on hours, so source verification remains necessary |
| 12 | Photosynthesis explanation | 0.840 | Useful: relevant educational/reference sources |
| 13 | Python 3.15 release notes | 0.776 | Useful discovery: official documentation/release URLs and recent-looking snippets; dates/content not independently audited |
| 14 | Spanish solar regulation, 2026 | 0.678 | Partial: relevant contemporary-looking commercial/video sources, not authoritative legal verification |
| 15 | Mixed Japanese/English Swift concurrency | 1.018 | Useful topic discovery; international query preserved, mostly English sources |
| 16 | Small models, quantization and MLX Swift | 1.106 | Useful: relevant project and Apple technical sources |
| 17 | Site-restricted LanguageModelSession docs | 1.346 | Useful: official session API documentation |
| 18 | Invented phrase with LapisWebSearch | 1.105 | Failed: unrelated Lua Lapis results; a nonempty response was not meaningful evidence for the exact phrase |
| 19 | Less-common Valladolid village history | 0.919 | Useful: relevant heritage and reference sources |
| 20 | Repeat Foundation Models documentation query | 0.376 | Useful: same three URLs as earlier; upstream caching is possible |

**13 useful (65%), four partial (20%), three failed (15%).** Even useful discovery grades do not prove freshness or underlying factual accuracy. In particular, the “recent research” failures and inability to establish latest release information prevent a broad current-information readiness claim. No invented publication dates or relevance scores were added to results.

## Native reproduction and resource observation

```sh
swift run LapisWebSearchCLI search "Apple Foundation Models Swift documentation" \
  --provider firecrawl --limit 3 --timeout 20
LAPIS_LIVE=1 ./scripts/validate-live.sh 20
```

The script spaces requests by three seconds and stops on the first failure. A 429/403 is evidence to stop, not authorization to change networks or impersonate a browser. Bing was not tested further after its notice; this repository did not declare Microsoft permission on the owner's behalf.

To reproduce a simulator live check, build the CLI for the Simulator SDK, boot the desired simulator, and run the native binary:

```sh
xcodebuild -scheme LapisWebSearchCLI -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/simulator-cli CODE_SIGNING_ALLOWED=NO build
xcrun simctl spawn <booted-simulator-UUID> \
  .build/simulator-cli/Build/Products/Debug-iphonesimulator/LapisWebSearchCLI \
  search "Apple Foundation Models Swift documentation" --provider firecrawl --limit 3
```

For the optimized memory observation, `/usr/bin/time -l` wrapped the release CLI's genuine three-result RAG search. The whole process took 0.76 s, maximum resident set size was **16,252,928 bytes (15.5 MiB)** and reported peak memory footprint was **5,128,936 bytes (4.89 MiB)**. These OS metrics differ in accounting. One sample is neither an Instruments allocation profile nor evidence of leak-free sustained use; it includes Swift/Foundation overhead and excludes build time.

CLI empty/invalid input and permission-gate checks are performed without contacting providers. Rate limits, outages and fallback are covered deterministically; **no actual provider outage, live 429 or permitted second-provider fallback was observed**. Live fallback success rate is therefore not measurable. Never present injected failures as real outages.

## Remaining release gates

- Obtain express Firecrawl commercial authorization applicable to distribution inside Lapis. Review ongoing service/data-use terms.
- Keep Bing disabled without separately established Microsoft permission; its initial quality was inadequate regardless.
- Validate real Lapis tool-path requests in a later integration task, physical iPhone/iPad hardware, multiple ordinary networks and geographically varied/shared-IP conditions.
- Accumulate repeated-day quality/availability evidence, especially current research, less-common exact phrases and multilingual freshness. Respect quotas rather than generating a large arbitrary load.
- Validate sustained memory/energy on constrained devices, and check actual CI for the final published revision.
- A usable allowed fallback provider has not been established. A provider protocol and deterministic fallback tests do not create redundant live infrastructure.

No release tag is warranted while these gates remain open. The package is a working independent library with measured experimental adapters, not a certified production search backend.
