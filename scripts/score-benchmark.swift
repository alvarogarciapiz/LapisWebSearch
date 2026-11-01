import Foundation

// Offline retrieval metrics from explicit reviewer labels. No model, network or provider content needed.
struct JudgedRun: Decodable {
    struct Result: Decodable {
        let resourceID: String
        let grade: Int
        let reason: String
    }
    let id: String
    let variant: String
    let provider: String
    let duration: Double
    let results: [Result]
    let validResultCount: Int
    let error: String?
}
struct Evidence: Decodable {
    let schemaVersion: Int
    let runs: [JudgedRun]
}
func dcg(_ grades: [Int]) -> Double {
    grades.prefix(5).enumerated().reduce(0) { $0 + (pow(2, Double($1.element)) - 1) / log2(Double($1.offset + 2)) }
}
if CommandLine.arguments.contains("--self-test") {
    precondition(dcg([0, 0, 0]) == 0)
    precondition(abs(dcg([2, 0, 0]) - 3) < 1e-9)
    precondition(abs(dcg([0, 2, 0]) - 3 / log2(3)) < 1e-9)
    print("Metric self-checks passed (offline synthetic labels).")
} else {
    guard CommandLine.arguments.count == 2 || (CommandLine.arguments.count == 4 && CommandLine.arguments[2] == "--ids")
    else { fatalError("Usage: swift scripts/score-benchmark.swift <reviewed-observations.json> | --self-test") }
    let evidence = try JSONDecoder().decode(
        Evidence.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
    precondition(evidence.schemaVersion == 1)
    var pools: [String: [String: Int]] = [:]
    for run in evidence.runs {
        precondition(
            run.results.count <= 5 && run.results.allSatisfy { (0...2).contains($0.grade) && !$0.reason.isEmpty })
        for result in run.results {
            pools[run.id, default: [:]][result.resourceID] = max(pools[run.id]?[result.resourceID] ?? 0, result.grade)
        }
    }
    var summary: [[String: Any]] = []
    let selectedIDs =
        CommandLine.arguments.count == 4 ? Set(CommandLine.arguments[3].split(separator: ",").map(String.init)) : nil
    let selected = evidence.runs.filter { selectedIDs?.contains($0.id) ?? true }
    let groups = Dictionary(grouping: selected, by: { $0.variant + ":" + $0.provider })
    for key in groups.keys.sorted() {
        let runs = groups[key]!
        precondition(Set(runs.map(\.id)).count == runs.count, "Duplicate query/variant rows would bias averages")
        var precision = 0.0
        var success = 0.0
        var ndcg = 0.0
        for run in runs {
            let grades = run.results.map(\.grade)
            precision += Double(grades.filter { $0 == 2 }.count) / 5
            success += grades.contains(2) ? 1 : 0
            let ideal = (pools[run.id] ?? [:]).values.sorted(by: >)
            let denominator = dcg(ideal)
            ndcg += denominator > 0 ? dcg(grades) / denominator : 0
        }
        let sorted = runs.map(\.duration).sorted()
        let n = runs.count
        let median = n.isMultiple(of: 2) ? (sorted[n / 2 - 1] + sorted[n / 2]) / 2 : sorted[n / 2]
        summary.append([
            "variantProvider": key, "queries": n, "transportSuccess": runs.filter { $0.error == nil }.count,
            "nonempty": runs.filter { $0.validResultCount > 0 }.count,
            "Success@5": success / Double(n), "Precision@5": precision / Double(n), "pooled_nDCG@5": ndcg / Double(n),
            "medianSeconds": median, "sampleP95NearestRankSeconds": sorted[Int(ceil(Double(n) * 0.95)) - 1],
        ])
    }
    let data = try JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys])
    FileHandle.standardOutput.write(data + Data("\n".utf8))
}
