# Provider guide — V3 research preview

No external service is selected by default. `LapisWebSearch()` throws `noEligibleProviders`. Explicit selection grants no usage rights. For the full evidence/classification and dates, read the [commercial audit](research/COMMERCIAL_USE_AUDIT.md); for request/source investigation, read the [landscape](research/SEARCH_PROVIDER_LANDSCAPE.md).

| Adapter | Interface / key | Supported controls | Required access decision |
|---|---|---|---|
| FirecrawlProvider | Official `POST https://api.firecrawl.dev/v2/search`, JSON, anonymous | Limit, timeout, boolean safe search, country, relative time range; no locale | Restricted commercial use without express authorization. Explicit evaluation only; no implicit default. |
| ParallelSearchProvider | Official `https://mcp.parallel.ai/mcp`, JSON-RPC/SSE, anonymous light access | Limit applied locally; rejects locale/country/time/safe overrides and quoted queries | Anonymous commercial production authorization unverified. Evaluation/production and output terms differ. |
| FreeSerpProvider | Documented `GET https://freeserp.ai/api.php?index=web`, JSON, no key | Limit, timeout, language-only locale such as es; rejects regional es-ES/country/time/safe options | Commercial/content/privacy terms unverified. Opt-in experiment, not a commercially cleared alternative. |
| BingRSSProvider | Unofficial `https://www.bing.com/search?format=rss`, XML, no key | Limit, timeout, experimental mkt locale | Permission gate remains false by default. Feed reuse restrictions require separate authorization; flag grants no rights. |

All original adapters are MIT code with no external dependencies. They use fixed HTTPS endpoints and the bounded native transport; no result URLs are fetched. No browser identity spoofing, proxy rotation, CAPTCHA bypass or hidden key/account is implemented. Conditions can change; no unlimited quota, uptime, geographic consistency or sustained throughput is promised.

Firecrawl requests standard web discovery only, with scraping/highlights disabled. Parallel calls only the documented web_search tool after an initialization/notification handshake and reuses an in-memory session. Lost sessions fail the current request; no retry is added. FreeSerp forces the full-web index and refuses engine fallback to generated homepage profiles, discards scores/summary/promotional fields, and never substitutes crawl time for publication time. Bing feed pubDate is raw metadata, not verified webpage publication time.

Inspect `provider.usage.status`, evidence URLs and review date before selection. `requireCommercialClearance` rejects every currently bundled adapter. Conditional/unverified/restricted assessments cannot silently become commercial fallbacks; the whole registry is rejected before networking. Custom providers default unverified and applications must review their author-supplied evidence. This mechanism does not certify legal claims or grant permission.

V3 native common-query results: Firecrawl/Parallel each 3/3 valid sets; FreeSerp 3/3 valid but only 1/3 intent successes. The larger FreeSerp six-query screen had 2/6 intent successes. Wiby returned JSON but failed all three general-intent screens and was not added. Current measurements and limitations: [RESULTS.md](research/RESULTS.md). Historical phase-1 feed observations: [VALIDATION.md](VALIDATION.md); historical V2: [RESULTS_V2.md](research/RESULTS_V2.md).
