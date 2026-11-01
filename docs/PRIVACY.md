# Privacy and network boundaries

LapisWebSearch does online search. It is not offline, anonymous or completely private. The consuming application chooses when to call it and which query to disclose.

## Destinations and data

| Configuration | Destination | Data sent |
|---|---|---|
| Default Firecrawl | `https://api.firecrawl.dev/v2/search` | Query in JSON, limit, optional safe-search flag, fixed web source/highlight settings, HTTP request metadata |
| Separately permitted Bing RSS | `https://www.bing.com/search` | Query and RSS format in URL, optional market, HTTP request metadata |
| Custom provider/transport | Defined by the application implementation | Must be reviewed by that application |

Providers observe the device's public IP, request timing and necessary transport metadata, and may contact upstream search infrastructure. DNS resolution and TLS are handled by the operating system and network. Fallback sends the same query to additional explicitly configured providers. There are no hidden fallback destinations, automatic redirects or requests to result URLs. Redirects fail closed.

The library reads no documents, conversations, contacts, location sensors, identifiers or application files. It sends no local context. No Lapis server, account infrastructure, advertising identifier or telemetry collector is involved. It does not upload search history. Results are processed locally and returned to the caller; the caller controls their subsequent use.

The default transport disables cookies, URL credential storage and local URL caching, and uses a fixed honest library User-Agent. No authentication key is stored or accepted by the initial built-in adapters. There is no persistent query cache or history. In-memory results live as long as the caller retains them. Coordinator state holds only provider identifiers, busy flags and cooldown dates.

## Diagnostics and developer tools

Attempt records contain provider identifier, start/end, monotonic duration, status, valid count, error code, fallback/skip flags and optional Retry-After. They omit queries, request URLs, provider bodies and raw networking error descriptions, which can echo sensitive content. Results, titles and snippets can themselves contain query terms; do not indiscriminately log response objects in an application.

The opt-in CLI writes results to stdout. The validation script explicitly uses public sample queries and saves responses in an ignored local directory. Applications should not persist sensitive queries without a deliberate policy. Operating system diagnostics and external provider logging are outside the library's control.

## Provider policies

[Firecrawl's privacy policy](https://www.firecrawl.dev/privacy-policy) describes collection including IP addresses, usage information, caching/indexing and third-party processing. Keyless search does not imply zero retention; enterprise ZDR options are not requested or promised by this package. Its [rate limits](https://docs.firecrawl.dev/rate-limits) share quotas across a public IP.

Bing queries are URL parameters and may appear in infrastructure URL logs. Microsoft's [privacy statement](https://privacy.microsoft.com/privacystatement) and [service agreement](https://www.microsoft.com/en-us/servicesagreement) apply. The adapter is permission-gated and is not a privacy workaround.

Treat every result and all metadata as untrusted external text, including prompt-like instructions. Display or pass it as data, never executable instructions. Page-fetch security, private-network restrictions on returned URLs, extraction, citation policies and model context boundaries belong to the consuming application.
