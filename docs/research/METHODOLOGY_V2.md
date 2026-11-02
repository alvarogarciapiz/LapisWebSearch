# Methodology

## Scope and environment

Reference implementation: `65f8a8aa4497b1c073a21376a16cd9c016370d86`. Phase-2 source and observations are versioned together in this repository. Host: physical Apple M4 Mac mini, 16 GB RAM, macOS 27.0.1, Xcode 27.1/Swift 6.4. One host network was used, without proxy rotation or a network switch. ISP/egress geography and provider-side cache behavior were not controlled. Physical iPhone/iPad and independent-network work remain pending unless specifically recorded as executed in RESULTS.md.

All library comparisons use genuine native URLSession requests. Timings use ContinuousClock and include request execution, body delivery and parsing; the retained-client harness also measures coordinator/admission overhead. CLI startup/build time and deliberate request spacing are excluded from per-search timing. The CLI response duration starts at job registration, while the paired harness measures around the public API call, including validation/registration. Firecrawl’s ten-case relevance-cohort timing mixes six CLI durations and four harness durations; this small scope difference is disclosed, and only the matched harness timings support the before/after latency comparison. No answer-generating AI API is invoked. Search services can use ML internally; the client cannot certify their internal implementation.

## Experiments

1. **Provider contract research:** primary docs, service/privacy terms, source and issues were reviewed before selection. Native MCP initialization/tool-schema probes established protocol shape, not search quality. One subsequent search each examined Parallel's structured output and Exa's text-only default output. No You.com requests or comparisons were made because its MSA restricts publication without consent.
2. **Current retrieval sample:** execute Q01–Q10 at five results using Firecrawl and Parallel. Firecrawl Q01–Q06 used the retained-client benchmark CLI; Q07–Q10 came from the controlled paired harness below. All ten Parallel cases used one retained client. This is a declared 10/50 corpus subset, not fifty live tests or a representative random sample of the web.
3. **Paired baseline:** compile the same native consumer harness against archived reference source and current source. Alternate request order for Q07–Q10, use five results and one retained client per process, with at least three seconds between individual requests. The baseline transport still creates its session per request; current transport retains its session. The order control reduces but cannot remove upstream caching, timing or network confounding. Four pairs do not justify a causal Internet-latency claim.
4. **Identical burst:** submit eight identical public queries simultaneously through each version, instrumenting actual HTTP sends with the public transport injection seam. This measures subscriber success and request sharing. It is one controlled scenario, not broad service reliability.
5. **Explicit filters:** request month filtering for Q03/Q05/Q10, plus country ES for Q03. Do not modify query text. Judge whether filters actually satisfy the intent rather than treating newly dated unrelated results as success.
6. **First-success race:** compare Parallel-first sequential execution against bounded first-success for Q03/Q04 using the same provider order. Record all attempts, cancellations and HTTP/search-call counts. Count transport invocations for `tools/call`, including cancellations; distinguish them from confirmed responses and do not infer wire delivery or billing; cancellation does not guarantee server work or quota was refunded. Separate cold MCP setup from a warm call. Two cases are illustrative, not a tail-latency estimate or ranking improvement.
7. **Local transport throughput:** use the same original synthetic test against both source revisions, with a 1 MiB payload delivered in sixteen URLProtocol chunks, three samples and optimized builds. No Internet or provider is involved. This isolates client body-processing overhead; its speedup must never be presented as a live-search speedup.

Do not combine different timing scopes or query cohorts into a before/after headline. A p95 with ten observations is the sample maximum under nearest-rank estimation; four paired observations are reported individually and by median, not as a reliable population p95.

## Reproduce

Offline checks:

```sh
swift test -Xswiftc -warnings-as-errors
swift build -c release -Xswiftc -warnings-as-errors
swift run --package-path Examples/Consumer ConsumerSmoke
swift run --package-path Examples/LatencyHarness LatencyHarness # Usage only, no network.
swift scripts/score-benchmark.swift --self-test
swift scripts/score-benchmark.swift benchmarks/v1/observations-2026-11-01.json
swift scripts/score-benchmark.swift benchmarks/v1/observations-2026-11-01.json --ids Q07,Q08,Q09,Q10
```

Review service rights and remaining quotas before any live command. Start with a small count. The runner stops after a failed nonempty-search attempt rather than exhausting free access:

```sh
swift run -c release LapisWebSearchCLI benchmark --live --provider parallel \
  --dataset benchmarks/v1/queries.json --count 5 --output validation-local/parallel-sanitized.json
# --include-results explicitly saves third-party result content locally; do not commit or publish it.
```

The output without `--include-results` contains query IDs, timings, counts, errors and attempt diagnostics, not raw queries, result text or URLs. A dataset ID still identifies a known public input; do not apply this public-data workflow to personal histories. Use `--offset`, `--count`, `--country`, `--time-range`, `--provider-timeout` and `--strategy` to make experiments explicit. The first Parallel search includes initialization/notification HTTP exchanges; later calls reuse the protocol session. No extra fetch, tools/list, research or decisions tool is called by the adapter.

Build the paired harness against archived baseline source:

```sh
mkdir -p validation-local/phase2/baseline/Examples/LatencyHarness/Sources/LatencyHarness
# This directory is an ignored source export, not a new Git repository.
git archive 65f8a8aa4497b1c073a21376a16cd9c016370d86 | tar -x -C validation-local/phase2/baseline
cp Examples/LatencyHarness/Sources/LatencyHarness/main.swift \
  validation-local/phase2/baseline/Examples/LatencyHarness/Sources/LatencyHarness/main.swift
# Local package identity follows its folder name. Only the consumer manifest changes, not baseline library source.
sed 's/package: "LapisWebSearch"/package: "baseline"/' Examples/LatencyHarness/Package.swift \
  > validation-local/phase2/baseline/Examples/LatencyHarness/Package.swift
swift build -c release --package-path Examples/LatencyHarness
swift build -c release --package-path validation-local/phase2/baseline/Examples/LatencyHarness
```

Obtain each binary path with `swift build -c release --show-bin-path --package-path <consumer-folder>`, then pass the absolute executable paths:

```sh
swift scripts/compare-baseline.swift --live <baseline-LatencyHarness> <current-LatencyHarness> \
  benchmarks/v1/queries.json validation-local/phase2/paired.json
```

That script runs four alternating pairs and one eight-subscriber burst per version, with public queries only. It stops on ordinary search failure; the old burst's busy errors are expected observations and are preserved. Both processes are closed after recording. Raw responses stay local.

To reproduce the offline throughput comparison, copy `TransportPerformanceTests.swift` into the archived package's test target and run `swift test -c release --filter TransportPerformanceTests` for each package. The test prints three timing observations and validates every delivered byte. No strict machine-specific performance threshold is part of CI.
