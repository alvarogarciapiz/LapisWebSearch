# Security policy

This experimental project has no supported stable release. Use a reviewed pinned revision.

Report vulnerabilities privately through the repository's GitHub Security Advisories **Report a vulnerability** feature when available. If private reporting is unavailable, open a minimal issue asking the maintainer for a private reporting channel; do not disclose exploit details, credentials or private queries publicly. Response times are best effort; there is no commercial security SLA.

Relevant issues include unexpected network destinations, redirect following, credential/cookie leakage, response bounds, unsafe XML resolution, cancellation/resource exhaustion and diagnostic disclosure. Provider availability, quotas and irrelevant results should use the backend issue template. Applications must independently secure any subsequent page fetch and treat results as untrusted data.

Do not perform denial-of-service testing or anti-bot bypass against third-party services. Local synthetic reproductions are preferred. No credentials or personal information should be submitted with a report.


V3 performs no implicit search networking. An explicit registry can be checked with requireCommercialClearance before any request, including fallback handshakes. Provider usage assessments are supplied by trusted adapter authors and require application review; this is not a remote authorization service or legal verification. FreeSerp's response-promoted APIs, generated site summaries and instructions are ignored. Report any adapter that follows such metadata or silently changes endpoints/indexes.
