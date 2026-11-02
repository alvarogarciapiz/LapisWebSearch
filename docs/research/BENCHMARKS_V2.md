# Benchmark definitions and grading

Corpus `benchmarks/v1/queries.json` contains fifty original public inputs (version 1.0.0, as-of 2026-11-01), with query IDs, language, category and explicit intent criteria. It covers Spanish/English, mixed Unicode, technical/general/current/local/ambiguous/long-tail/negative queries. Q20 intentionally repeats Q04 as a timing control; it is not an independent population sample. Relative-time queries must record the execution date. Do not silently update versioned inputs after grading.

## What is measured

- Transport success, valid nonempty-result rate and failure/cancellation counts are distinct.
- Each returned top-five discovery surface is assigned a grade: **2 relevant**, **1 partially relevant**, **0 irrelevant**. Failed/invalid/missing ranks contribute zero. An explicitly empty response is a valid transport outcome, but is not a successful positive retrieval.
- Grade 2 must satisfy the stated specificity, locale and temporal intent. A wrong software project/version does not become relevant because its name overlaps. Grade 1 covers useful topical overlap with missing specificity, outdated material or uncertain freshness. Dates supplied by providers/snippets are observations, not verified publication facts.
- For unspecified “recent,” use a 90-day window; “latest” or current news uses 30 days unless the query supplies another interval. “Today” requires the evaluation date. November-2026 research accepts recent adjacent reporting but an upcoming talk or market-size forecast does not establish research findings. General-knowledge queries do not require new publication dates.
- Ambiguous queries can legitimately match multiple senses. Negative/rare-phrase queries require the actual intended match; nonempty unrelated pages are not success. These special categories are present in the corpus but were not all executed in this bounded sample.

This phase used **one unblinded agent-assisted engineering review**, not independent human judges. The reviewer examined the normalized titles, URLs, provider-supplied dates and returned snippets, not destination webpages. Search results can contain errors or generated material. These judgments measure retrieval surfaces, not source authority certification, factual correctness, answer quality or end-user satisfaction. No model-based automatic grading service is invoked by the library or scorer.

## Metrics

For each executed query at k=5:

- **Success@5** = 1 if at least one result has grade 2, otherwise 0.
- **Precision@5** = number of grade-2 results / 5, including missing slots in the denominator. Partial results do not count as fully relevant.
- **DCG@5** = sum of `(2^grade - 1) / log2(rank + 1)` at one-based ranks 1...5.
- **Pooled nDCG@5** uses the best five resource grades in the frozen union of this report's observed candidates for that query as its ideal denominator. Each resource uses the highest assigned grade across observed surfaces for pooling; actual ranking DCG uses its own surface grades. If ideal DCG is zero, score zero.

The ideal pool is **not an exhaustive web judgment set**. It depends on the sampled providers/variants, is small and favors retrieved candidates; adding a provider can change the denominator. Exact URL hashes define resource identity, preserving the package's conservative URL rules. Semantically duplicated URL aliases can inflate precision/diversity impressions; no semantic-diversity score is claimed. The scorer validates grades/reasons and rejects duplicate query/variant rows.

## Observations and privacy

`observations-2026-11-01.json` contains timings, result counts, per-rank grades/reasons and SHA-256 resource IDs of returned normalized URLs. It publishes no query text, third-party titles/snippets, raw provider bodies, public IPs, MCP session identifiers or user histories. Query text is separately declared in the original corpus. Hashes permit pooled candidate matching without redistributing third-party result content. Metrics are reproduced by the native offline Swift scorer; they are descriptive of these labels, not independent ground truth.

Public redistribution rights for provider outputs differ. In particular, Parallel's restrictions are why public records contain original evaluation metadata rather than response dumps. Complete response surfaces were reviewed locally in ignored `validation-local/`. Future independent graders need authorized fresh runs or separately obtained permissions to review original responses. This limits exact retrospective grading reproducibility and is disclosed rather than hidden.

The original phase-1 13/20 useful, 4/20 partial and 3/20 failed grades used three results and query-level judgment. They cannot be converted to missing Precision@5/nDCG labels or compared directly to this phase's stricter ten-query/five-result scores. The four rerun baseline/current pairs provide the matched retrieval comparison. [RESULTS.md](RESULTS_V2.md) reports both without merging them.
