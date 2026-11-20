import Foundation
import CryptoKit

// Public App Store metadata is supplemental. Exact bundle identity is required;
// names, categories and similar artwork never establish an app match.
struct IPAProductMetadata: Codable, Equatable, Sendable {
    let bundleIdentifier: String
    let icon: URL?
    let screenshots: [URL]
    let rating: Double?
    let ratingCount: Int?
    let ageRating: String?
    let category: String?
    let languages: [String]
    let listing: URL?
    static func decode(_ data: Data, matching identifier: String) -> Self? {
        guard data.count <= 2 * 1024 * 1024,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = root["results"] as? [[String: Any]],
              let item = results.first(where: { ($0["bundleId"] as? String) == identifier && ($0["kind"] as? String) == "software" }) else { return nil }
        func secure(_ value: Any?) -> URL? {
            guard let text = value as? String, let url = URL(string: text), url.scheme == "https", url.host != nil, url.user == nil, url.password == nil else { return nil }
            return url
        }
        let rating = (item["averageUserRating"] as? NSNumber)?.doubleValue
        let count = (item["userRatingCount"] as? NSNumber)?.intValue
        return .init(bundleIdentifier: identifier, icon: secure(item["artworkUrl512"] ?? item["artworkUrl100"]),
                     screenshots: ((item["screenshotUrls"] as? [String]) ?? []).prefix(12).compactMap { secure($0) },
                     rating: rating.flatMap { $0.isFinite && (0...5).contains($0) ? $0 : nil },
                     ratingCount: count.flatMap { $0 >= 0 ? $0 : nil }, ageRating: item["contentAdvisoryRating"] as? String,
                     category: item["primaryGenreName"] as? String, languages: Array(((item["languageCodesISO2A"] as? [String]) ?? []).prefix(100)),
                     listing: secure(item["trackViewUrl"]))
    }
}

// A shared bounded transport avoids constructing a connection pool for each page.
private final class IPAMetadataDownloadLimit: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if max(totalBytesWritten, totalBytesExpectedToWrite) > 2 * 1024 * 1024 { downloadTask.cancel() }
    }
}

actor IPAProductMetadataResolver {
    static let shared = IPAProductMetadataResolver()
    typealias Lookup = @Sendable (String) async throws -> IPAProductMetadata?
    private struct Cached: Codable { let date: Date; let metadata: IPAProductMetadata? }
    private struct Pending {
        let id: UUID
        let task: Task<IPAProductMetadata?, Error>
        var consumers: Set<UUID>
    }
    private var cache: [String: Cached] = [:]
    private var retryAt: [String: Date] = [:]
    private var pending: [String: Pending] = [:]
    private var nextRequest = Date.distantPast
    private let directory: URL
    private let lookup: Lookup
    private let interval: TimeInterval
    private let retryInterval: TimeInterval
    private var writes = 0
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil; configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = 12; configuration.timeoutIntervalForResource = 20
        configuration.httpMaximumConnectionsPerHost = 2
        return URLSession(configuration: configuration, delegate: IPAMetadataDownloadLimit(), delegateQueue: nil)
    }()
    init(cacheDirectory: URL? = nil, minimumRequestInterval: TimeInterval = 3.1, retryInterval: TimeInterval = 60, lookup: Lookup? = nil) {
        directory = cacheDirectory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("iPAStoreListingMetadata", isDirectory: true)
        self.interval = max(0, minimumRequestInterval); self.retryInterval = max(0, retryInterval)
        self.lookup = lookup ?? { identifier in
            var components = URLComponents(string: "https://itunes.apple.com/lookup")!
            components.queryItems = [.init(name: "bundleId", value: identifier), .init(name: "entity", value: "software"), .init(name: "limit", value: "1")]
            return try await Self.fetch(from: components.url!, matching: identifier)
        }
    }
    static func fetch(from url: URL, matching identifier: String) async throws -> IPAProductMetadata? {
        let (file, response) = try await session.download(from: url)
        defer { try? FileManager.default.removeItem(at: file) }
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        guard let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 2 * 1024 * 1024 else { throw URLError(.dataLengthExceedsMaximum) }
        let data = try Data(contentsOf: file)
        if let metadata = IPAProductMetadata.decode(data, matching: identifier) { return metadata }
        // Only a valid empty result is a missing listing. Server failures and
        // malformed/mismatched replies must not hide artwork for a whole day.
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any], let results = root["results"] as? [Any], results.isEmpty else { throw URLError(.cannotParseResponse) }
        return nil
    }
    private func waitForSlot() async throws {
        while true {
            try Task.checkCancellation()
            let delay = nextRequest.timeIntervalSinceNow
            if delay <= 0 { nextRequest = Date().addingTimeInterval(interval); return }
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }
    private func cancelConsumer(_ consumer: UUID, identifier: String, request: UUID) {
        guard var work = pending[identifier], work.id == request else { return }
        work.consumers.remove(consumer)
        if work.consumers.isEmpty { work.task.cancel(); pending[identifier] = nil }
        else { pending[identifier] = work }
    }
    func resolve(_ identifier: String) async -> IPAProductMetadata? {
        guard identifier.count <= 255, identifier.contains("."), identifier.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_").contains($0) }) else { return nil }
        let file = directory.appendingPathComponent(SHA256.hash(data: Data(identifier.utf8)).map { String(format: "%02x", $0) }.joined() + ".json")
        if cache[identifier] == nil, let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 2 * 1024 * 1024,
           let data = try? Data(contentsOf: file), let saved = try? JSONDecoder().decode(Cached.self, from: data),
           saved.metadata == nil || saved.metadata?.bundleIdentifier == identifier { remember(saved, for: identifier) }
        let stale = cache[identifier]?.metadata
        if let saved = cache[identifier], Date().timeIntervalSince(saved.date) < (saved.metadata == nil ? 86400 : 7 * 86400) { return saved.metadata }
        guard !Task.isCancelled else { return stale }
        if retryAt[identifier].map({ $0 > Date() }) == true { return stale }
        let consumer = UUID()
        let work: Pending
        if var existing = pending[identifier] {
            existing.consumers.insert(consumer); pending[identifier] = existing; work = existing
        } else {
            guard pending.count < 12 else { return stale }
            let lookup = lookup
            let task = Task { () throws -> IPAProductMetadata? in
                try await self.waitForSlot()
                try Task.checkCancellation()
                return try await lookup(identifier)
            }
            work = Pending(id: UUID(), task: task, consumers: [consumer]); pending[identifier] = work
        }
        let outcome: Result<IPAProductMetadata?, Error> = await withTaskCancellationHandler {
            do { return .success(try await work.task.value) } catch { return .failure(error) }
        } onCancel: { Task { await self.cancelConsumer(consumer, identifier: identifier, request: work.id) } }
        if Task.isCancelled { cancelConsumer(consumer, identifier: identifier, request: work.id) }
        if pending[identifier]?.id == work.id {
            pending[identifier] = nil
            switch outcome {
            case .success(let result):
                let saved = Cached(date: Date(), metadata: result)
                remember(saved, for: identifier); retryAt[identifier] = nil
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                if let data = try? JSONEncoder().encode(saved) { try? data.write(to: file, options: [.atomic]) }
                writes += 1
                if writes % 16 == 0 { prune() }
            case .failure:
                if !work.task.isCancelled {
                    if retryAt.count >= 128 { retryAt = retryAt.filter { $0.value > Date() } }
                    if retryAt.count >= 128, let oldest = retryAt.min(by: { $0.value < $1.value })?.key { retryAt[oldest] = nil }
                    retryAt[identifier] = Date().addingTimeInterval(retryInterval)
                }
            }
        }
        guard !Task.isCancelled else { return nil }
        switch outcome { case .success(let result): return result; case .failure: return stale }
    }
    private func remember(_ saved: Cached, for identifier: String) {
        cache[identifier] = saved
        if cache.count > 128, let oldest = cache.min(by: { $0.value.date < $1.value.date })?.key { cache[oldest] = nil }
    }
    private func prune() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let dated = files.map { ($0, (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) }
        for item in dated.sorted(by: { $0.1 > $1.1 }).dropFirst(128) { try? FileManager.default.removeItem(at: item.0) }
    }
}
