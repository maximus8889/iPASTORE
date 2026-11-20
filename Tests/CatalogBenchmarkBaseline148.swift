// Frozen build 148 grouping/sorting path, for paired performance comparisons.
import Foundation
enum CatalogBenchmarkBaseline148 {
    static func entries(_ libraries: [(IPAStoreReference, [AltStoreSourceApp])]) -> [IPAAppEntry] {
        var grouped: [String: [IPAAppVariant]] = [:]
        var seen = Set<String>()
        for (store, apps) in libraries {
            for app in apps {
                if Task.isCancelled { return [] }
                let variant = IPAAppVariant(app: app, store: store)
                guard seen.insert(variant.id).inserted else { continue }
                grouped[IPACatalogPresentation.familyID(app), default: []].append(variant)
            }
        }
        return grouped.map { identifier, variants in
            let preferred = variants.enumerated().sorted {
                if $0.element.isPreview != $1.element.isPreview { return !$0.element.isPreview }
                return $0.offset < $1.offset
            }.map(\.element)
            return IPAAppEntry(id: identifier, variants: preferred)
        }.sorted {
            let result = $0.app.name.localizedStandardCompare($1.app.name)
            return result == .orderedSame ? $0.id < $1.id : result == .orderedAscending
        }
    }
}
