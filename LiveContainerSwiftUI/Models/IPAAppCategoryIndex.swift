import Foundation

// Factual public genres, resolved at build time. No per-library network lookup.
struct IPAAppCategoryIndex {
    private let categories: [String: String]
    static let shared = Self(data: Bundle.main.url(forResource: "AppCategories", withExtension: "json").flatMap { try? Data(contentsOf: $0) })
    init(data: Data?) {
        guard let data, data.count <= 512 * 1024,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = object["categories"] as? [String: String], entries.count <= 10000 else { categories = [:]; return }
        categories = entries.reduce(into: [:]) { output, pair in
            if !pair.key.isEmpty, pair.key.count < 256, !pair.value.isEmpty, pair.value.count < 80 { output[pair.key.lowercased()] = pair.value }
        }
    }
    func category(for identifier: String) -> String? { categories[identifier.lowercased()] }
}
