import Foundation

/// An injection seam for deterministic tests and application-managed networking.
/// Custom transports are responsible for cancellation, redirect and response-size enforcement.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest, maximumResponseBytes: Int) async throws -> HTTPResponse
}

public struct HTTPResponse: Sendable {
    public let data: Data
    public let status: Int
    public let contentType: String?
    public let retryAfter: String?

    public init(data: Data, status: Int, contentType: String?, retryAfter: String? = nil) {
        self.data = data
        self.status = status
        self.contentType = contentType
        self.retryAfter = retryAfter
    }

    func validate(types: Set<String>, maximumBytes: Int) throws {
        switch status {
        case 200...299: break
        case 401: throw SearchError(.unauthorized, httpStatus: status)
        case 402, 429: throw SearchError(.rateLimited, httpStatus: status, retryAfter: RetryAfter.parse(retryAfter))
        case 403, 451: throw SearchError(.blocked, httpStatus: status)
        case 408, 504: throw SearchError(.timeout, httpStatus: status)
        case 500...599: throw SearchError(.serverError, httpStatus: status)
        default: throw SearchError(.invalidResponse, httpStatus: status)
        }
        guard data.count <= maximumBytes else { throw SearchError(.responseTooLarge, httpStatus: status) }
        let mime = contentType?.split(separator: ";").first?.trimmingCharacters(in: .whitespaces).lowercased()
        guard let mime, types.contains(mime) else { throw SearchError(.invalidResponse, httpStatus: status) }
    }
}

enum RetryAfter {
    static func parse(_ value: String?, now: Date = Date()) -> Date? {
        guard let rawValue = value else { return nil }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let seconds = TimeInterval(value), seconds.isFinite, seconds >= 0, seconds <= 31_536_000 {
            return now.addingTimeInterval(seconds)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: value)
    }
}

/// Ephemeral URLSession with no cookies, credentials, cache or automatic redirects.
public struct URLSessionTransport: HTTPTransport {
    private let protocolClasses: [AnyClass]
    public init() { protocolClasses = [] }
    init(protocolClasses: [AnyClass]) { self.protocolClasses = protocolClasses }

    public func send(_ request: URLRequest, maximumResponseBytes: Int) async throws -> HTTPResponse {
        guard request.url?.scheme == "https", maximumResponseBytes > 0 else { throw SearchError(.invalidConfiguration) }
        let configuration = URLSessionConfiguration.ephemeral
        if !protocolClasses.isEmpty { configuration.protocolClasses = protocolClasses }
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForResource = request.timeoutInterval
        let session = URLSession(configuration: configuration, delegate: RedirectPolicy(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse else { throw SearchError(.invalidResponse) }
            let type = http.value(forHTTPHeaderField: "Content-Type")
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After")
            // Classify errors before reading their potentially large or sensitive bodies.
            if !(200...299).contains(http.statusCode) {
                return HTTPResponse(data: Data(), status: http.statusCode, contentType: type, retryAfter: retryAfter)
            }
            guard http.expectedContentLength <= Int64(maximumResponseBytes) else {
                throw SearchError(.responseTooLarge, httpStatus: http.statusCode)
            }
            var data = Data()
            for try await byte in bytes {
                try Task.checkCancellation()
                guard data.count < maximumResponseBytes else {
                    throw SearchError(.responseTooLarge, httpStatus: http.statusCode)
                }
                data.append(byte)
            }
            return HTTPResponse(data: data, status: http.statusCode, contentType: type, retryAfter: retryAfter)
        } catch { throw SearchError.classify(error) }
    }
}

final class RedirectPolicy: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) { completionHandler(nil) }
}
