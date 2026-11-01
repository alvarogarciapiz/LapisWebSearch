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
