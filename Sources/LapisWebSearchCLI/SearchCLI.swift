import Foundation
import LapisWebSearch

@main struct SearchCLI {
    static func main() async {
        do {
            let args = Array(CommandLine.arguments.dropFirst())
            if args.isEmpty || args == ["--help"] {
                print(usage)
                return
            }
            if args.first == "validate" {
                try await ValidationRunner.run(Array(args.dropFirst()))
                return
            }
            if args.first == "benchmark" {
                try await BenchmarkRunner.run(Array(args.dropFirst()))
                return
            }
            guard args.first == "search", args.count >= 2, !args[1].hasPrefix("--") else { throw CLIError.usage }
            var provider = "none"
            var commercial = false
            var limit = 5
            var timeout = 20.0
            var locale: String?
            var safe: Bool?
            var permission = false
            var strategy = SearchStrategy.sequential
            var providerTimeout: Double?
            var country: String?
            var timeRange: SearchTimeRange?
            var parallelism = 2
            var index = 2
            while index < args.count {
                let flag = args[index]
                if flag == "--commercial" {
                    commercial = true
                    index += 1
                    continue
                }
                if flag == "--bing-permission" {
                    permission = true
                    index += 1
                    continue
                }
                guard index + 1 < args.count else { throw CLIError.usage }
                let value = args[index + 1]
                switch flag {
                case "--provider": provider = value
                case "--limit":
                    guard let number = Int(value) else { throw CLIError.usage }
                    limit = number
                case "--timeout":
                    guard let number = Double(value) else { throw CLIError.usage }
                    timeout = number
                case "--locale": locale = value
                case "--country": country = value
                case "--time-range":
                    guard let range = SearchTimeRange(rawValue: value) else { throw CLIError.usage }
                    timeRange = range
                case "--strategy":
                    guard let selected = SearchStrategy(rawValue: value) else { throw CLIError.usage }
                    strategy = selected
                case "--provider-timeout":
                    guard let number = Double(value) else { throw CLIError.usage }
                    providerTimeout = number
                case "--parallelism":
                    guard let number = Int(value) else { throw CLIError.usage }
                    parallelism = number
                case "--safe":
                    guard ["true", "false"].contains(value) else { throw CLIError.usage }
                    safe = value == "true"
                default: throw CLIError.usage
                }
                index += 2
            }
            let providers = try makeProviders(provider, bingPermission: permission)
            let client = LapisWebSearch(
                providers: providers,
                configuration: .init(providerPolicy: commercial ? .requireCommercialClearance : .explicitSelection))
            let response = try await client.search(
                args[1],
                options: .init(
                    limit: limit, timeout: timeout, locale: locale, safeSearch: safe, strategy: strategy,
                    maximumParallelProviders: parallelism, providerTimeout: providerTimeout, country: country,
                    timeRange: timeRange))
            try printJSON(response)
        } catch let error as SearchError {
            try? printJSON(error)
            exit(error.code == .invalidInput ? 2 : 1)
        } catch {
            FileHandle.standardError.write(Data(("\(error.localizedDescription)\n\(usage)\n").utf8))
            exit(2)
        }
    }

    static func makeProviders(
        _ name: String, bingPermission: Bool = false, transport: any HTTPTransport = URLSessionTransport()
    ) throws -> [any SearchProvider] {
        switch name {
        case "none": return []
        case "freeserp": return [FreeSerpProvider(transport: transport)]
        case "freeserp-first":
            return [FreeSerpProvider(transport: transport), ParallelSearchProvider(transport: transport)]
        case "firecrawl": return [FirecrawlProvider(transport: transport)]
        case "parallel": return [ParallelSearchProvider(transport: transport)]
        case "research-fallback":
            return [FirecrawlProvider(transport: transport), ParallelSearchProvider(transport: transport)]
        case "parallel-first":
            return [ParallelSearchProvider(transport: transport), FirecrawlProvider(transport: transport)]
        case "bing-rss":
            guard bingPermission else { throw CLIError.restricted }
            return [BingRSSProvider(hasSeparatePermission: true)]
        case "fallback":
            guard bingPermission else { throw CLIError.restricted }
            return [FirecrawlProvider(), BingRSSProvider(hasSeparatePermission: true)]
        default: throw CLIError.usage
        }
    }

    static func printJSON(_ value: some Encodable) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        print(String(decoding: try encoder.encode(value), as: UTF8.self))
    }

    enum CLIError: LocalizedError {
        case usage, restricted
        var errorDescription: String? {
            switch self {
            case .usage: "Invalid command line."
            case .restricted:
                "Bing RSS is restricted. --bing-permission declares that you already hold separate Microsoft permission. The flag grants no rights."
            }
        }
    }

    static let usage = """
        LapisWebSearchCLI (experimental; external provider terms apply)
        search "query" [--provider firecrawl|parallel|freeserp|freeserp-first|research-fallback|parallel-first|bing-rss|fallback] [--limit 1...100]
          [--timeout seconds] [--provider-timeout seconds] [--strategy sequential|firstSuccess]
          [--parallelism 1...4] [--locale es-ES] [--country ES] [--time-range day|week|month|year]
          [--safe true|false] [--bing-permission] [--commercial]
        benchmark --live --provider firecrawl|parallel|freeserp|freeserp-first|research-fallback|parallel-first --dataset path --count 1...20
          [--offset 0] [--interval 3] [--strategy sequential|firstSuccess] [--include-results] [--output path]
        Benchmark output omits query text and result content unless --include-results is explicitly requested.
        validate --live fallback|coalescing
        Fallback validation injects a local 503, then contacts Parallel. It is not a real provider outage.
        JSON on stdout; exit 0 = nonempty results, 1 = search failure, 2 = invalid input/usage.
        Firecrawl does not support locale. Bing requires separate permission and does not support safe search.
        No implicit provider: select --provider explicitly. --commercial rejects all currently bundled providers.
        FreeSerp supports language-only --locale es, not regional es-ES; commercial access remains unverified.
        No query logging, retries, scraping or browser impersonation.
        """
}
