// Frozen build 148 artwork path, used only by the paired backlog benchmark.
import SwiftUI
import UIKit
import ImageIO
import CryptoKit

// Share connection pools and original bytes across icon/hero sizes. Decoding
// and disk access stay outside the main actor; both bytes and concurrency are bounded.
private final class IPAImageDownloadLimit: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if max(totalBytesWritten, totalBytesExpectedToWrite) > 12 * 1024 * 1024 { downloadTask.cancel() }
    }
}
actor IPAArtworkDownloads {
    static let shared = IPAArtworkDownloads()
    private let memory = NSCache<NSURL, NSData>()
    private var pending: [URL: Task<Data?, Never>] = [:]
    private var active = 0
    private var generation = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private let session: URLSession
    init() {
        memory.totalCostLimit = 8 * 1024 * 1024; memory.countLimit = 48
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil; configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = 8; configuration.timeoutIntervalForResource = 16
        configuration.httpMaximumConnectionsPerHost = 6
        session = URLSession(configuration: configuration, delegate: IPAImageDownloadLimit(), delegateQueue: nil)
    }
    private func acquire() async {
        if active < 6 { active += 1; return }
        await withCheckedContinuation { waiting.append($0) }
    }
    private func release() {
        if waiting.isEmpty { active -= 1 }
        else { waiting.removeFirst().resume() }
    }
    func data(from url: URL) async -> Data? {
        guard ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        if let cached = memory.object(forKey: url as NSURL) { return cached as Data }
        if let work = pending[url] {
            let epoch = generation, value = await work.value
            return epoch == generation && !work.isCancelled ? value : nil
        }
        let generation = generation
        let session = session
        let work = Task.detached(priority: .userInitiated) { () -> Data? in
            await self.acquire()
            if Task.isCancelled { await self.release(); return nil }
            let result: Data?
            do {
                let (file, response) = try await session.download(from: url)
                defer { try? FileManager.default.removeItem(at: file) }
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                   let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 12 * 1024 * 1024 {
                    result = try Data(contentsOf: file)
                } else { result = nil }
            } catch { result = nil }
            await self.release()
            return result
        }
        pending[url] = work
        let result = await work.value
        guard generation == self.generation, !work.isCancelled else { return nil }
        pending[url] = nil
        // Large hero images don't evict all of the small reusable icon bytes.
        if let result, result.count <= 2 * 1024 * 1024 { memory.setObject(result as NSData, forKey: url as NSURL, cost: result.count) }
        return result
    }
    func clearMemory() {
        generation += 1
        for work in pending.values { work.cancel() }
        pending.removeAll(); memory.removeAllObjects()
    }
}

private enum IPAImageMemory {
    private static let small: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>(); cache.totalCostLimit = 20 * 1024 * 1024; cache.countLimit = 180; return cache
    }()
    private static let large: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>(); cache.totalCostLimit = 20 * 1024 * 1024; cache.countLimit = 24; return cache
    }()
    static func cache(for pixels: Int) -> NSCache<NSString, UIImage> { pixels <= 384 ? small : large }
    static func clear() { small.removeAllObjects(); large.removeAllObjects(); previews.removeAllObjects() }
    static let previews: NSCache<NSString, UIImage> = { let cache = NSCache<NSString, UIImage>(); cache.totalCostLimit = 12 * 1024 * 1024; return cache }()
    static func key(_ url: URL, _ pixels: Int) -> String { url.absoluteString + "|" + String(pixels) }
}
// Limit CPU-heavy image decoding independently of the network connection pool.
// A cached library can expose many images at once without spawning a decoder
// for every visible cell on the cooperative executor.
private enum IPAArtworkDecoder {
    static let queue: OperationQueue = {
        let queue = OperationQueue(); queue.name = "app.ipastore.artwork.decode"
        queue.maxConcurrentOperationCount = 2; queue.qualityOfService = .userInitiated
        return queue
    }()
    static func thumbnail(_ data: Data, pixels: Int) async -> UIImage? {
        guard !Task.isCancelled else { return nil }
        let image: UIImage? = await withCheckedContinuation { reply in
            queue.addOperation {
                let result: UIImage? = autoreleasepool {
                    guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
                          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: pixels, kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { return nil }
                    return UIImage(cgImage: image)
                }
                reply.resume(returning: result)
            }
        }
        return Task.isCancelled ? nil : image
    }
}

// Slow file writes and directory pruning cannot hold up decoded image delivery.
// Epochs reject writes queued before a memory trim or explicit cache clear.
private actor IPAArtworkDiskWriter {
    let directory: URL
    private var epoch = 0
    private var writes = 0
    init(directory: URL) { self.directory = directory }
    func store(_ data: Data, at url: URL, epoch: Int) {
        guard epoch >= self.epoch, !Task.isCancelled else { return }; self.epoch = epoch
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            writes += 1
            if writes % 16 == 0 || data.count > 2 * 1024 * 1024 { prune() }
        } catch { /* Artwork caching is best effort; decoded images remain usable. */ }
    }
    func advance(to epoch: Int, clear: Bool) {
        self.epoch = max(self.epoch, epoch)
        if clear { try? FileManager.default.removeItem(at: directory); writes = 0 }
    }
    private func prune() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) else { return }
        let dated = files.compactMap { url -> (URL, Date, Int)? in
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) else { return nil }
            return (url, values.contentModificationDate ?? .distantPast, values.fileSize ?? 0)
        }.sorted { $0.1 > $1.1 }
        var total = 0
        for (index, entry) in dated.enumerated() {
            total += entry.2
            if index >= 240 || total > 80 * 1024 * 1024 { try? FileManager.default.removeItem(at: entry.0) }
        }
    }
}

actor IPAImagePipeline {
    static let shared = IPAImagePipeline()
    private var pending: [String: Task<(UIImage?, Data?), Never>] = [:]
    private let directory: URL
    private let diskWriter: IPAArtworkDiskWriter
    private var failures: [String: Date] = [:]
    private var generation = 0
    private var clearing = false
    init(cacheDirectory: URL? = nil) {
        directory = cacheDirectory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("IPAStoreArtwork", isDirectory: true)
        diskWriter = IPAArtworkDiskWriter(directory: directory)
    }
    func image(_ url: URL, pixels: Int) async -> UIImage? {
        guard !clearing, ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        let pixels = min(1600, max(64, pixels)), key = IPAImageMemory.key(url, min(1600, max(64, pixels)))
        if let cached = IPAImageMemory.cache(for: pixels).object(forKey: key as NSString) { return cached }
        if let task = pending[key] {
            let epoch = generation, image = await task.value.0
            return epoch == generation && !task.isCancelled ? image : nil
        }
        if let failed = failures[key], Date().timeIntervalSince(failed) < 60 { return nil }
        let disk = directory.appendingPathComponent(SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined() + ".artwork")
        let legacy = directory.appendingPathComponent(SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined() + ".png")
        let generation = generation
        let task = Task.detached(priority: .userInitiated) { () -> (UIImage?, Data?) in
            for file in [disk, legacy] {
                guard !Task.isCancelled else { return (nil, nil) }
                if let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                   let date = values.contentModificationDate, Date().timeIntervalSince(date) < 7 * 86400,
                   let size = values.fileSize, size <= 12 * 1024 * 1024,
                   let data = try? Data(contentsOf: file), let cached = await IPAArtworkDecoder.thumbnail(data, pixels: pixels) { return (cached, nil) }
            }
            guard let data = await IPAArtworkDownloads.shared.data(from: url),
                  !Task.isCancelled, let result = await IPAArtworkDecoder.thumbnail(data, pixels: pixels) else { return (nil, nil) }
            return (result, data)
        }
        pending[key] = task
        let (result, original) = await task.value
        guard generation == self.generation, !task.isCancelled else { return nil }
        pending[key] = nil
        if result == nil {
            if failures.count >= 256 { failures.removeAll(keepingCapacity: true) }
            failures[key] = Date()
        } else { failures[key] = nil }
        if let result {
            // Keep the publisher's compressed original once per URL. Encoding a
            // new PNG for every icon/hero size wastes CPU, storage and battery.
            if let original {
                let writer = diskWriter
                Task(priority: .utility) { await writer.store(original, at: disk, epoch: generation) }
            }
            IPAImageMemory.cache(for: pixels).setObject(result, forKey: key as NSString, cost: Int(result.size.width * result.size.height * 4))
            if pixels <= 384 { IPAImageMemory.previews.setObject(result, forKey: url.absoluteString as NSString, cost: Int(result.size.width * result.size.height * 4)) }
        }
        return result
    }
    func cachedArtworkBytes() async -> Int64 {
        let directory = directory
        return await Task.detached(priority: .utility) {
            let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
            return files.reduce(Int64(0)) { $0 + Int64((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        }.value
    }
    func trimMemory() async {
        // Keep compressed disk originals. Only discard reconstructible RAM and
        // in-flight artwork while the host is suspended or under pressure.
        generation += 1
        for work in pending.values { work.cancel() }
        pending.removeAll()
        IPAImageMemory.clear()
        await diskWriter.advance(to: generation, clear: false)
        await IPAArtworkDownloads.shared.clearMemory()
    }
    func clearCachedArtwork() async {
        clearing = true; defer { clearing = false }
        generation += 1
        for work in pending.values { work.cancel() }
        pending.removeAll()
        IPAImageMemory.clear(); failures.removeAll()
        await diskWriter.advance(to: generation, clear: true)
        await IPAArtworkDownloads.shared.clearMemory()
    }

}

