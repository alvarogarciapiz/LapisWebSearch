# LAPIS Research: native web discovery on small devices

LapisWebSearch is an open engineering research preview, not peer-reviewed work or a production service certification. The question is whether a small native Swift client can obtain useful general-web results without an application-owned backend, user keys, paid mandatory APIs, browser automation or AI inference dependencies.

The original Lapis app already owned extraction, retrieval, context budgeting and citations. Its DuckDuckGo HTML integration was blocked in real app requests after a successful diagnostic request. That motivated an independent discovery package; it did not justify bypassing blocks or treating curl as native application validation.

Start with [results](RESULTS.md), then [methodology](METHODOLOGY.md), [benchmark definitions](BENCHMARKS.md), [provider landscape](SEARCH_PROVIDER_LANDSCAPE.md) and [limitations](LIMITATIONS.md). The [audit](AUDIT.md) and [revised execution brief](REVISED_BRIEF.md) explain the changes selected for this phase. [Article draft](ARTICLE.md) is intended for later publication after editorial review.

Evidence categories are explicit throughout: native live observations, deterministic/synthetic correctness and throughput tests, external provider claims, engineering decisions, and pending hypotheses. Public corpus/labels/metrics live in `benchmarks/v1/`. Private application queries are never benchmark inputs. Default diagnostic exports omit raw queries and result content.
