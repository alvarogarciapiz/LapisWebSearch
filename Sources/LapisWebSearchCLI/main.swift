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
            guard args.first == "search", args.count >= 2, !args[1].hasPrefix("--") else { throw CLIError.usage }
            var provider = "firecrawl"
            var limit = 5
            var timeout = 20.0
            var locale: String?
            var safe: Bool?
            var permission = false
            var index = 2
            while index < args.count {
                let flag = args[index]
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
                case "--safe":
                    guard ["true", "false"].contains(value) else { throw CLIError.usage }
                    safe = value == "true"
                default: throw CLIError.usage
                }
                index += 2
            }
            let providers: [any SearchProvider]
            switch provider {
            case "firecrawl": providers = [FirecrawlProvider()]
            case "bing-rss":
                guard permission else { throw CLIError.restricted }
                providers = [BingRSSProvider(hasSeparatePermission: true)]
            case "fallback":
                guard permission else { throw CLIError.restricted }
                providers = [FirecrawlProvider(), BingRSSProvider(hasSeparatePermission: true)]
            default: throw CLIError.usage
            }
            let client = LapisWebSearch(providers: providers)
            let response = try await client.search(
                args[1], options: .init(limit: limit, timeout: timeout, locale: locale, safeSearch: safe))
            try printJSON(response)
        } catch let error as SearchError {
            try? printJSON(error)
            exit(error.code == .invalidInput ? 2 : 1)
        } catch {
            FileHandle.standardError.write(Data(("\(error.localizedDescription)\n\(usage)\n").utf8))
            exit(2)
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
        search "query" [--provider firecrawl|bing-rss|fallback] [--limit 1...100]
          [--timeout seconds] [--locale es-ES] [--safe true|false] [--bing-permission]
        JSON on stdout; exit 0 = nonempty results, 1 = search failure, 2 = invalid input/usage.
        Firecrawl does not support locale. Bing requires separate permission and does not support safe search.
        No query logging, retries, scraping or browser impersonation.
        """
}
