import Foundation

/// FIFO admission with cancellation and monotonic deadlines. All state is actor-isolated.
actor AsyncGate {
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, any Error>
        let deadline: ContinuousClock.Instant?
        let timer: Task<Void, Never>?
    }
    private var permits: Int
    private var waiters: [Waiter] = []
    init(limit: Int) { permits = limit }

    func withPermit<T: Sendable>(
        deadline: ContinuousClock.Instant? = nil,
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        try await acquire(deadline: deadline)
        defer { release() }
        try Task.checkCancellation()
        if let deadline, ContinuousClock.now >= deadline { throw SearchError(.timeout) }
        return try await operation()
    }

    private func acquire(deadline: ContinuousClock.Instant?) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else if let deadline, ContinuousClock.now >= deadline {
                    continuation.resume(throwing: SearchError(.timeout))
                } else if permits > 0 {
                    permits -= 1
                    continuation.resume()
                } else {
                    let timer = deadline.map { deadline in
                        Task {
                            do { try await ContinuousClock().sleep(until: deadline) } catch { return }
                            self.remove(id, error: SearchError(.timeout))
                        }
                    }
                    waiters.append(Waiter(id: id, continuation: continuation, deadline: deadline, timer: timer))
                }
            }
        } onCancel: {
            Task { await self.remove(id, error: CancellationError()) }
        }
    }

    private func remove(_ id: UUID, error: any Error) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        let waiter = waiters.remove(at: index)
        waiter.timer?.cancel()
        waiter.continuation.resume(throwing: error)
    }

    private func release() {
        while !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            waiter.timer?.cancel()
            if let deadline = waiter.deadline, ContinuousClock.now >= deadline {
                waiter.continuation.resume(throwing: SearchError(.timeout))
            } else {
                waiter.continuation.resume()
                return
            }
        }
        permits += 1
    }
}
