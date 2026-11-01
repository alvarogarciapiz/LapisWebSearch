import Foundation

// Developer-only paired native comparison. Inputs/outputs are public-corpus data, never application history.
// Build both harness executables first (see research/METHODOLOGY.md). No external runtime is required.
struct Corpus: Decodable {
    struct Query: Decodable {
        let id: String
        let query: String
    }
    let queries: [Query]
}
final class Harness {
    let process = Process()
    let input = Pipe()
    let output = Pipe()
    init(_ executable: String) throws {
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["--live"]
        process.standardInput = input
        process.standardOutput = output
        try process.run()
    }
    func search(_ query: Corpus.Query, burst: Int) throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: ["id": query.id, "query": query.query, "burst": burst])
        input.fileHandleForWriting.write(data + Data("\n".utf8))
        var line = Data()
        while let byte = try output.fileHandleForReading.read(upToCount: 1), !byte.isEmpty {
            if byte == Data([10]) { break }
            line.append(byte)
        }
        guard let value = try JSONSerialization.jsonObject(with: line) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        return value
    }
    func close() {
        try? input.fileHandleForWriting.close()
        process.waitUntilExit()
    }
}
guard CommandLine.arguments.count == 6, CommandLine.arguments[1] == "--live" else {
    fatalError(
        "Usage: swift scripts/compare-baseline.swift --live <baseline-binary> <current-binary> <corpus.json> <local-output.json>"
    )
}
let args = CommandLine.arguments
let corpus = try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: URL(fileURLWithPath: args[4])))
let baseline = try Harness(args[2])
let current = try Harness(args[3])
defer {
    baseline.close()
    current.close()
}
var records: [[String: Any]] = []
var stopped = false
for (index, query) in Array(corpus.queries[6..<10]).enumerated() {
    let order =
        index.isMultiple(of: 2)
        ? [("baseline", baseline), ("current", current)] : [("current", current), ("baseline", baseline)]
    for (variant, harness) in order {
        var record = try harness.search(query, burst: 1)
        record["variant"] = variant
        records.append(record)
        print("Paired \(query.id): \(variant)")
        if let outcomes = record["outcomes"] as? [[String: Any]], outcomes.contains(where: { $0["response"] == nil }) {
            stopped = true
            break
        }
        Thread.sleep(forTimeInterval: 3)
    }
    if stopped { break }
}
if !stopped {
    for (variant, harness) in [("baseline", baseline), ("current", current)] {
        var record = try harness.search(corpus.queries[3], burst: 8)
        record["variant"] = variant
        record["experiment"] = "identical-burst"
        records.append(record)
        print("Eight identical subscribers: \(variant)")
        Thread.sleep(forTimeInterval: 3)
    }
}
let result: [String: Any] = [
    "schemaVersion": 1, "baseline": "65f8a8aa4497b1c073a21376a16cd9c016370d86", "records": records,
    "stoppedEarly": stopped,
]
try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]).write(
    to: URL(fileURLWithPath: args[5]), options: .atomic)
