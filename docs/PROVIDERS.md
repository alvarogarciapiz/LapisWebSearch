# Historical Phase 1 provider evaluation

This page preserves the initial investigation. See the current [ranked landscape](research/SEARCH_PROVIDER_LANDSCAPE.md) for Parallel and other Phase 2 candidates, rights and decisions.

Reviewed 2026-11-01. Service access rights are separate from the package's MIT license. Technical availability, source-code licensing and permission to embed a service are three different questions. This is an engineering review, not a grant of third-party rights.

## Firecrawl keyless

**Implemented; experimental default for evaluation. Commercial deployment remains blocked pending express authorization.**

- Official [search documentation](https://docs.firecrawl.dev/features/search), [REST reference](https://docs.firecrawl.dev/api-reference/endpoint/search), [keyless announcement](https://www.firecrawl.dev/blog/firecrawl-keyless-launch) and [rate limits](https://docs.firecrawl.dev/rate-limits).
- Fixed endpoint: `POST https://api.firecrawl.dev/v2/search`. JSON query/limit, `sources: ["web"]`, `highlights: false`, optional `safe`. No Authorization header, account configuration, `scrapeOptions` or extra fetch was needed in native tests. The parser accepts `success: true` with `data.web` rows containing URL/title/description and optional original position.
- Keyless access is officially documented. Reviewed current docs describe daily per-IP request and credit caps, with 429 when either is exceeded, but give no numeric keyless allowance. Search-index snippets of the launch page still mention an older monthly allowance; do not treat that as a guaranteed current quota. One initial three-result probe reported two credits used; that observation does not define all pricing behavior.
- The adapter accepts 1...100 results and queries up to 500 characters. Safe search is supported; no language/locale option is claimed. Search does not add date filters, scrape content, request images/news or enterprise retention options.
- [Terms](https://www.firecrawl.dev/terms-of-service), revised October 7, 2026, section 5.d.1 require express authorization for commercial purposes. The keyless announcement does not by itself establish authorization for redistribution inside a commercial Apple application. No special authorization was obtained in this task.
- [Privacy policy](https://www.firecrawl.dev/privacy-policy): review provider processing and retention before disclosure. The adapter makes no ZDR promise. Public IPs share limits; outages, IP reputation and location can affect access. Geographic coverage and VPN behavior were not established across networks.
- Live evidence: initial native probe plus 20-search Mac matrix and additional native platform/performance checks, detailed in [VALIDATION.md](VALIDATION.md). The matrix produced 20/20 HTTP 200 nonempty parsed result sets, but only 13/20 were graded useful for the requested intent under the documented manual rubric. Four were partial and three failed intent/freshness. No 429 was observed; quotas were not intentionally exhausted.

Successful native requests establish that this configuration worked on the tested network at the recorded time. They establish neither an SLA nor satisfactory general freshness. No production-candidate status is justified.

## Bing RSS

**Adapter implemented and offline-tested; disabled due to restrictions unless the caller declares separate Microsoft permission.**

- Endpoint investigated: `GET https://www.bing.com/search?q=...&format=rss`. This is not represented as an officially supported public search API. No official authorization for this integration was found.
- One native URLSession probe returned HTTP 200, `text/xml`, ten RSS items in approximately 0.790 seconds. It preserved Spanish text. For “Apple Foundation Models Swift documentation,” results were primarily generic Apple homepages, account and support pages, rather than relevant framework documentation. HTTP success was not quality success.
- The returned feed contained an explicit notice restricting result reuse to displaying Bing results in a personal, noncommercial RSS aggregator, with other uses requiring explicit written Microsoft consent. The [Microsoft Services Agreement](https://www.microsoft.com/en-us/servicesagreement), Bing/MSN section, also restricts material reuse. This is a substantive restriction, not permission inferred from free access. Further live matrix requests were stopped after discovering it. No Bing content dump is redistributed in this repository.
- Native XMLParser adapter uses encoded query parameters and optional `mkt` locale. This locale mapping has synthetic request tests, not a multi-locale live quality validation. Safe search is unsupported. Feed `pubDate` values are retained as raw `rssPubDate` metadata because their semantics were not established as page publication dates.
- Public initializer defaults to `hasSeparatePermission: false` and refuses requests. Setting it to true declares that permission already exists; it does not create rights. The CLI similarly requires `--bing-permission` for this adapter or a Firecrawl/Bing fallback chain. The repository owner was not assumed to hold that permission.
- No documented RSS API quota, stability commitment, commercial license, geographic consistency or rate-limit behavior was established. [Microsoft privacy policy](https://privacy.microsoft.com/privacystatement) applies. Query parameters may appear in URL logs.

## Other candidates

No additional provider was enabled solely because an adapter existed elsewhere.

| Candidate | Decision and primary evidence |
|---|---|
| DuckDuckGo Lite/HTML | Not implemented. [Terms](https://duckduckgo.com/terms) and authorization requirements were reviewed; no supported keyless general-search API integration was established. Existing Lapis blocking is background information, not a new live result from this task. HTML adapter fragility and anti-bot behavior do not justify browser impersonation or bypass. |
| Mojeek | Not implemented. Its [official search API](https://www.mojeek.com/services/search/web-search-api/) is a priced service. No authorized keyless interface satisfying this task was established. |
| Brave | Not implemented. Its [official API documentation](https://api-dashboard.search.brave.com/documentation) directs developers to an API key. No authorized keyless public-page interface was established. |
| Public SearXNG | Not implemented. [Search API documentation](https://docs.searxng.org/dev/search_api.html) describes configurable JSON/XML/CSV output; operators can disable formats and access. No particular instance operator's permission or service commitment was established. There is no default public-instance pool or hidden hosted intermediary. |
| Anonymous endpoints in other projects | Deferred. Their adapters do not establish permission, quotas, privacy or direct Apple-device reliability. No unauthenticated credentials or undocumented private APIs were reused. |

## Reference implementation research and licensing

The following were examined as research; no code, fixture, asset or runtime dependency was copied into LapisWebSearch. License observations are scoped to the reviewed repository state and are not access rights for engines.

| Reference | Reviewed material and engineering conclusion |
|---|---|
| [DDGS](https://github.com/deedy5/ddgs) (MIT) | `ddgs/ddgs.py`, `ddgs/engines/bing.py` and provider tree: engine contracts, engine selection, request construction, XPath extraction, URL unwrapping and aggregation. Bing's HTML adapter was marked disabled in inspected source. Adopted the general separation of provider/result/coordinator, not Python, randomized engine order, proxy options or scraping. |
| [dsh-free-search](https://github.com/DDDMUC/dsh-free-search) (MIT) | README, `lib` inventory and `fetch_upstream.js`: configured engine pools, failure cooldown policies, HTTP request/cancellation structure, and free/keyed distinctions. Omitted rotating credentials, uncontrolled fallback pools, page extraction and cloud-fetch infrastructure. Its reliability/“unlimited” statements are not evidence for this package. |
| [ModSearch](https://github.com/liustack/modsearch) (MIT) | `src/providers/firecrawl.ts` and provider tree: keyless JSON body/response shape, timeouts, normalized sources and error classification. Cross-checked Firecrawl access against official docs rather than treating this adapter as authorization. Did not import its fetch pipeline. |
| [Kestrel Search](https://github.com/rafaelpierre/kestrelsearch) | `src/kestrelsearch/search.py`: independent engines, shared timeout, merging and bounded retries. No repository-level license was reported in GitHub metadata during review; no reuse was attempted. Browser impersonation, parallel fan-out and Python dependencies were excluded. |
| [dsh-free-web-search](https://github.com/sjlgg/dsh-free-web-search) (Apache-2.0) | `src/backends/bing.ts` and test inventory: RSS fields, market mapping and parsing/error tests. Its use of a feed and parsed dates does not establish commercial rights or publication-date semantics. Our parser and synthetic fixtures are original. |
| [hsandhu/agent](https://github.com/hsandhu/agent) | `Agent/Web/WebSearch.swift` and web adapter inventory: Swift provider/result seam and native request structure. No repository-level license was reported in GitHub metadata; no code reuse was attempted. Its browser User-Agent approach was excluded. |
| [SearXNG](https://docs.searxng.org/) | Search API and operator-controlled formats/access: self-hosting would add infrastructure; public instances require operator-specific permission. Neither is a hidden default in this package. |

## Readiness decisions

Firecrawl: **Experimental**, useful for constrained authorized evaluation. Bing RSS: **Disabled due to restrictions**, with experimental adapter code retained for separately permitted use. Alternatives: not implemented. No provider is a production candidate or validated for broad commercial use. Reassess terms, genuine app-level behavior, relevance and multiple ordinary networks before changing these statuses. Nothing here promises unlimited, unblockable or anonymous access.
