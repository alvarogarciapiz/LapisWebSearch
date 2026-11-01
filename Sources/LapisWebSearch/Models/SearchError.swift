import Foundation

/// Errors intentionally exclude queries, server bodies, credentials and URLSession descriptions.
public struct SearchError: Error, Sendable, LocalizedError, Encodable {
    public enum Code: String, Sendable, Codable, CaseIterable {
        case invalidInput, invalidConfiguration, networkUnavailable, timeout, cancelled
        case rateLimited, blocked, unauthorized, invalidResponse, parsingFailure
        case unsupportedOperation, allProvidersUnavailable, noResults, responseTooLarge
        case serverError, providerBusy
    }

    public let code: Code
    public let httpStatus: Int?
    public let retryAfter: Date?
    public let attempts: [ProviderAttempt]

    public init(_ code: Code, httpStatus: Int? = nil, retryAfter: Date? = nil, attempts: [ProviderAttempt] = []) {
        self.code = code
        self.httpStatus = httpStatus
        self.retryAfter = retryAfter
        self.attempts = attempts
    }

    public var errorDescription: String? { "Web search failed: \(code.rawValue)." }

    static func classify(_ error: any Error) -> SearchError {
        if let error = error as? SearchError { return error }
        if error is CancellationError { return SearchError(.cancelled) }
        if let error = error as? URLError {
            switch error.code {
            case .cancelled: return SearchError(.cancelled)
            case .timedOut: return SearchError(.timeout)
            default: return SearchError(.networkUnavailable)
            }
        }
        return SearchError(.invalidResponse)
    }
}
