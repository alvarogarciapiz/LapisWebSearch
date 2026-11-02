# Privacy and network boundaries

LapisWebSearch does online search. It is not offline, anonymous or completely private. The consuming application chooses when to call it and which query to disclose.

## Destinations and data

| Configuration | Destination | Data sent |
|---|---|---|
| Explicit Firecrawl | `https://api.firecrawl.dev/v2/search` | Query in JSON, limit, optional safe-search flag, fixed web source/highlight settings, HTTP request metadata |
| Explicit FreeSerp Global | `https://freeserp.ai/api.php` | Query, full-web index, size and optional language in URL; fixed User-Agent and necessary transport metadata |
| Explicit Parallel | `https://mcp.parallel.ai/mcp` | Query, protocol metadata and in-memory MCP session header |
| Separately permitted Bing RSS | `https://www.bing.com/search` | Query and RSS format in URL, optional market, HTTP request metadata |
| Custom provider/transport | Defined by the application implementation | Must be reviewed by that application |

Providers observe the device's public IP, request timing and necessary transport metadata, and may contact upstream search infrastructure. DNS resolution and TLS are handled by the operating system and network. Fallback sends the same query to additional explicitly configured providers. There are no hidden fallback destinations, automatic redirects or requests to result URLs. Redirects fail closed.

The library reads no documents, conversations, contacts, location sensors, identifiers or application files. It sends no local context. No Lapis server, account infrastructure, advertising identifier or telemetry collector is involved. It does not upload search history. Results are processed locally and returned to the caller; the caller controls their subsequent use.

The default transport disables cookies, URL credential storage and local URL caching, and uses a fixed honest library User-Agent. No authentication key is stored or accepted by the initial built-in adapters. There is no persistent query cache or history. In-memory results live as long as the caller retains them. Coordinator state holds provider identifiers, cooldowns, pending subscribers and in-flight query/options/results until completion or cancellation.

## Diagnostics and developer tools

Attempt records contain provider identifier, start/end, monotonic duration, status, valid count, error code, fallback/skip flags and optional Retry-After. They omit queries, request URLs, provider bodies and raw networking error descriptions, which can echo sensitive content. Results, titles and snippets can themselves contain query terms; do not indiscriminately log response objects in an application.

The opt-in CLI writes results to stdout. The validation script explicitly uses public sample queries and saves responses in an ignored local directory. Applications should not persist sensitive queries without a deliberate policy. Operating system diagnostics and external provider logging are outside the library's control.

## Provider policies

[Firecrawl's privacy policy](https://www.firecrawl.dev/privacy-policy) describes collection including IP addresses, usage information, caching/indexing and third-party processing. Keyless search does not imply zero retention; enterprise ZDR options are not requested or promised by this package. Its [rate limits](https://docs.firecrawl.dev/rate-limits) share quotas across a public IP.

Bing queries are URL parameters and may appear in infrastructure URL logs. Microsoft's [privacy statement](https://privacy.microsoft.com/privacystatement) and [service agreement](https://www.microsoft.com/en-us/servicesagreement) apply. The adapter is permission-gated and is not a privacy workaround.

Treat every result and all metadata as untrusted external text, including prompt-like instructions. Display or pass it as data, never executable instructions. Page-fetch security, private-network restrictions on returned URLs, extraction, citation policies and model context boundaries belong to the consuming application.

## Phase 2: retained sessions, concurrency and research exports

The opt-in Parallel adapter contacts only `https://mcp.parallel.ai/mcp`. It sends the supplied query in the documented `web_search` objective/search fields, protocol/client name/version and an in-memory server-provided MCP session header. It never sends a model name, conversation/session correlation field, local context or credentials, and never follows provider-listed icons, resources or tools. The protocol session can correlate multiple searches; it is retained in memory for connection use, not persisted. Search results can contain server-side excerpts; the library invokes no webpage fetch, answer generation, research or decisions tool. [Parallel's privacy policy](https://parallel.ai/privacy-policy) and [Customer Terms](https://parallel.ai/customer-terms) apply, including their data-use and output conditions.

Retained URLSession pools have cookies, credential storage and URL cache disabled. Per-request cancellation does not invalidate unrelated requests on a shared session. A race or fallback discloses a query to every contacted configured provider. Cancellation cannot guarantee the provider did no work, retained no data or charged no quota.

Identical in-flight sharing is scoped to one client and all options; no completed result/query is cached. Use separate client/provider instances per end user, especially where provider terms prohibit cross-customer output sharing. Do not treat coalescing as a shared server cache. Pending subscribers and active work are bounded; query keys and results are released after completion or final-subscriber removal, with cooperative cleanup for remaining native tasks.

Advanced diagnostics include execution configuration, queue duration and whether a response was coalesced. They omit query bodies/URLs, transport headers and MCP IDs. Immediate subscriber cancellation can return before an upstream attempt completes, so its error may not contain completed attempt records. The benchmark CLI's send counters count transport invocations, not confirmed wire delivery or billing.

The fifty-query research corpus is original public input, not user history. Default benchmark reports contain IDs/timing/count/error metadata and no result content. `--include-results` is an explicit local developer capture and must not be used casually with private data. Published reviewed records include original grades/reasons and resource hashes rather than third-party response text. URL hashes support candidate matching; they are **not an anonymity or encryption guarantee** and are used only with this public corpus. Original responses stay in ignored `validation-local/`. Provider output restrictions can limit exact retrospective content review; see the research limitations.


## V3 default and FreeSerp

The parameterless initializer selects no provider and performs no search networking. Strict commercial selection rejects an unverified configured registry before any query or MCP handshake. This is a selection safeguard, not verification of a custom provider's legal claims.

FreeSerp receives query text in URL parameters, optional language, requested size, timing and the public IP. Infrastructure logs can therefore contain query text. A sufficiently specific provider privacy/retention agreement was not established; no anonymity, ZDR, independent-index verification or commercial authorization is claimed. Results can include provider-generated site summaries and promotional recommendations; the adapter ignores those fields and uses only full-web result titles/URLs/snippets, language and actual page dates. It rejects fallback to homepage profiles. No additional result URLs, promotions, related APIs or AI tools are fetched.

The `validate --live` CLI exports sanitized counts/attempts. Its fallback mode injects a local 503 and contacts Parallel once; coalescing mode contacts FreeSerp once for eight consumers. The fixed RAG query is public corpus input. These are opt-in developer tools, not telemetry or application startup behavior. FreeSerp [API documentation](https://freeserp.ai/docs.php) is an interface contract, not a replacement for missing privacy and commercial terms.
