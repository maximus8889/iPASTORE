import Foundation
import Combine

struct IPAActivityRecord: Codable, Identifiable, Hashable {
    var id: String { identifier.lowercased() + "|" + (libraryURL?.absoluteString ?? "local") }
    let identifier: String
    let name: String
    let iconURL: URL?
    let libraryURL: URL?
    let libraryName: String?
    let version: String?
    let date: Date
}

// Encode and persist complete snapshots off the navigation actor. Revisions
// prevent a cancelled older write from resurrecting cleared history.
private actor IPAHistoryPersistence {
    private var revisions: [String: Int] = [:]
    func store(_ records: [IPAActivityRecord], key: String, revision: Int, defaults: UserDefaults) {
        guard !Task.isCancelled, revision >= (revisions[key] ?? 0), let data = try? JSONEncoder().encode(records) else { return }
        revisions[key] = revision
        defaults.set(data, forKey: key)
    }
}

@MainActor final class IPAActivityHistory: ObservableObject {
    static let shared = IPAActivityHistory()
    @Published private(set) var recent: [IPAActivityRecord]
    @Published private(set) var downloads: [IPAActivityRecord]
    private let defaults: UserDefaults
    private let persistence = IPAHistoryPersistence()
    private var recentWrite: Task<Void, Never>?
    private var downloadWrite: Task<Void, Never>?
    private var revision = 0
    private var downloadedIdentifiers = Set<String>()
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        func read(_ key: String) -> [IPAActivityRecord] {
            guard let data = defaults.data(forKey: key), let records = try? JSONDecoder().decode([IPAActivityRecord].self, from: data) else { return [] }
            var seen = Set<String>()
            return records.sorted { $0.date > $1.date }.filter { seen.insert($0.id).inserted }
        }
        recent = Array(read("IPARecentApps.v1").prefix(300))
        downloads = Array(read("IPADownloadHistory.v1").prefix(2000))
        downloadedIdentifiers = Set(downloads.map { $0.identifier.lowercased() })
    }
    func viewed(_ entry: IPAAppEntry) {
        let value = record(entry.primary)
        var updated = recent
        updated.removeAll { $0.id == value.id }; updated.insert(value, at: 0)
        recent = Array(updated.prefix(300)); persist(writeRecent: true)
    }
    func downloaded(_ variant: IPAAppVariant) { saveDownload(record(variant)) }
    func imported(identifier: String, name: String, version: String?) {
        saveDownload(.init(identifier: identifier, name: name, iconURL: nil, libraryURL: nil, libraryName: nil, version: version, date: Date()))
    }
    func wasDownloaded(_ identifier: String) -> Bool { downloadedIdentifiers.contains(identifier.lowercased()) }
    func clearRecent() { recent = []; persist(writeRecent: true) }
    func remove(_ value: IPAActivityRecord, downloaded: Bool) {
        if downloaded {
            downloads.removeAll { $0.id == value.id }
            downloadedIdentifiers = Set(downloads.map { $0.identifier.lowercased() })
            persist(writeDownloads: true)
        } else { recent.removeAll { $0.id == value.id }; persist(writeRecent: true) }
    }
    private func record(_ variant: IPAAppVariant) -> IPAActivityRecord {
        .init(identifier: variant.app.bundleIdentifier, name: variant.app.name, iconURL: variant.app.iconURL, libraryURL: variant.store.url, libraryName: variant.store.name, version: variant.app.latestVersion?.version, date: Date())
    }
    private func saveDownload(_ value: IPAActivityRecord) {
        var updated = downloads
        updated.removeAll { $0.id == value.id }; updated.insert(value, at: 0)
        downloads = Array(updated.prefix(2000))
        downloadedIdentifiers = Set(downloads.map { $0.identifier.lowercased() })
        persist(writeDownloads: true)
    }
    func flush() async {
        // Foreground-to-background and tests can wait for the latest snapshots.
        let recent = recentWrite, downloads = downloadWrite
        await recent?.value; await downloads?.value
    }
    private func persist(writeRecent: Bool = false, writeDownloads: Bool = false) {
        revision += 1
        let revision = revision, persistence = persistence, defaults = defaults
        if writeRecent {
            let snapshot = recent
            recentWrite?.cancel()
            recentWrite = Task.detached(priority: .utility) {
                do { try await Task.sleep(nanoseconds: 120_000_000); try Task.checkCancellation() }
                catch { return }
                await persistence.store(snapshot, key: "IPARecentApps.v1", revision: revision, defaults: defaults)
            }
        }
        if writeDownloads {
            let snapshot = downloads
            downloadWrite?.cancel()
            downloadWrite = Task.detached(priority: .utility) {
                await persistence.store(snapshot, key: "IPADownloadHistory.v1", revision: revision, defaults: defaults)
            }
        }
    }
}
