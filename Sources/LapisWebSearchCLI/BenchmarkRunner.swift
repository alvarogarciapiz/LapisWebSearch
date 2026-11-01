import Foundation
import LapisWebSearch

/// Opt-in public-corpus evaluation, never part of ordinary tests or CI. One retained native client.
enum BenchmarkRunner {
    struct Dataset: Decodable {
        let version: String
        let queries: [Query]
    }
    struct Query: Decodable {
        let id: String
        let query: String
    }
    struct Observation: Encodable {
        let id: String
        let duration: TimeInterval
        let httpRequestCount: Int
        let searchRequestCount: Int
        let resultCount: Int
        let error: SearchError.Code?
        let attempts: [ProviderAttempt]
        let results: [SearchResult]?
    }
    struct Report: Encodable {
        let schemaVersion = 1
        let datasetVersion: String
        let startedAt: Date
        let providerChoice: String
        let strategy: SearchStrategy
        let interval: Double
        let observations: [Observation]
        let stoppedEarly: Bool
    }
    static func run(_ args: [String]) async throws {
        guard args.contains("--live") else { throw SearchCLI.CLIError.usage }
        var values: [String: String] = [:]
        var includeResults = false
        var index = 0
        let permitted = [
            "--provider", "--dataset", "--count", "--offset", "--interval", "--strategy", "--output", "--country",
            "--time-range", "--provider-timeout",
        ]
        while index < args.count {
            let flag = args[index]
            if flag == "--live" {
                index += 1
                continue
            }
            if flag == "--include-results" {
                includeResults = true
                index += 1
                continue
            }
            guard permitted.contains(flag), index + 1 < args.count else { throw SearchCLI.CLIError.usage }
            values[flag] = args[index + 1]
            index += 2
        }
        guard let path = values["--dataset"], let provider = values["--provider"],
            ["firecrawl", "parallel", "research-fallback", "parallel-first"].contains(provider),
            let count = Int(values["--count"] ?? "5"), (1...20).contains(count),
            let offset = Int(values["--offset"] ?? "0"), offset >= 0,
            let interval = Double(values["--interval"] ?? "3"), interval.isFinite, (1...60).contains(interval),
            let strategy = SearchStrategy(rawValue: values["--strategy"] ?? "sequential")
        else { throw SearchCLI.CLIError.usage }
        let dataset = try JSONDecoder().decode(Dataset.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        guard offset < dataset.queries.count, Set(dataset.queries.map(\.id)).count == dataset.queries.count else {
            throw SearchCLI.CLIError.usage
        }
        let range = values["--time-range"].flatMap(SearchTimeRange.init(rawValue:))
        if values["--time-range"] != nil && range == nil { throw SearchCLI.CLIError.usage }
        let budget = values["--provider-timeout"].flatMap(Double.init)
        if values["--provider-timeout"] != nil && budget == nil { throw SearchCLI.CLIError.usage }
        let options = SearchOptions(
            limit: 5, strategy: strategy, providerTimeout: budget,
            country: values["--country"], timeRange: range)
        let transport = BenchmarkTransport()
        let client = LapisWebSearch(providers: try SearchCLI.makeProviders(provider, transport: transport))
        let queries = Array(dataset.queries.dropFirst(offset).prefix(count))
        let started = Date()
        var observations: [Observation] = []
        for (index, query) in queries.enumerated() {
            let instant = ContinuousClock.now
            let before = await transport.counts
            do {
                let response = try await client.search(query.query, options: options)
                observations.append(
                    Observation(
                        id: query.id, duration: response.duration,
                        httpRequestCount: await transport.counts.http - before.http,
                        searchRequestCount: await transport.counts.search - before.search,
                        resultCount: response.results.count,
                        error: nil, attempts: response.attempts, results: includeResults ? response.results : nil))
            } catch {
                let error = error as? SearchError ?? SearchError(.invalidResponse)
                let duration = instant.duration(to: .now).components
                observations.append(
                    Observation(
                        id: query.id, duration: Double(duration.seconds) + Double(duration.attoseconds) / 1e18,
                        httpRequestCount: await transport.counts.http - before.http,
                        searchRequestCount: await transport.counts.search - before.search, resultCount: 0,
                        error: error.code, attempts: error.attempts, results: nil))
                if error.code != .noResults { break }
            }
            if index + 1 < queries.count { try await Task.sleep(for: .seconds(interval)) }
        }
        let report = Report(
            datasetVersion: dataset.version, startedAt: started, providerChoice: provider,
            strategy: strategy, interval: interval, observations: observations,
            stoppedEarly: observations.count < queries.count)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(report)
        if let output = values["--output"] {
            try data.write(to: URL(fileURLWithPath: output), options: .atomic)
        } else {
            FileHandle.standardOutput.write(data + Data("\n".utf8))
        }
        if report.stoppedEarly { throw SearchError(.allProvidersUnavailable) }
    }
}

/// Counts requests/methods, never query bodies or headers. Used only by the opt-in benchmark CLI.
private actor BenchmarkTransport: HTTPTransport {
    let underlying = URLSessionTransport()
    var counts = (http: 0, search: 0)
    func send(_ request: URLRequest, maximumResponseBytes: Int) async throws -> HTTPResponse {
        counts.http += 1
        if request.url?.host == "api.firecrawl.dev" {
            counts.search += 1
        } else if let body = request.httpBody,
            let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
            object["method"] as? String == "tools/call"
        {
            counts.search += 1
        }
        return try await underlying.send(request, maximumResponseBytes: maximumResponseBytes)
    }
}
