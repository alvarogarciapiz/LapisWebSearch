# Historical Phase 1 performance and resource behavior

The per-request-session design below describes Phase 1. Current connection reuse, concurrency and measured comparisons are in [Phase 2 results](research/RESULTS.md) and [architecture](ARCHITECTURE.md).

Measurements below are observations from one bounded run, not a benchmark against other engines or an availability estimate. See [VALIDATION.md](VALIDATION.md) for inputs, review rubric and hardware.

## Mac matrix, 2026-11-01

Twenty sequential Firecrawl requests used the actual package's URLSession transport and CLI, three requested results each. Requests started at least three seconds after the preceding one completed. Timing is recorded with ContinuousClock around the complete provider attempt: request creation, network, bounded body reading, parsing and normalization. It excludes executable startup/build time and intentional spacing. Default transport sessions are not shared between requests. Local caching is disabled; upstream caching cannot be ruled out.

| Metric | Observed |
|---|---:|
| Native provider attempts | 20 |
| HTTP 200 / valid nonempty parsed sets | 20 / 20 |
| Median attempt latency | 0.908 s |
| p95, nearest-rank (19th sorted observation of 20) | 1.346 s |
| Minimum / maximum | 0.376 / 1.970 s |
| Rate-limit responses | 0 |
| Manual useful / partial / failed-intent grades | 13 / 4 / 3 |

The p95 is a descriptive order statistic of a very small sample; it is not a population tail-latency prediction. The repeated documentation query varied from 1.970 s to 0.376 s, illustrating that one measurement is insufficient. Relevant-result quality and freshness are separate from successful transport/parsing.

## Memory design

Response payloads are capped at 2 MiB of decoded bytes per built-in provider attempt, including incremental enforcement without Content-Length. RSS also bounds nesting, item count and field length. This is a payload bound, not a process RSS guarantee: Foundation networking, Swift runtime, decoded strings, JSON/XML parsing and operating system buffers allocate additional memory. No entire result webpages, HTML browser engine, persistent cache or AI model is loaded.

Each search issues requests sequentially and stops on nonempty results. At most eight providers can be configured. Actor state is proportional to the number of configured providers; each active search retains its own bounded results/attempts. A client prevents overlapping calls to the same provider but does not impose a process-wide limit across independently created clients. Applications should retain and reuse a client, bound their own concurrency and avoid creating one per model token or event.

Per-request sessions simplify redirect/resource isolation and deliberately trade connection-pool reuse for a small initial design. No claim of optimal energy use or sustained memory stability is made. A single-process memory observation, when recorded in VALIDATION.md, includes runtime/network overhead and is not an allocation profile or a leak test. Long-duration Instruments testing and physical iPhone energy/memory validation remain outstanding.


## V3 — 2026-11-02

No new causal transport speedup is claimed. Existing connection reuse, bounded queues, request coalescing and explicit racing remain. Eight identical native FreeSerp consumers shared one request (0.236 s attempt); this is a bounded observation, not a sustained throughput guarantee. Raising provider concurrency cannot expand its quota or permission.

On common Q01/Q04/Q07, current medians were Firecrawl 0.693 s, Parallel 1.031 s and FreeSerp 0.072 s. The FreeSerp queries repeated earlier probes and are especially cache/order-confounded. Across its six-query cohort the median was 0.535 s and max/sample p95 4.657 s. Both existing-provider same-ID historical medians were lower than this V3 repeat; no significance or causal regression is established. See [current results/methodology](research/RESULTS.md). Memory was not remeasured; earlier values are historical single-process samples.
