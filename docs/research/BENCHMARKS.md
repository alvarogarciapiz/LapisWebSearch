# V3 reproducible benchmarks

Use the original [50-query v1 corpus](../../benchmarks/v1/queries.json). Do not spend a provider quota just to run every query; screen first and retain failures. The V3 sample is six queries for FreeSerp and three common queries for each existing usable provider, not a completed 50-query benchmark.

## Offline checks

```sh
swift test -Xswiftc -warnings-as-errors
swift scripts/validate-research.swift
swift scripts/score-benchmark.swift --self-test
swift scripts/score-benchmark.swift benchmarks/v3/observations-2026-11-02.json
swift scripts/score-benchmark.swift benchmarks/v3/observations-2026-11-02.json --ids Q01,Q04,Q07
```

[All-cohort metrics](../../benchmarks/v3/metrics-all-2026-11-02.json), [common-query metrics](../../benchmarks/v3/metrics-common-2026-11-02.json), [per-rank labels/reasons](../../benchmarks/v3/observations-2026-11-02.json), [execution records](../../benchmarks/v3/execution-2026-11-02.json) and [screening/operational evidence](../../benchmarks/v3/screening-and-operations-2026-11-02.json) contain no raw queries outside the already-public corpus, headers, IPs, account/session IDs or result text. The result fixture is original synthetic test data and is never called live evidence.

## Opt-in live commands

Review [service permissions](COMMERCIAL_USE_AUDIT.md) first. Explicit selection grants no rights. Keep outputs containing third-party result text out of public Git.

```sh
swift run -c release LapisWebSearchCLI search 'What is retrieval augmented generation?' --provider freeserp --limit 5
swift run -c release LapisWebSearchCLI search 'Modelos de lenguaje locales para iPhone' --provider freeserp --locale es
swift run -c release LapisWebSearchCLI benchmark --live --provider freeserp --dataset benchmarks/v1/queries.json --count 3 --interval 3 --output validation-local/v3/local-report.json
```

The last command screens Q01–Q03, not the exact V3 subset. For the exact selection, make a local dataset with the same version and the original Q01/Q04/Q07/Q08/Q09/Q10 records (three-query common selection: Q01/Q04/Q07). No query rewrites. `--include-results` is required for local result-content judging; it is omitted by default. The CLI counts `HTTPTransport.send` calls, not guaranteed server acceptance/billing; cancellation does not refund quotas.

```sh
swift run -c release LapisWebSearchCLI validate --live fallback
swift run -c release LapisWebSearchCLI validate --live coalescing
```

`fallback` injects a local 503 in the FreeSerp transport and then performs one genuine Parallel search (plus protocol setup). It does **not** call FreeSerp or induce an outage. `coalescing` starts eight same-query consumers against a retained FreeSerp client; response counts are reported separately from native HTTP count. These commands use the fixed public RAG query and export only sanitized execution metadata. They are never run by normal CI/tests.

## Scoring

Use grade 2 for intent-relevant results, 1 for partial matches and 0 for irrelevant results. Failed/invalid sets count as unsuccessful. Success@5 means at least one grade-2 result. Precision@5 is the number of grade-2 results divided by five, including a penalty for missing positions. DCG uses gain `2^grade - 1` and discount `log2(rank + 1)`; the ideal is the five highest unique-resource grades in the observed pool for that query. Empty ideal gets nDCG zero. This is **pooled** nDCG, not an exhaustive ideal web ranking. Near-duplicate content at different URLs can remain; no content fetching/canonicalization is claimed.

Grade definitions, labels and reasons allow metric reproduction, not automatic factual verification. Compare providers on the same IDs and judging date; do not compare a six-query aggregate to another provider's three-query aggregate as if samples matched. Historical definitions/results are preserved in [V2 benchmarks](BENCHMARKS_V2.md).
