# Contributing

Use Swift 6 and Xcode 16 or later on a Mac. The package has no external dependencies.

```sh
swift build -c release -Xswiftc -warnings-as-errors
swift test -Xswiftc -warnings-as-errors
swift run --package-path Examples/Consumer ConsumerSmoke
swift format format --in-place --recursive Package.swift Sources Tests Examples
swift format lint --strict --recursive Package.swift Sources Tests Examples
```

Ordinary tests must be offline, deterministic and safe for public contributors. Use an injected `SearchProvider`, `HTTPTransport` or session-local URLProtocol. Fixtures are synthetic and explicitly not live evidence. Do not add raw personal queries, credentials, browsing histories or copyrighted feed dumps. New fixture files belong in `Tests/LapisWebSearchTests/Fixtures`; SwiftPM bundles them automatically.

To add a provider, first document its official endpoint, access permission, authentication, limits, terms, privacy and geographic restrictions. Implement the Sendable contract with explicit capabilities, cooperative cancellation, bounded responses and genuine zero-result detection. Preserve source order and supplied dates; never invent metadata or success. Add request-construction, parsing, invalid/empty, status, Unicode and cancellation tests. Keep page fetching, AI, ranking and UI out of the package.

Live testing is opt-in, never a public-PR CI step. Read [VALIDATION.md](docs/VALIDATION.md), obtain necessary access permission and start with a small sample. Do not bypass blocking, rotate proxies, impersonate browsers or exhaust quotas. Report failures and sample sizes alongside successes. Re-evaluate rights before proposing default enablement.

Broken backend reports should include provider identifier, date/time, platform/toolchain, error codes/status, sanitized attempt timings, result counts and whether a VPN/shared IP was involved. Include a public reproducible query only if you are comfortable disclosing it. Do not include personal queries, public IP addresses, tokens or raw provider bodies. State whether the symptom is transport failure, parsing, empty results, poor relevance or stale results.

Keep PRs focused, describe changed behavior and test evidence, and update relevant docs and the unreleased changelog. No stable tag or production claim should be added without the release gates in VALIDATION.md. Contributions must be original or have a verified compatible license and required attribution. The package MIT license does not grant service access rights.

## Phase 2 research and concurrency changes

Run the native metric self-check (`swift scripts/score-benchmark.swift --self-test`) and the offline harness usage check (`swift run --package-path Examples/LatencyHarness LatencyHarness`). Neither contacts providers. Include `scripts` in recursive Swift formatting/lint checks. For concurrency/transport changes, targeted `swift test --sanitize=thread --filter 'ConcurrencyTests|AdmissionTests|URLSessionTransportTests'` is useful on supported Macs; report unsupported tooling or failures honestly.

Do not change the frozen v1 corpus/labels to improve a headline. Add versioned experiments, declare the executed subset, report negative/partial results and link the rubric. Metrics require actual per-rank judgments; the old 13/20 query-level assessment cannot supply missing Precision/nDCG labels. Preserve third-party output restrictions: publish reviewed original metadata, not unrestricted result dumps. An API that prohibits public benchmark publication needs separate permission before inclusion.

Provider adapters must reject unsupported options consistently through both direct use and coordination. Concurrency changes must cover pending bounds, queue expiration, cancellation isolation, final-subscriber cleanup, rate-limit rechecks and first-success loser diagnostics. Do not raise default fan-out merely because a local synthetic benchmark is faster; measure quota/disclosure/relevance costs independently.
