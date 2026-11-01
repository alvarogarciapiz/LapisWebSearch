import Foundation

/// Ordered provider registry, bounded scheduling and identical in-flight search sharing.
/// No completed results are cached. Last-subscriber cancellation cancels the upstream work.
public actor SearchCoordinator {
    private struct Subscriber {
        let continuation: CheckedContinuation<SearchResponse, any Error>
        let coalesced: Bool
    }
    private struct Flight {
        let request: SearchRequest
        let task: Task<Void, Never>
        var subscribers: [UUID: Subscriber]
    }
    private struct Outcome: Sendable {
        let index: Int
        let results: [SearchResult]
        let attempt: ProviderAttempt
    }
    private let providers: [any SearchProvider]
    private let configuration: SearchConfiguration
    private let searchGate: AsyncGate
    private let providerGates: [String: AsyncGate]
    private var cooldowns: [String: Date] = [:]
    private var flights: [UUID: Flight] = [:]
    private var identical: [SearchRequest: UUID] = [:]

    public init(providers: [any SearchProvider], configuration: SearchConfiguration = .init()) {
        self.providers = providers
        self.configuration = configuration
        searchGate = AsyncGate(limit: max(1, configuration.maximumConcurrentSearches))
        var gates: [String: AsyncGate] = [:]
        for provider in providers {
            gates[provider.identifier] = AsyncGate(limit: max(1, configuration.maximumConcurrentRequestsPerProvider))
        }
        providerGates = gates
    }

    public func search(_ request: SearchRequest) async throws -> SearchResponse {
        guard !providers.isEmpty, providers.count <= 8,
            Set(providers.map(\.identifier)).count == providers.count,
            providers.allSatisfy({ !$0.identifier.isEmpty }),
            (1...32).contains(configuration.maximumConcurrentSearches),
            (1...8).contains(configuration.maximumConcurrentRequestsPerProvider),
            (1...1024).contains(configuration.maximumPendingSearches)
        else { throw SearchError(.invalidConfiguration) }
        let subscriberID = UUID()
        return try await withTaskCancellationHandler {
            if Task.isCancelled { throw SearchError(.cancelled) }
            return try await withCheckedThrowingContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume(throwing: SearchError(.cancelled))
                    return
                }
                let count = flights.values.reduce(0) { $0 + $1.subscribers.count }
                guard count < configuration.maximumPendingSearches else {
                    continuation.resume(throwing: SearchError(.providerBusy))
                    return
                }
                if configuration.coalesceIdenticalRequests, let id = identical[request], flights[id] != nil {
                    flights[id]?.subscribers[subscriberID] = Subscriber(continuation: continuation, coalesced: true)
                    return
                }
                let id = UUID()
                let started = ContinuousClock.now
                let task = Task {
                    let result: Result<SearchResponse, any Error>
                    do { result = .success(try await self.execute(request, started: started)) } catch {
                        result = .failure(SearchError.classify(error))
                    }
                    self.complete(id, result: result)
                }
                flights[id] = Flight(
                    request: request, task: task,
                    subscribers: [subscriberID: Subscriber(continuation: continuation, coalesced: false)])
                if configuration.coalesceIdenticalRequests { identical[request] = id }
            }
        } onCancel: {
            Task { await self.cancelSubscriber(subscriberID) }
        }
    }

    private func complete(_ id: UUID, result: Result<SearchResponse, any Error>) {
        guard let flight = flights.removeValue(forKey: id) else { return }
        if identical[flight.request] == id { identical[flight.request] = nil }
        for subscriber in flight.subscribers.values {
            subscriber.continuation.resume(
                with: result.map { response in
                    var response = response
                    response.wasCoalesced = subscriber.coalesced
                    return response
                })
        }
    }

    private func cancelSubscriber(_ subscriberID: UUID) {
        guard let id = flights.first(where: { $0.value.subscribers[subscriberID] != nil })?.key,
            let subscriber = flights[id]?.subscribers.removeValue(forKey: subscriberID)
        else { return }
        subscriber.continuation.resume(throwing: SearchError(.cancelled))
        if let flight = flights[id], flight.subscribers.isEmpty {
            flights[id] = nil
            if identical[flight.request] == id { identical[flight.request] = nil }
            flight.task.cancel()
        }
    }

    private func execute(_ request: SearchRequest, started: ContinuousClock.Instant) async throws -> SearchResponse {
        let deadline = started.advanced(by: .seconds(request.options.timeout))
        let diagnostics = SearchDiagnostics(request.options, providers: providers.map(\.identifier))
        do {
            var response = try await searchGate.withPermit(deadline: deadline) {
                try await self.run(request, deadline: deadline)
            }
            response.duration = seconds(started.duration(to: .now))
            response.configuration = diagnostics
            return response
        } catch {
            var error = SearchError.classify(error)
            error.configuration = diagnostics
            throw error
        }
    }

    private func run(_ request: SearchRequest, deadline: ContinuousClock.Instant) async throws -> SearchResponse {
        var outcomes: [Outcome] = []
        var winner: [SearchResult] = []
        if request.options.strategy == .sequential {
            for index in providers.indices {
                let outcome = await attempt(index, request: request, deadline: deadline)
                outcomes.append(outcome)
                if Task.isCancelled { break }
                if !outcome.results.isEmpty {
                    winner = outcome.results
                    break
                }
                if ContinuousClock.now >= deadline || !request.options.fallback { break }
            }
        } else {
            await withTaskGroup(of: Outcome.self) { group in
                var next = 0
                let width = min(providers.count, request.options.maximumParallelProviders)
                for _ in 0..<width {
                    let index = next
                    next += 1
                    group.addTask { await self.attempt(index, request: request, deadline: deadline) }
                }
                while let outcome = await group.next() {
                    outcomes.append(outcome)
                    if winner.isEmpty && !outcome.results.isEmpty && !Task.isCancelled {
                        winner = outcome.results
                        group.cancelAll()
                    }
                    if winner.isEmpty && !Task.isCancelled && ContinuousClock.now < deadline && next < providers.count {
                        let index = next
                        next += 1
                        group.addTask { await self.attempt(index, request: request, deadline: deadline) }
                    }
                }
            }
        }
        let attempts = outcomes.sorted { $0.index < $1.index }.map(\.attempt)
        if Task.isCancelled { throw SearchError(.cancelled, attempts: attempts) }
        if !winner.isEmpty { return SearchResponse(results: winner, attempts: attempts) }
        if ContinuousClock.now >= deadline { throw SearchError(.timeout, attempts: attempts) }
        let onlyEmpty = !attempts.isEmpty && attempts.allSatisfy { $0.error == .noResults }
        throw SearchError(onlyEmpty ? .noResults : .allProvidersUnavailable, attempts: attempts)
    }

    private func attempt(_ index: Int, request: SearchRequest, deadline: ContinuousClock.Instant) async -> Outcome {
        let provider = providers[index]
        let startedAt = Date()
        let started = ContinuousClock.now
        var queued: TimeInterval = 0
        do {
            try Task.checkCancellation()
            try check(provider, options: request.options)
            guard let gate = providerGates[provider.identifier] else { throw SearchError(.invalidConfiguration) }
            let value = try await gate.withPermit(deadline: deadline) {
                try await self.perform(provider, request: request, deadline: deadline)
            }
            queued = value.queueStart > started ? seconds(started.duration(to: value.queueStart)) : 0
            return outcome(
                index, results: value.results, error: value.error, status: value.status,
                startedAt: startedAt, started: started, queued: queued, skipped: false, request: request)
        } catch {
            let error = SearchError.classify(error)
            // A rejected admission did not contact the provider.
            return outcome(
                index, results: [], error: error, status: error.httpStatus,
                startedAt: startedAt, started: started, queued: seconds(started.duration(to: .now)),
                skipped: true, request: request)
        }
    }

    private func check(_ provider: any SearchProvider, options: SearchOptions) throws {
        if let until = cooldowns[provider.identifier], until > Date() {
            throw SearchError(.rateLimited, retryAfter: until)
        }
        let caps = provider.capabilities
        if (options.locale != nil && !caps.locale) || (options.safeSearch != nil && !caps.safeSearch)
            || (options.country != nil && !caps.country) || (options.timeRange != nil && !caps.timeRange)
        {
            throw SearchError(.unsupportedOperation)
        }
    }

    private struct ProviderValue: Sendable {
        let results: [SearchResult]
        let error: SearchError?
        let status: Int?
        let queueStart: ContinuousClock.Instant
    }
    private func perform(
        _ provider: any SearchProvider, request: SearchRequest,
        deadline: ContinuousClock.Instant
    ) async throws -> ProviderValue {
        try Task.checkCancellation()
        try check(provider, options: request.options)  // A queued request must see a newly established cooldown.
        let start = ContinuousClock.now
        let providerDeadline = min(
            deadline, start.advanced(by: .seconds(request.options.providerTimeout ?? request.options.timeout)))
        guard providerDeadline > start else { throw SearchError(.timeout) }
        let options = request.options.withTimeout(seconds(start.duration(to: providerDeadline)))
        let bounded = try SearchRequest(query: request.query, options: options)
        do {
            let response = try await withinDeadline(providerDeadline) { try await provider.search(bounded) }
            try Task.checkCancellation()
            switch response {
            case .results(let candidates, let status):
                guard !candidates.isEmpty, candidates.allSatisfy({ $0.provider == provider.identifier }) else {
                    throw SearchError(.invalidResponse, httpStatus: status)
                }
                let results = uniqueResults(candidates, limit: request.options.limit)
                return ProviderValue(results: results, error: nil, status: status, queueStart: start)
            case .noResults(let status):
                return ProviderValue(
                    results: [], error: SearchError(.noResults, httpStatus: status), status: status, queueStart: start)
            }
        } catch {
            let error = SearchError.classify(error)
            if error.code == .rateLimited {
                cooldowns[provider.identifier] = max(error.retryAfter ?? Date(), Date().addingTimeInterval(60))
            }
            return ProviderValue(results: [], error: error, status: error.httpStatus, queueStart: start)
        }
    }

    private func outcome(
        _ index: Int, results: [SearchResult], error: SearchError?, status: Int?,
        startedAt: Date, started: ContinuousClock.Instant, queued: TimeInterval, skipped: Bool,
        request: SearchRequest
    ) -> Outcome {
        var attempt = ProviderAttempt(
            provider: providers[index].identifier, startedAt: startedAt, completedAt: Date(),
            duration: seconds(started.duration(to: .now)), httpStatus: status, validResultCount: results.count,
            error: error?.code, wasFallback: request.options.strategy == .sequential && index > 0,
            skipped: skipped, retryAfter: error?.retryAfter)
        attempt.queueDuration = queued
        return Outcome(index: index, results: results, attempt: attempt)
    }
}

func seconds(_ duration: Duration) -> TimeInterval {
    let components = duration.components
    return Double(components.seconds) + Double(components.attoseconds) / 1e18
}

extension SearchOptions {
    func withTimeout(_ timeout: TimeInterval) -> SearchOptions {
        SearchOptions(
            limit: limit, timeout: timeout, locale: locale, safeSearch: safeSearch, fallback: fallback,
            strategy: strategy, maximumParallelProviders: maximumParallelProviders, providerTimeout: providerTimeout,
            country: country, timeRange: timeRange)
    }
}
