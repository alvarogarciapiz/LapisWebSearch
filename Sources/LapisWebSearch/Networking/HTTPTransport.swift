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
    /// Only used by the fixed-endpoint MCP adapter; never included in diagnostics.
    public let mcpSessionID: String?

    public init(data: Data, status: Int, contentType: String?, retryAfter: String? = nil, mcpSessionID: String? = nil) {
        self.data = data
        self.status = status
        self.contentType = contentType
        self.retryAfter = retryAfter
        self.mcpSessionID = mcpSessionID
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

/// A reusable ephemeral session. Copies share its connection pool, not cookies, credentials or caches.
public struct URLSessionTransport: HTTPTransport {
    private let storage: SessionStorage
    public init() { storage = SessionStorage(protocolClasses: []) }
    init(protocolClasses: [AnyClass]) { storage = SessionStorage(protocolClasses: protocolClasses) }

    public func send(_ request: URLRequest, maximumResponseBytes: Int) async throws -> HTTPResponse {
        guard request.url?.scheme == "https", maximumResponseBytes > 0,
            request.timeoutInterval.isFinite, request.timeoutInterval > 0, request.timeoutInterval <= 300
        else { throw SearchError(.invalidConfiguration) }
        defer { withExtendedLifetime(storage) {} }
        let receiver = BoundedReceiver(maximumBytes: maximumResponseBytes)
        let task = storage.session.dataTask(with: request)
        task.delegate = receiver
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                receiver.start(task, continuation: continuation)
            }
        } onCancel: {
            receiver.cancel()
        }
    }
}

private final class SessionStorage: Sendable {
    let session: URLSession
    init(protocolClasses: [AnyClass]) {
        let configuration = URLSessionConfiguration.ephemeral
        if !protocolClasses.isEmpty { configuration.protocolClasses = protocolClasses }
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForResource = 300
        session = URLSession(configuration: configuration, delegate: RedirectPolicy(), delegateQueue: nil)
    }
    deinit { session.invalidateAndCancel() }
}

/// Every mutable field is protected by lock. Callbacks/continuations are always invoked after unlocking.
/// Chunks arrive on URLSession's delegate queue; no per-byte tasks, copies or cancellation checks.
private final class BoundedReceiver: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private let maximumBytes: Int
    private var task: URLSessionDataTask?
    private var continuation: CheckedContinuation<HTTPResponse, any Error>?
    private var response: HTTPURLResponse?
    private var data = Data()
    private var finished = false
    private var cancelled = false
    private var timer: DispatchWorkItem?

    init(maximumBytes: Int) { self.maximumBytes = maximumBytes }

    func start(_ task: URLSessionDataTask, continuation: CheckedContinuation<HTTPResponse, any Error>) {
        lock.lock()
        if cancelled {
            lock.unlock()
            task.cancel()
            continuation.resume(throwing: SearchError(.cancelled))
            return
        }
        self.task = task
        self.continuation = continuation
        let timeout = task.originalRequest?.timeoutInterval ?? 60
        let timer = DispatchWorkItem { [weak self] in self?.finish(.failure(SearchError(.timeout))) }
        self.timer = timer
        lock.unlock()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: timer)
        task.resume()
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let started = continuation != nil
        lock.unlock()
        if started { finish(.failure(SearchError(.cancelled))) }
    }

    private func finish(_ result: Result<HTTPResponse, any Error>) {
        var result = result
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        if case .failure(let failure) = result, let error = failure as? SearchError,
            error.httpStatus == nil, let status = response?.statusCode
        {
            result = .failure(SearchError(error.code, httpStatus: status, retryAfter: error.retryAfter))
        }
        let continuation = continuation
        self.continuation = nil
        let task = task
        self.task = nil
        let timer = timer
        self.timer = nil
        data = Data()
        lock.unlock()
        timer?.cancel()
        task?.cancel()
        continuation?.resume(with: result)
    }

    private func value(_ http: HTTPURLResponse, data: Data) -> HTTPResponse {
        HTTPResponse(
            data: data, status: http.statusCode,
            contentType: http.value(forHTTPHeaderField: "Content-Type"),
            retryAfter: http.value(forHTTPHeaderField: "Retry-After"),
            mcpSessionID: http.value(forHTTPHeaderField: "Mcp-Session-Id"))
    }

    func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        guard let http = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            finish(.failure(SearchError(.invalidResponse)))
            return
        }
        lock.lock()
        self.response = http
        let active = !finished
        lock.unlock()
        guard active else {
            completionHandler(.cancel)
            return
        }
        if !(200...299).contains(http.statusCode) {
            completionHandler(.cancel)
            finish(.success(value(http, data: Data())))
        } else if http.expectedContentLength > Int64(maximumBytes) {
            completionHandler(.cancel)
            finish(.failure(SearchError(.responseTooLarge, httpStatus: http.statusCode)))
        } else {
            completionHandler(.allow)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive chunk: Data) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        if chunk.count > maximumBytes - data.count {
            let status = response?.statusCode
            lock.unlock()
            finish(.failure(SearchError(.responseTooLarge, httpStatus: status)))
        } else {
            data.append(chunk)
            lock.unlock()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        lock.lock()
        let http = response
        let body = data
        lock.unlock()
        if let error {
            finish(.failure(SearchError.classify(error)))
        } else if let http {
            finish(.success(value(http, data: body)))
        } else {
            finish(.failure(SearchError(.invalidResponse)))
        }
    }

    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) { completionHandler(nil) }
}

final class RedirectPolicy: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) { completionHandler(nil) }
}
