import Foundation

// Offline schema checks for the original public corpus; no search provider is contacted.
struct Corpus: Decodable {
    struct Query: Decodable {
        let id: String
        let query: String
        let language: String
        let category: String
        let criteria: String
    }
    let version: String
    let queries: [Query]
}
let data = try Data(contentsOf: URL(fileURLWithPath: "benchmarks/v1/queries.json"))
let corpus = try JSONDecoder().decode(Corpus.self, from: data)
precondition(corpus.version == "1.0.0" && corpus.queries.count == 50)
precondition(Set(corpus.queries.map(\.id)).count == 50)
precondition(
    corpus.queries.allSatisfy {
        !$0.criteria.isEmpty && !$0.language.isEmpty && !$0.category.isEmpty && !$0.query.isEmpty
            && $0.query.count <= 500
    })
print("Public corpus v1 validated: 50 distinct IDs with intent/language/category criteria; no live searches.")
