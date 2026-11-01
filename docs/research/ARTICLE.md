# Native web discovery for small-device AI: reducing overhead without pretending search is solved

*Draft for later LAPIS Research publication. Research preview, not peer-reviewed work or a production-readiness announcement. Measurements: 2026-11-01.*

Local language models need a way to discover information published after training. That does not require turning every application into a browser, metasearch server or cloud inference client. Lapis already has page extraction, retrieval, context budgets and citations. Its missing boundary was narrower: obtain usable source titles, URLs and snippets from a native device.

An earlier DuckDuckGo HTML integration illustrated a recurring mistake: a successful diagnostic request was followed by blocked real application requests. LapisWebSearch isolates discovery as a standalone Swift Package so networking behavior, service rights and retrieval quality can be tested independently of an AI application.

## The bottleneck was not only the search service

The first package created an ephemeral URLSession per request and rejected concurrent calls to a busy provider. The second phase retains connection pools, processes bounded body chunks and schedules requests through cancellation-aware queues. Identical in-flight queries share one owned operation. A subscriber can stop waiting without cancelling the other subscribers; when none remain, upstream work is cancelled. Results are not cached after completion.

In a genuine native eight-subscriber experiment, the original implementation returned one successful search and seven busy errors from one HTTP send. The new implementation returned eight successful consumers from one HTTP send. That demonstrates a concrete concurrency improvement without multiplying provider load.

A synthetic local 1 MiB transport test reduced median body-processing time from 17.457 milliseconds to 0.357 milliseconds across three samples. This approximately 49-fold local difference is not a 49-fold Internet search speedup. Four alternating native query pairs had mixed timings: the median changed from 0.518 to 0.490 seconds, with two improvements and two regressions. Network/provider/cache variability dominates such a small sample.

## Faster can also mean worse

We implemented an optional bounded first-success race and tested it with Parallel preferred over Firecrawl. In two cases it returned in 0.387 and 0.167 seconds rather than 1.253 and 1.237 seconds. It also entered both services' search transports. Local cancellation does not establish whether remote work or quota was refunded.

The research-query race returned the faster but weaker results. That is why sequential fallback remains the default and racing is a caller choice. We did not add ranking fusion or an LLM to disguise this tradeoff.

## Provider research is part of the implementation

Parallel's documented keyless MCP interface returned structured search results through native URLSession. The adapter invokes only its search tool, with no browser, Node/Python runtime, answer-generation tool or application-owned backend. Firecrawl remains the compatible experimental default. Neither selection grants commercial service rights.

Other candidates were not automatically adopted. Exa's observed default MCP output was formatted text. You.com's current MSA restricts publication of benchmark results without consent. Bing's RSS reuse restrictions remain. Public SearXNG software licenses do not grant capacity or permission on arbitrary operators' servers. Chinese community implementations often describe “no dependencies” while still using keys, model inference or browser-page scraping. These distinctions materially change which code should be shipped.

## Relevance needs its own evidence

We versioned fifty public queries with intent criteria and ran a bounded ten-query relevance sample per current provider. A single unblinded agent-assisted review graded returned surfaces, not webpage factual correctness. Under the declared rubric, Firecrawl scored Success@5 0.50 and Precision@5 0.38; Parallel scored 0.80 and 0.50. Both had clear failures, including confusion between similarly named Python and Swift projects. Explicit date filters did not reliably fix research/release intent.

The corpus, labels, sanitized observations and native offline scorer are published. Pooled nDCG uses only observed candidates, not an exhaustive web ideal. Original third-party response content remains local because redistribution permissions are not unrestricted, limiting exact retrospective content review.

The package is more useful and better instrumented, but remains a research preview. Commercial authorization, physical mobile devices, multiple ordinary networks, repeated-day quality and real outage-triggered fallback still need evidence. Those gates are part of the result, not footnotes to a production claim.

See [methods](METHODOLOGY.md), [benchmark definitions](BENCHMARKS.md), [provider landscape](SEARCH_PROVIDER_LANDSCAPE.md), [results](RESULTS.md) and [limitations](LIMITATIONS.md) for reproducible commands and the complete qualifications.
