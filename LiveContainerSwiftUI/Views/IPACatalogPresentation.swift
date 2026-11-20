import Foundation
import Combine

struct IPAStoreReference: Identifiable, Hashable {
    let id: String
    let url: URL
    let name: String
    let summary: String
    let publisher: URL?
    var suggestion: IPAStoreSuggestion? { IPAStoreDirectory.suggestion(for: url) }
    init(url: URL, name: String, summary: String, publisher: URL?) {
        self.id = IPAStoreDirectory.canonical(url)
        self.url = url; self.name = name; self.summary = summary; self.publisher = publisher
    }
    init(_ suggestion: IPAStoreSuggestion) {
        self.init(url: suggestion.url, name: suggestion.name, summary: suggestion.summary, publisher: suggestion.publisher)
    }
    init(_ item: AltStoreSourcesViewModel.SourceItem) {
        if let known = IPAStoreDirectory.suggestion(for: item.url) {
            self.init(known)
        } else {
            self.init(url: item.url, name: item.displayName, summary: item.source?.subtitle ?? "An independent app library.", publisher: item.source?.website)
        }
    }
}

struct IPAAppVariant: Identifiable, Hashable {
    var id: String { store.id + "|" + app.id }
    let app: AltStoreSourceApp
    let store: IPAStoreReference
    var isPreview: Bool { IPACatalogPresentation.isPreview(app) }
    var edition: String { isPreview ? "Preview" : "Standard" }
}

struct IPAAppEntry: Identifiable, Hashable {
    let id: String
    let variants: [IPAAppVariant]
    var primary: IPAAppVariant { variants[0] }
    var app: AltStoreSourceApp { primary.app }
    let category: String
    init(id: String, variants: [IPAAppVariant]) {
        self.id = id; self.variants = variants
        self.category = IPACatalogPresentation.category(for: variants[0].app)
    }
}

struct IPAAppCategory: Identifiable {
    var id: String { name }
    let name: String
    let apps: [IPAAppEntry]
}

enum IPAProductSelection {
    static func variantKey(_ variant: IPAAppVariant) -> String {
        variant.store.id + "|" + variant.app.bundleIdentifier.lowercased()
    }
    static func versionKey(_ version: AltStoreSourceAppVersion) -> String {
        version.version + "|" + (version.buildVersion ?? "") + "|" + version.downloadURL.absoluteString
    }
    static func variant(in current: IPAAppEntry, origin: IPAAppVariant, selected: String?) -> IPAAppVariant {
        let key = selected ?? variantKey(origin)
        return current.variants.first { variantKey($0) == key } ?? current.primary
    }
    static func version(in variant: IPAAppVariant, selected: String?) -> AltStoreSourceAppVersion? {
        guard let selected else { return variant.app.latestVersion }
        return variant.app.versions.first { versionKey($0) == selected } ?? variant.app.latestVersion
    }
}

enum IPAReleaseNotes {
    // Recognize release headings, not numbered bullets or version mentions in
    // prose. Some publishers put their entire version history in one field.
    private static let heading = try! NSRegularExpression(pattern: #"(?im)^[\t ]*(?:#{1,6}[\t ]+)?(?:\*\*)?(?:version[\t ]+|v)?\[?(\d+(?:\.\d+){1,3}(?:[-+][0-9a-z.-]+)?)\]?(?:\*\*)?[\t ]*(?:[(:—–-][^\r\n]*)?$"#)
    static func latest(in app: AltStoreSourceApp) -> String? {
        guard let release = app.latestVersion,
              let raw = release.localizedDescription?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let ns = raw as NSString
        let matches = heading.matches(in: raw, range: NSRange(location: 0, length: ns.length))
        let current = normalized(release.version)
        let known = Set(app.versions.map { normalized($0.version) } + [current])
        let headings = matches.filter { known.contains(normalized(ns.substring(with: $0.range(at: 1)))) || matches.count > 1 }
        let currentHeading = headings.first { normalized(ns.substring(with: $0.range(at: 1))) == current }
        let start = currentHeading.map { NSMaxRange($0.range) } ?? 0
        let end = headings.first { $0.range.location >= start }?.range.location ?? ns.length
        let latest = ns.substring(with: NSRange(location: start, length: max(0, end - start)))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return latest.isEmpty ? nil : latest
    }
    private static func normalized(_ version: String) -> String {
        let value = version.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return value.hasPrefix("v") ? String(value.dropFirst()) : value
    }
}

enum IPACatalogPresentation {
    private static let gameGenres: Set<String> = ["game", "games", "action", "adventure", "arcade", "board", "card", "casual", "puzzle", "racing", "role-playing", "role playing", "simulation", "strategy", "trivia", "word"]
    private static let names = ["utilities": "Utilities", "developer": "Developer Tools", "developer-tools": "Developer Tools", "entertainment": "Entertainment", "productivity": "Productivity", "education": "Education", "social": "Social", "social-networking": "Social Networking", "photo-video": "Photo & Video", "photography": "Photo & Video", "music": "Music"]
    private static let genreIDs = ["6000": "Business", "6001": "Weather", "6002": "Utilities", "6003": "Travel", "6004": "Sports", "6005": "Social Networking", "6006": "Reference", "6007": "Productivity", "6008": "Photo & Video", "6009": "News", "6010": "Navigation", "6011": "Music", "6012": "Lifestyle", "6013": "Health & Fitness", "6014": "Games", "6015": "Finance", "6016": "Entertainment", "6017": "Education", "6018": "Books", "6020": "Medical", "6021": "Magazines & Newspapers", "6023": "Food & Drink", "6024": "Shopping", "6026": "Developer Tools", "6027": "Graphics & Design"]
    static func displayValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !["", "unknown", "not provided", "n/a", "none", "null", "—", "-"].contains(clean.lowercased()) else { return nil }
        return clean
    }
    static let shelfPageCount = 5
    static let shelfRowsPerPage = 3
    static func shelfPages<Element>(_ items: [Element]) -> [[Element]] {
        let displayed = Array(items.prefix(shelfPageCount * shelfRowsPerPage))
        return stride(from: 0, to: displayed.count, by: shelfRowsPerPage).map {
            Array(displayed[$0..<min($0 + shelfRowsPerPage, displayed.count)])
        }
    }
    static func libraryCategories(_ entries: [IPAAppEntry]) -> [IPAAppCategory] {
        guard !entries.isEmpty else { return [] }
        let all = IPAAppCategory(name: "All Apps", apps: entries)
        guard entries.count > 1 else { return [all] }
        let entertainment = Set(["Entertainment", "Music", "Photo & Video", "Social", "Social Networking", "Sports", "Books", "News", "Magazines & Newspapers"])
        let utilities = Set(["Utilities", "Developer Tools", "Productivity", "Business", "Weather", "Travel", "Reference", "Navigation", "Lifestyle", "Health & Fitness", "Finance", "Education", "Medical", "Food & Drink", "Shopping", "Graphics & Design"])
        let additional = categories(entries.filter { !utilities.contains($0.category) && !entertainment.contains($0.category) && $0.category != "Games" })
        return ([
            IPAAppCategory(name: "Entertainment", apps: entries.filter { entertainment.contains($0.category) }),
            IPAAppCategory(name: "Utilities", apps: entries.filter { utilities.contains($0.category) }),
            IPAAppCategory(name: "Games", apps: entries.filter { $0.category == "Games" })
        ] + additional + [all]).filter { !$0.apps.isEmpty }
    }
    static func libraries(subscribed: [AltStoreSourcesViewModel.SourceItem], discovered: [String: AltStoreSource]) -> [(IPAStoreReference, AltStoreSource?)] {
        let added = Set(subscribed.map { IPAStoreDirectory.canonical($0.url) })
        let owned = subscribed.map { item in
            (IPAStoreReference(item), item.source ?? IPAStoreDirectory.suggestion(for: item.url).flatMap { discovered[$0.id] })
        }
        // A stale discovery copy must never resurrect removed apps or old releases
        // from a library that is already represented by a current subscription.
        return owned + IPAStoreDirectory.suggestions.filter { !added.contains(IPAStoreDirectory.canonical($0.url)) }.map { (IPAStoreReference($0), discovered[$0.id]) }
    }
    static func isPreview(_ app: AltStoreSourceApp) -> Bool {
        let identifier = app.bundleIdentifier.lowercased()
        return app.isBeta || [".beta", ".alpha", ".nightly"].contains { identifier.hasSuffix($0) }
    }
    static func familyID(_ app: AltStoreSourceApp) -> String {
        let identifier = app.bundleIdentifier.lowercased()
        // Only explicit edition suffixes are grouped. Similar display names are not identity.
        for suffix in [".beta", ".alpha", ".nightly"] where identifier.hasSuffix(suffix) {
            return String(identifier.dropLast(suffix.count))
        }
        return identifier
    }
    static func category(for app: AltStoreSourceApp, index: IPAAppCategoryIndex = .shared) -> String {
        guard let raw = displayValue(app.category) else {
            if let genre = index.category(for: app.bundleIdentifier) { return genre }
            let text = (app.name + " " + (app.subtitle ?? "") + " " + String((app.description ?? "").prefix(240))).lowercased()
            func contains(_ words: [String]) -> Bool { words.contains { text.range(of: $0, options: .literal) != nil } }
            if contains(["emulator", "gameboy", "nintendo", "supermario", "super mario", "playstation", " games", " gaming"]) { return "Games" }
            if contains(["debug", "terminal", "linux shell", "signing", "file manager", "clipboard", " vpn"]) { return "Utilities" }
            if contains(["podcast", "music player", "audio player"]) { return "Music" }
            if contains(["media player", "streaming", "video player"]) { return "Entertainment" }
            return "More Apps"
        }
        let key = raw.lowercased().replacingOccurrences(of: "public.app-category.", with: "").replacingOccurrences(of: "_", with: "-")
        if gameGenres.contains(key) || key.hasSuffix("-games") || key.hasSuffix(" games") { return "Games" }
        return names[key] ?? genreIDs[key] ?? raw.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ").capitalized
    }
    static func entries(_ libraries: [(IPAStoreReference, [AltStoreSourceApp])]) -> [IPAAppEntry] {
        var grouped: [String: [IPAAppVariant]] = [:]
        var seen = Set<String>()
        for (store, apps) in libraries {
            for app in apps {
                if Task.isCancelled { return [] }
                let variant = IPAAppVariant(app: app, store: store)
                guard seen.insert(variant.id).inserted else { continue }
                grouped[familyID(app), default: []].append(variant)
            }
        }
        return grouped.map { identifier, variants in
            // A stable partition keeps edition/source priority without sorting
            // each singleton or recomputing preview suffixes in a comparator.
            var preferred = variants
            if variants.count > 1 {
                var standard: [IPAAppVariant] = [], preview: [IPAAppVariant] = []
                for variant in variants {
                    if variant.isPreview { preview.append(variant) } else { standard.append(variant) }
                }
                preferred = standard + preview
            }
            return IPAAppEntry(id: identifier, variants: preferred)
        }.sorted {
            let result = $0.app.name.localizedStandardCompare($1.app.name)
            return result == .orderedSame ? $0.id < $1.id : result == .orderedAscending
        }
    }
    static func categories(_ entries: [IPAAppEntry]) -> [IPAAppCategory] {
        Dictionary(grouping: entries, by: \.category).map { IPAAppCategory(name: $0.key, apps: $0.value) }.sorted {
            if $0.name == "More Apps" { return false }
            if $1.name == "More Apps" { return true }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
    static func featuredIndex(on date: Date, calendar: Calendar = .current, count: Int) -> Int? {
        guard count > 0 else { return nil }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return ((day % count) + count) % count
    }
    static func search(_ text: String, in entries: [IPAAppEntry]) -> [IPAAppEntry] {
        let term = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return [] }
        return entries.filter { entry in
            entry.variants.contains { variant in
                [variant.app.name, variant.app.developerName ?? "", variant.app.subtitle ?? "", entry.category, variant.store.name].contains { $0.localizedCaseInsensitiveContains(term) }
            }
        }.sorted {
            let first = $0.app.name.folding(options: .caseInsensitive, locale: .current).hasPrefix(term.folding(options: .caseInsensitive, locale: .current))
            let second = $1.app.name.folding(options: .caseInsensitive, locale: .current).hasPrefix(term.folding(options: .caseInsensitive, locale: .current))
            return first != second ? first : $0.app.name.localizedStandardCompare($1.app.name) == .orderedAscending
        }
    }
}

@MainActor final class IPASearchHistory: ObservableObject {
    @Published private(set) var terms: [String]
    private let defaults: UserDefaults
    private let key = "IPARecentSearches.v1"
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var seen = Set<String>()
        terms = Array((defaults.stringArray(forKey: key) ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }.prefix(8))
    }
    func record(_ raw: String) {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        terms.removeAll { $0.caseInsensitiveCompare(value) == .orderedSame }
        terms.insert(String(value.prefix(120)), at: 0)
        terms = Array(terms.prefix(8)); persist()
    }
    func remove(_ term: String) { terms.removeAll { $0 == term }; persist() }
    func clear() { terms = []; persist() }
    private func persist() { defaults.set(terms, forKey: key) }
}

// Keep a day's editorial choice stable while independent feeds arrive/retry.
// Persist the choice so reopening the app does not replace the visible feature.
@MainActor final class IPADailyLibraryChoice {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    private func dayKey(_ date: Date, calendar: Calendar) -> String {
        "\(calendar.timeZone.identifier)|\(calendar.ordinality(of: .day, in: .era, for: date) ?? 0)"
    }
    func saved(on date: Date, calendar: Calendar = .current, candidates: [String]) -> String? {
        guard defaults.string(forKey: "IPADailyLibraryDay") == dayKey(date, calendar: calendar),
              let id = defaults.string(forKey: "IPADailyLibraryID"), candidates.contains(id) else { return nil }
        return id
    }
    func select(on date: Date, calendar: Calendar = .current, candidates: [String], eligible: Set<String>) -> String? {
        let day = dayKey(date, calendar: calendar)
        if let id = saved(on: date, calendar: calendar, candidates: candidates), eligible.contains(id) { return id }
        guard let start = IPACatalogPresentation.featuredIndex(on: date, calendar: calendar, count: candidates.count) else { return nil }
        for offset in candidates.indices {
            let id = candidates[(start + offset) % candidates.count]
            guard eligible.contains(id) else { continue }
            defaults.set(day, forKey: "IPADailyLibraryDay"); defaults.set(id, forKey: "IPADailyLibraryID")
            return id
        }
        return nil
    }
}

extension Notification.Name {
    static let ipaStoreAdded = Notification.Name("IPAStore.LibraryAdded")
    static let ipaSearchTabReselected = Notification.Name("IPAStore.SearchTabReselected")
}

@MainActor final class IPACatalogIndex: ObservableObject {
    @Published private(set) var entries: [IPAAppEntry] = []
    private var signature: [String] = []
    func rebuild(_ sources: [AltStoreSourcesViewModel.SourceItem]) {
        let next = sources.map { $0.url.absoluteString + "|" + ($0.source?.id.uuidString ?? "") }
        guard next != signature else { return }
        signature = next
        entries = IPACatalogPresentation.entries(sources.map { (IPAStoreReference($0), $0.source?.apps ?? []) })
    }
}

// Cache derived library rows by immutable source revision. Opening an app or
// showing search must not regroup every release in its parent catalog.
@MainActor final class IPALibraryIndex: ObservableObject {
    static let shared = IPALibraryIndex()
    @Published private(set) var revision = 0
    private struct Snapshot {
        let sourceID: UUID
        let entries: [IPAAppEntry]
        let categories: [IPAAppCategory]
        let browsingCategories: [IPAAppCategory]
    }
    private struct Preparation {
        let sourceID: UUID
        let task: Task<Void, Never>
    }
    // Keep one revision per logical library, with an LRU and row budget. The
    // current oversized library is allowed in full; no catalog rows are dropped.
    private var cache: [String: Snapshot] = [:]
    private var pending: [String: Preparation] = [:]
    private var recent: [String] = []
    var cachedLibraryCount: Int { cache.count }
    var cachedEntryCount: Int { cache.values.reduce(0) { $0 + $1.entries.count } }
    func entries(reference: IPAStoreReference, source: AltStoreSource?) -> [IPAAppEntry] {
        snapshot(reference: reference, source: source)?.entries ?? []
    }
    func categories(reference: IPAStoreReference, source: AltStoreSource?) -> [IPAAppCategory] {
        snapshot(reference: reference, source: source)?.categories ?? []
    }
    func browsingCategories(reference: IPAStoreReference, source: AltStoreSource?) -> [IPAAppCategory] {
        snapshot(reference: reference, source: source)?.browsingCategories ?? []
    }
    func prepare(reference: IPAStoreReference, source: AltStoreSource) async {
        _ = snapshot(reference: reference, source: source)
        await pending[reference.id]?.task.value
        if let index = recent.firstIndex(of: reference.id) { recent.remove(at: index); recent.append(reference.id) }
    }
    private func snapshot(reference: IPAStoreReference, source: AltStoreSource?) -> Snapshot? {
        guard let source else { return nil }
        let key = reference.id
        if let value = cache[key], value.sourceID == source.id { return value }
        guard pending[key]?.sourceID != source.id else { return nil }
        pending[key]?.task.cancel()
        let task = Task {
            let preparation = Task.detached(priority: .userInitiated) { () -> Snapshot? in
                let entries = IPACatalogPresentation.entries([(reference, source.apps)])
                guard !Task.isCancelled else { return nil }
                return Snapshot(sourceID: source.id, entries: entries, categories: IPACatalogPresentation.libraryCategories(entries), browsingCategories: IPACatalogPresentation.categories(entries))
            }
            let value = await withTaskCancellationHandler { await preparation.value } onCancel: { preparation.cancel() }
            guard !Task.isCancelled, pending[key]?.sourceID == source.id, let value else { return }
            cache[key] = value; pending[key] = nil
            recent.removeAll { $0 == key }; recent.append(key)
            while recent.count > 1 && (cache.count > 16 || cachedEntryCount > 30_000) {
                cache.removeValue(forKey: recent.removeFirst())
            }
            revision += 1
        }
        pending[key] = Preparation(sourceID: source.id, task: task)
        return nil
    }
    func trimMemory() {
        for preparation in pending.values { preparation.task.cancel() }
        pending.removeAll(); cache.removeAll(); recent.removeAll()
        // Do not invalidate every hidden page during memory pressure. Existing
        // content stays visible; consumers prepare when next rendered.
    }
}

struct IPASearchDocument {
    let name: String
    let text: String
    static func normalized(_ text: String) -> String { text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current) }
    init(_ entry: IPAAppEntry) {
        name = Self.normalized(entry.app.name)
        text = Self.normalized(entry.variants.flatMap { [$0.app.name, $0.app.developerName ?? "", $0.app.subtitle ?? "", entry.category, $0.store.name] }.joined(separator: "\n"))
    }
    static func matches(_ query: String, documents: [Self]) -> [Int] {
        let term = normalized(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !term.isEmpty else { return [] }
        var prefix: [Int] = [], other: [Int] = []
        for (index, document) in documents.enumerated() {
            if index % 128 == 0 && Task.isCancelled { return [] }
            if document.text.contains(term) {
                if document.name.hasPrefix(term) { prefix.append(index) } else { other.append(index) }
            }
        }
        return prefix + other
    }
}

@MainActor final class IPAAllAppsIndex: ObservableObject {
    @Published private(set) var entries: [IPAAppEntry] = []
    @Published private(set) var revision = 0
    private var documents: [IPASearchDocument] = []
    private var byIdentifier: [String: IPAAppEntry] = [:]
    private var byLibrary: [String: [IPAAppEntry]] = [:]
    private var byCategory: [String: [IPAAppEntry]] = [:]
    func more(in library: String, excluding identifier: String, limit: Int = 15) -> [IPAAppEntry] {
        Array((byLibrary[library] ?? []).lazy.filter { $0.id != identifier }.prefix(limit)).map {
            IPAAppEntry(id: $0.id, variants: $0.variants.filter { $0.store.id == library })
        }
    }
    func similar(to entry: IPAAppEntry, excluding others: [IPAAppEntry], limit: Int = 15) -> [IPAAppEntry] {
        let excluded = Set(others.map(\.id) + [entry.id])
        return Array((byCategory[entry.category] ?? []).lazy.filter { !excluded.contains($0.id) }.prefix(limit))
    }
    private var signature: [String] = []
    private var generation = UUID()
    private var worker: Task<Void, Never>?
    func search(_ query: String) async -> [IPAAppEntry] {
        let snapshot = entries, prepared = documents, token = generation
        let task = Task.detached(priority: .userInitiated) {
            IPASearchDocument.matches(query, documents: prepared).map { snapshot[$0] }
        }
        let rows = await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
        guard !Task.isCancelled, generation == token else { return [] }
        return rows
    }
    func waitForRebuild() async { await worker?.value }
    func entry(identifier: String) -> IPAAppEntry? { byIdentifier[identifier.lowercased()] }
    func rebuild(subscribed: [AltStoreSourcesViewModel.SourceItem], discovered: [String: AltStoreSource]) {
        let libraries = IPACatalogPresentation.libraries(subscribed: subscribed, discovered: discovered)
        let next = libraries.map { $0.0.id + "|" + ($0.1?.id.uuidString ?? "") }
        guard next != signature else { return }
        signature = next; generation = UUID(); let token = generation
        worker?.cancel()
        worker = Task {
            // Coalesce independently arriving feeds. Catalog sorting is never on
            // the navigation transition's main-thread work.
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard !Task.isCancelled else { return }
            let preparation = Task.detached(priority: .userInitiated) { () -> ([IPAAppEntry], [IPASearchDocument], [String: IPAAppEntry], [String: [IPAAppEntry]], [String: [IPAAppEntry]]) in
                let rows = IPACatalogPresentation.entries(libraries.map { ($0.0, $0.1?.apps ?? []) })
                var identifiers: [String: IPAAppEntry] = [:], libraryRows: [String: [IPAAppEntry]] = [:], categories: [String: [IPAAppEntry]] = [:]
                for entry in rows {
                    if Task.isCancelled { return ([], [], [:], [:], [:]) }
                    categories[entry.category, default: []].append(entry)
                    identifiers[entry.id.lowercased()] = entry
                    for id in Set(entry.variants.map { $0.store.id }) { libraryRows[id, default: []].append(entry) }
                    for variant in entry.variants { identifiers[variant.app.bundleIdentifier.lowercased()] = entry }
                }
                return (rows, rows.map(IPASearchDocument.init), identifiers, libraryRows, categories)
            }
            let prepared = await withTaskCancellationHandler { await preparation.value } onCancel: { preparation.cancel() }
            let rows = prepared.0
            guard !Task.isCancelled, generation == token else { return }
            documents = prepared.1; byIdentifier = prepared.2; byLibrary = prepared.3; byCategory = prepared.4
            entries = rows; revision += 1
        }
    }
}
