import Foundation

enum URLNormalizer {
    static func normalize(_ url: URL) -> URL? {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let scheme = parts.scheme?.lowercased(), ["https", "http"].contains(scheme),
            let host = parts.host?.lowercased(), !host.isEmpty,
            parts.user == nil, parts.password == nil
        else { return nil }
        parts.scheme = scheme
        parts.host = host
        if (scheme == "https" && parts.port == 443) || (scheme == "http" && parts.port == 80) { parts.port = nil }
        if parts.path.isEmpty { parts.path = "/" }
        // Preserve fragments, path case, query ordering and tracking parameters: changing them can change resources.
        return parts.url
    }
}

enum TextCleanup {
    static func clean(_ value: String) -> String {
        value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}

func withinDeadline<T: Sendable>(
    _ deadline: ContinuousClock.Instant,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await ContinuousClock().sleep(until: deadline)
            try Task.checkCancellation()
            throw SearchError(.timeout)
        }
        defer { group.cancelAll() }
        guard let first = try await group.next() else { throw SearchError(.invalidResponse) }
        return first
    }
}

/// Single-pass deduplication: a stateful lazy Collection predicate may be evaluated more than once.
func uniqueResults(_ candidates: [SearchResult], limit: Int) -> [SearchResult] {
    var seen: Set<URL> = []
    var results: [SearchResult] = []
    for candidate in candidates where seen.insert(candidate.url).inserted {
        results.append(candidate)
        if results.count == limit { break }
    }
    return results
}
