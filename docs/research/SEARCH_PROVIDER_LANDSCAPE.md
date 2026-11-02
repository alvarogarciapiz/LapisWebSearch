# Search-provider landscape — V3, reviewed 2026-11-02

**Finding: no commercially cleared general provider satisfies all required constraints.** FreeSerp Global is a new, native-compatible experimental alternative; it does not resolve the commercial gate or improve broad relevance in our sample. Wiby failed general-query screening. Mwmbl/Marginalia have noncommercial data grants; AnySearch adds anonymous-access and account-provisioning questions.

See [commercial evidence and exact terms](COMMERCIAL_USE_AUDIT.md), [18 pinned source inspections including all 16 requested projects](GITHUB_SOURCE_AUDIT.md), [native results](RESULTS.md) and the preserved [V2 landscape](SEARCH_PROVIDER_LANDSCAPE_V2.md). These are new source/terms observations, not an assumption that wrappers imply access rights.

## Ranked practical leads

| Priority | Candidate | New evidence and decision |
|---|---|---|
| 1 | Parallel / Firecrawl authorization | Already usable native adapters; a deployment-specific written grant would address the central blocker more directly than more scraping adapters. No grant obtained; neither enabled implicitly. |
| 2 | FreeSerp Global | Documented `GET /api.php?index=web&q=…&size=5`. Native JSON returned usable RAG results but poor current/technical results. Small original adapter implemented, explicit opt-in. Commercial/output/privacy grant remains unverified. |
| 3 | Wiby | Documented JSON endpoint and required backlink, small independent classic-web index. Three native general-query probes returned parseable but irrelevant sets. No adapter adopted for this mission; commercial redistribution scope also unverified. |
| 4 | Mwmbl | Explicit anonymous v2 API with per-IP quotas. Current CC BY-NC-SA dataset terms prevent declaring this commercial solution. v1's use in SearXNG does not justify skipping metering. |
| 5 | AnySearch | Official anonymous JSON REST documentation, discovered through actual free-search-mcp code. Terms limit re-provisioning; exhaustion may generate credentials/account. No native query made, no silent account/key transition implemented. |
| 6 | Marginalia | Official experimentation key and documented API; commercial data use is metered or negotiated, not a free anonymous entitlement. |
| 7 | SearXNG | Native JSON technically simple. No specific operator permission plus upstream commercial rights established. A public directory is not an authorized instance pool. |
| 8 | Official Brave / Mojeek / Yep | Genuine sanctioned APIs, but keys/contracts/payment violate this mission's default requirements. Not substituted silently. |
| 9 | Consumer HTML engines | DDG/Bing/Startpage/Ecosia/Qwant/Yahoo/Yandex/Swisscows/Baidu/360 adapters in wrappers add parsing breadth, not authorization or stable native access. Restricted/unverified interfaces not implemented. |

## Underlying-engine technical matrix

“Native feasible” means HTTP/format could be implemented with URLSession, not a live device test or access grant. **Not tested** is distinct from failed. Engines not screened were excluded by scope/rights first, avoiding unnecessary traffic. No undocumented result endpoint was promoted to a supported API.

| Engine | Endpoint / response inspected | Browser/session/key considerations | Spanish / native live evidence / risk |
|---|---|---|---|
| DuckDuckGo HTML | `https://html.duckduckgo.com/html/`, GET/form POST, HTML CSS/XPath | No browser key; wrappers increasingly add impersonation/browser fallbacks; no such fallback allowed here | Region parameters exist; no V3 live search. Previous Lapis blocking remains background evidence, not a V3 rate estimate. |
| DuckDuckGo Lite | `https://lite.duckduckgo.com/lite/`, form HTML | No key/JS needed for page parsing in principle; challenge/session variability | No V3 test; no commercial embedded-result permission established. |
| DuckDuckGo Instant Answer | `https://api.duckduckgo.com/`, JSON topic/related answers | Native JSON feasible, no key; not general ranked results | General query coverage not implied by topic answers. No V3 query. |
| Brave public search | `https://search.brave.com/search`, HTML | Wrappers use axios/Playwright; challenges can prevent native access. Official API uses key | Spanish/latency not measured here. Scraping interface not commercially cleared. |
| Bing HTML | `https://www.bing.com/search`, CN/www4 variants, HTML | Cookie warm-up and browser pools/impersonation appear in wrappers | No V3 test. Endpoint variants do not grant reuse rights or demonstrate independent fallback. |
| Bing RSS | Same `/search` with `format=rss`, XML | Native XMLParser implemented; permission gate retained | Historical poor relevance and restrictive feed notice. No V3 call. |
| Mojeek | Public `/search?q=…` HTML; official Search API JSON/XML | Official contracted API; public automation/scraping needs authorization | No V3 test, no anonymous commercial entitlement. |
| Startpage | Public `/sp/search` / browser result paths, HTML | Wrappers use browser/HTTP; official anti-scraping enforcement | No V3 test; JavaScript/cookie requirements can depend on challenge state. |
| Ecosia | `https://www.ecosia.org/search?q=…`, HTML | HTTP/browser technically possible; automated access prohibited by terms | No V3 test; legitimate human business use differs from extraction. |
| Qwant | `https://api.qwant.com/v3/search/web`, JSON | SearXNG labels API undocumented; bot/token machinery, no third-party license by default | No V3 test; JSON alone is not a sanctioned app interface. |
| Yahoo | `https://search.yahoo.com/search`, HTML | Wrappers use cookies/tokens/impersonation; collection permission needed | No V3 test; regional terms matter. |
| Yandex | `/search/` or `/search/site/`, HTML | HTTP native feasible; personal/noncommercial service scope | No V3 test; separate XML/cloud contracts not keyless commercial clearance. |
| Yep | `api.yep.com` browser-service JSON in SearXNG; official `https://platform.yep.com/api/search` | Official API Bearer key + metered balance; old service surface not API authorization | No V3 test; undocumented access not adopted. |
| Swisscows | `https://api.swisscows.com`, browser-service API | SearXNG manages request tokens/session machinery; no supported integration grant established | No V3 test; no proven direct-device quota or Spanish quality. |
| Baidu | `https://www.baidu.com/s`, HTML; cloud AI Search JSON | Consumer warm-up/cookies in wrappers; official cloud API needs key/account | Chinese focus; Spanish not evaluated. No V3 search. |
| 360 Search | `https://www.so.com/s?q=…`, HTML `data-mdurl`/anchors | Native parser possible, no applicable programmatic commercial grant found | No V3 query; Chinese wrapper breadth is not Spanish quality evidence. |
| SearXNG | Operator `/search?format=json` | Formats, engines, authentication/limits set by each operator | No V3 instance queries; only operator-permitted instances would qualify. |
| Marginalia | `https://api2.marginalia-search.com/search?query=…`, JSON | API-Key header, shared `public` experimentation credential | Small-web corpus; no V3 call. Noncommercial data license / paid commercial option. |
| Mwmbl | `https://api.mwmbl.org/api/v2/search/?q=…`, JSON | Anonymous 1,000/month/IP, 1 req/s; server/data licenses differ | No V3 query; noncommercial data conditions unresolved for Lapis. |
| Wiby | `https://wiby.me/json/?q=…`, JSON | No key/JS/cookie needed in three native probes; mandatory Wiby link | Spanish accents preserved; 3/3 parseable sets, 0/3 useful for sampled general intents. |
| FreeSerp Global | `https://freeserp.ai/api.php?index=web&q=…`, JSON | No key/account/cookie in native probes; supports language-only filter, batch-refreshed index | Six normalized benchmark sets valid; 2/6 Success@5. Native Mac/iPhone/iPad simulator checks. Terms and long-run reliability unresolved. |
| AnySearch | `POST https://api.anysearch.com/v1/search`, JSON | Optional key; per-IP anonymous quota; 402 may auto-register credentials | Official `language` preference; Spanish/quality/latency not measured. No live search. |

## Architecture decision

**A, direct documented JSON:** adopted experimentally for FreeSerp. Force the full-web index and reject server fallback to homepage profiles; discard promotional fields, generated homepage summaries and scores. Never fetch result URLs. This is a fixed native adapter, not an API proxy or cloud answer service.

**B, native metasearch:** retain V2's bounded sequential fallback, per-provider budgets, coalescing and explicit first-success racing. Do not enable a provider just to create a longer chain. No fusion, confidence routing or query rewriting was justified: FreeSerp's missing intent/current coverage cannot be repaired by reordering its five URLs. Optional language filtering is explicit, with no inferred query language. Raising concurrency does not raise the provider's permitted quota.

**C, open indexing infrastructure:** Mwmbl, Marginalia, Wiby and infomesh are genuine indexing/distributed projects, but coverage, server/data rights and deployment costs still apply. An embedded crawler/full index, P2P network or Python/Java/Node/browser runtime was not added. No independent full-web index can be produced by porting a request adapter alone.

## New primary-source leads

- FreeSerp: [HTTP contract and fallback semantics](https://freeserp.ai/docs.php), [integration contact](https://freeserp.ai/contact). Index size/ownership and free availability are provider claims, not independently audited measurements. No separate commercial/content license or adequate privacy contract established.
- Wiby: [API and backlink terms](https://wiby.me/json/), [scope](https://wiby.me/about/), [privacy](https://wiby.me/about/pp.html).
- Mwmbl: [anonymous quota/pricing](https://developer.mwmbl.org/), [dataset terms](https://mwmbl.org/terms), [source discussion](https://github.com/mwmbl/mwmbl/issues/410).
- AnySearch: [anonymous auth](https://www.anysearch.com/docs/auth), [402/account flow](https://www.anysearch.com/docs/api-endpoints/v1-search), [terms](https://www.anysearch.com/legal?type=tos). General FAQ privacy claims do not override its more specific truncated-query logging policy.
- FreeNewsAPI: [current authentication docs](https://freenewsapi.ai/docs) require keys from November 1, 2026. Old keyless search-index snippets are stale, demonstrating why current primary sources matter.
