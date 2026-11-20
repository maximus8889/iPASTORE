import SwiftUI
import UIKit
import ImageIO
import CryptoKit
import Foundation
import Darwin

// Each caller owns a subscription, not the shared operation. Leaving a row
// releases it immediately; only the last departure cancels the underlying work.
// Request IDs prevent a cancelled older completion from erasing a replacement.
actor IPASharedWork<Key: Hashable & Sendable, Value: Sendable> {
    private struct Job {
        let id: UUID
        let task: Task<Void, Never>
        var replies: [UUID: CheckedContinuation<Value?, Never>]
    }
    private var jobs: [Key: Job] = [:]
    func value(for key: Key, operation: @escaping @Sendable () async -> Value?) async -> Value? {
        let consumer = UUID()
        return await withTaskCancellationHandler {
            guard !Task.isCancelled else { return nil }
            return await withCheckedContinuation { reply in
                guard !Task.isCancelled else { reply.resume(returning: nil); return }
                if var job = jobs[key] {
                    job.replies[consumer] = reply; jobs[key] = job
                } else {
                    let id = UUID()
                    let task = Task.detached(priority: .userInitiated) {
                        let result = await operation()
                        await self.complete(key, id: id, result: result)
                    }
                    jobs[key] = Job(id: id, task: task, replies: [consumer: reply])
                }
            }
        } onCancel: { Task { await self.cancel(key, consumer: consumer) } }
    }
    private func complete(_ key: Key, id: UUID, result: Value?) {
        guard let job = jobs[key], job.id == id else { return }
        jobs[key] = nil
        for reply in job.replies.values { reply.resume(returning: result) }
    }
    private func cancel(_ key: Key, consumer: UUID) {
        guard var job = jobs[key], let reply = job.replies.removeValue(forKey: consumer) else { return }
        reply.resume(returning: nil)
        if job.replies.isEmpty { jobs[key] = nil; job.task.cancel() }
        else { jobs[key] = job }
    }
    func cancelAll() {
        let current = jobs; jobs.removeAll()
        for job in current.values {
            job.task.cancel()
            for reply in job.replies.values { reply.resume(returning: nil) }
        }
    }
    var pendingCount: Int { jobs.count }
    func consumerCount(for key: Key) -> Int { jobs[key]?.replies.count ?? 0 }
}

// A cancelled row waiting for a download slot must not occupy the queue until
// some unrelated slow publisher finishes. Active permits are returned by defer.
private actor IPAArtworkSlots {
    private var active = 0
    private var waiting: [(UUID, CheckedContinuation<Bool, Never>)] = []
    func acquire() async -> Bool {
        let id = UUID()
        return await withTaskCancellationHandler {
            guard !Task.isCancelled else { return false }
            if active < 6 { active += 1; return true }
            return await withCheckedContinuation { reply in
                if Task.isCancelled { reply.resume(returning: false) }
                else { waiting.append((id, reply)) }
            }
        } onCancel: { Task { await self.cancel(id) } }
    }
    private func cancel(_ id: UUID) {
        guard let index = waiting.firstIndex(where: { $0.0 == id }) else { return }
        waiting.remove(at: index).1.resume(returning: false)
    }
    func release() {
        if waiting.isEmpty { active -= 1 }
        else { waiting.removeFirst().1.resume(returning: true) }
    }
}

private final class IPAImageDownloadLimit: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if max(totalBytesWritten, totalBytesExpectedToWrite) > 12 * 1024 * 1024 { downloadTask.cancel() }
    }
}
fileprivate final class IPAArtworkBytes: NSObject, @unchecked Sendable {
    let data: Data
    let fromDisk: Bool
    let token = UUID()
    init(_ data: Data, fromDisk: Bool) { self.data = data; self.fromDisk = fromDisk }
}
actor IPAArtworkDownloads {
    static let shared = IPAArtworkDownloads()
    private let memory = NSCache<NSURL, IPAArtworkBytes>()
    private let work = IPASharedWork<URL, IPAArtworkBytes>()
    private let slots = IPAArtworkSlots()
    private var generation = 0
    private var diskReads = 0
    private let session: URLSession
    init() {
        memory.totalCostLimit = 8 * 1024 * 1024; memory.countLimit = 48
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil; configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = 8; configuration.timeoutIntervalForResource = 16
        configuration.httpMaximumConnectionsPerHost = 6
        session = URLSession(configuration: configuration, delegate: IPAImageDownloadLimit(), delegateQueue: nil)
    }
    func data(from url: URL) async -> Data? { await original(from: url).map(\.data) }
    fileprivate func original(from url: URL, disk: URL? = nil, forceNetwork: Bool = false) async -> IPAArtworkBytes? {
        guard !Task.isCancelled, ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        if !forceNetwork, let cached = memory.object(forKey: url as NSURL) { return cached }
        let epoch = generation, session = session, slots = slots
        return await work.value(for: url) {
            // A previous completion can populate the cache between the first
            // lookup and subscription on the work actor. Check again inside it.
            if let cached = await self.cachedOriginal(for: url, forceNetwork: forceNetwork) { return cached }
            let result: IPAArtworkBytes?
            if !forceNetwork, let disk,
               let values = try? disk.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
               let date = values.contentModificationDate, Date().timeIntervalSince(date) < 7 * 86400,
               let size = values.fileSize, size > 0, size <= 12 * 1024 * 1024,
               let data = try? Data(contentsOf: disk) {
                await self.recordDiskRead()
                result = IPAArtworkBytes(data, fromDisk: true)
            } else {
                guard await slots.acquire() else { return nil }
                if Task.isCancelled { await slots.release(); return nil }
                do {
                    let (file, response) = try await session.download(from: url)
                    defer { try? FileManager.default.removeItem(at: file) }
                    if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                       let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 12 * 1024 * 1024 {
                        result = IPAArtworkBytes(try Data(contentsOf: file), fromDisk: false)
                    } else { result = nil }
                } catch { result = nil }
                await slots.release()
            }
            guard !Task.isCancelled else { return nil }
            return await self.remember(result, for: url, epoch: epoch)
        }
    }
    fileprivate func cachedOriginal(for url: URL, forceNetwork: Bool) -> IPAArtworkBytes? {
        guard let cached = memory.object(forKey: url as NSURL), !forceNetwork || !cached.fromDisk else { return nil }
        return cached
    }
    private func recordDiskRead() { diskReads += 1 }
    private func remember(_ result: IPAArtworkBytes?, for url: URL, epoch: Int) -> IPAArtworkBytes? {
        guard epoch == generation else { return nil }
        if let result, result.data.count <= 2 * 1024 * 1024 { memory.setObject(result, forKey: url as NSURL, cost: result.data.count) }
        return result
    }
    var diskReadCount: Int { diskReads }
    func clearMemory() async {
        generation += 1; memory.removeAllObjects()
        await work.cancelAll()
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
// Cancellation also removes queued decodes, rather than merely discarding an
// already decoded bitmap. The reply lock makes completion/cancellation race safe.
private final class IPAArtworkDecodeOperation: Operation, @unchecked Sendable {
    private let data: Data
    private let pixels: Int
    private let replyLock = NSLock()
    private var reply: CheckedContinuation<UIImage?, Never>?
    init(data: Data, pixels: Int) { self.data = data; self.pixels = pixels }
    func install(_ reply: CheckedContinuation<UIImage?, Never>) {
        replyLock.lock()
        if isCancelled { replyLock.unlock(); reply.resume(returning: nil) }
        else { self.reply = reply; replyLock.unlock() }
    }
    private func finish(_ image: UIImage?) {
        replyLock.lock(); let reply = reply; self.reply = nil; replyLock.unlock()
        reply?.resume(returning: image)
    }
    override func cancel() { super.cancel(); finish(nil) }
    override func main() {
        guard !isCancelled else { finish(nil); return }
        let result: UIImage? = autoreleasepool {
            guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: pixels, kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { return nil }
            return UIImage(cgImage: image)
        }
        finish(isCancelled ? nil : result)
    }
}
private enum IPAArtworkDecoder {
    static let queue: OperationQueue = {
        let queue = OperationQueue(); queue.name = "app.ipastore.artwork.decode"
        queue.maxConcurrentOperationCount = 2; queue.qualityOfService = .userInitiated
        return queue
    }()
    static func thumbnail(_ data: Data, pixels: Int) async -> UIImage? {
        let operation = IPAArtworkDecodeOperation(data: data, pixels: pixels)
        return await withTaskCancellationHandler {
            guard !Task.isCancelled else { return nil }
            return await withCheckedContinuation { reply in
                operation.install(reply)
                if Task.isCancelled { operation.cancel() }
                queue.addOperation(operation)
            }
        } onCancel: { operation.cancel() }
    }
}

// Slow file writes and directory pruning cannot hold up decoded image delivery.
// Epochs reject writes queued before a memory trim or explicit cache clear.
private actor IPAArtworkDiskWriter {
    let directory: URL
    private var epoch = 0
    private var writes = 0
    private var stored: [URL: UUID] = [:]
    init(directory: URL) { self.directory = directory }
    func store(_ data: Data, at url: URL, epoch: Int, token: UUID = UUID()) {
        guard epoch >= self.epoch, !Task.isCancelled, stored[url] != token else { return }; self.epoch = epoch
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            if stored.count >= 240 { stored.removeAll(keepingCapacity: true) }
            stored[url] = token; writes += 1
            if writes % 16 == 0 || data.count > 2 * 1024 * 1024 { prune() }
        } catch { /* Artwork caching is best effort; decoded images remain usable. */ }
    }
    func advance(to epoch: Int, clear: Bool) {
        self.epoch = max(self.epoch, epoch)
        if clear { try? FileManager.default.removeItem(at: directory); writes = 0; stored.removeAll() }
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
    private let work = IPASharedWork<String, UIImage>()
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
        guard !clearing, !Task.isCancelled, ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        let pixels = min(1600, max(64, pixels)), key = IPAImageMemory.key(url, min(1600, max(64, pixels)))
        if let cached = IPAImageMemory.cache(for: pixels).object(forKey: key as NSString) { return cached }
        if let failed = failures[key], Date().timeIntervalSince(failed) < 60 { return nil }
        let epoch = generation
        return await work.value(for: key) { await self.load(url, pixels: pixels, key: key, epoch: epoch) }
    }
    private func load(_ url: URL, pixels: Int, key: String, epoch: Int) async -> UIImage? {
        if let cached = IPAImageMemory.cache(for: pixels).object(forKey: key as NSString) { return cached }
        let disk = directory.appendingPathComponent(Self.diskName(url.absoluteString, suffix: ".artwork"))
        let legacy = directory.appendingPathComponent(Self.diskName(key, suffix: ".png"))
        var result: UIImage?
        let downloads = IPAArtworkDownloads.shared
        var original = await downloads.cachedOriginal(for: url, forceNetwork: false)
        if original == nil,
           let values = try? disk.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
           let date = values.contentModificationDate, Date().timeIntervalSince(date) < 7 * 86400,
           let size = values.fileSize, size > 0, size <= 12 * 1024 * 1024 {
            original = await downloads.original(from: url, disk: disk)
        }
        if let original { result = await IPAArtworkDecoder.thumbnail(original.data, pixels: pixels) }
        // Prefer the current original over legacy thumbnails. Existing per-size
        // PNGs still avoid a network download when an original is unavailable.
        if result == nil, !Task.isCancelled,
           let values = try? legacy.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
           let date = values.contentModificationDate, Date().timeIntervalSince(date) < 7 * 86400,
           let size = values.fileSize, size > 0, size <= 12 * 1024 * 1024,
           let data = try? Data(contentsOf: legacy) { result = await IPAArtworkDecoder.thumbnail(data, pixels: pixels) }
        if result == nil, !Task.isCancelled, original == nil || original?.fromDisk == true {
            // A corrupt disk original must recover online. Malformed network
            // images are not requested twice and enter the normal retry delay.
            original = await downloads.original(from: url, disk: disk, forceNetwork: original?.fromDisk == true)
            if let original { result = await IPAArtworkDecoder.thumbnail(original.data, pixels: pixels) }
        }
        guard epoch == generation, !Task.isCancelled, !clearing else { return nil }
        if let result {
            failures[key] = nil
            if let original, !original.fromDisk {
                let writer = diskWriter
                Task(priority: .utility) { await writer.store(original.data, at: disk, epoch: epoch, token: original.token) }
            }
            let cost = result.cgImage.map { $0.bytesPerRow * $0.height } ?? Int(result.size.width * result.size.height * 4)
            IPAImageMemory.cache(for: pixels).setObject(result, forKey: key as NSString, cost: cost)
            if pixels <= 384 { IPAImageMemory.previews.setObject(result, forKey: url.absoluteString as NSString, cost: cost) }
        } else {
            if failures.count >= 256 { failures.removeAll(keepingCapacity: true) }
            failures[key] = Date()
        }
        return result
    }
    private static func diskName(_ key: String, suffix: String) -> String {
        SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined() + suffix
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
        IPAImageMemory.clear()
        await work.cancelAll()
        await diskWriter.advance(to: generation, clear: false)
        await IPAArtworkDownloads.shared.clearMemory()
    }
    func clearCachedArtwork() async {
        clearing = true; defer { clearing = false }
        generation += 1
        IPAImageMemory.clear()
        await work.cancelAll(); failures.removeAll()
        await diskWriter.advance(to: generation, clear: true)
        await IPAArtworkDownloads.shared.clearMemory()
    }

}

struct IPARemoteImage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let url: URL?
    var pixels: Int = 240
    var mode: ContentMode = .fill
    var fallbackAsset: String? = nil
    var fallbackSymbol = "app.dashed"
    var fallbackText: String? = nil
    var fallbackURLs: [URL] = []
    var showsPlaceholder = true
    var onFailure: (() -> Void)? = nil
    var onSize: ((CGSize) -> Void)? = nil
    private var candidates: [URL] {
        var seen = Set<URL>()
        return ([url].compactMap { $0 } + fallbackURLs).filter { seen.insert($0).inserted }
    }
    private var bundledFallback: String? {
        if let fallbackAsset { return fallbackAsset }
        if url?.host == "www.stremio.com", url?.path == "/website/stremio-logo-small.png" { return "Library-hub-stremio-official-pal" }
        return nil
    }
    @State private var loaded: UIImage?
    @State private var loadedKey: String?
    @State private var loadedURL: URL?
    @State private var loadedPixels: Int?
    @State private var visibleKey: String?
    private var key: String { candidates.map { IPAImageMemory.key($0, pixels) }.joined(separator: "|") }
    private var retainedImage: UIImage? {
        guard let loadedURL, candidates.contains(loadedURL), loadedPixels == pixels else { return nil }
        return loaded
    }
    private var cachedImage: UIImage? {
        for candidate in candidates.prefix(4) {
            if let image = IPAImageMemory.cache(for: pixels).object(forKey: IPAImageMemory.key(candidate, pixels) as NSString)
                ?? IPAImageMemory.previews.object(forKey: candidate.absoluteString as NSString) { return image }
        }
        return nil
    }
    var body: some View {
        let memoryImage = cachedImage
        Group {
            if let image = retainedImage ?? memoryImage {
                Image(uiImage: image).resizable().aspectRatio(contentMode: mode)
                    .opacity(visibleKey == key || (retainedImage != nil && visibleKey == loadedKey) || (retainedImage == nil && memoryImage != nil) ? 1 : 0)
                    .animation(.easeOut(duration: reduceMotion ? 0.1 : 0.2), value: visibleKey)
            } else if let bundledFallback, let image = UIImage(named: bundledFallback) {
                Image(uiImage: image).resizable().aspectRatio(contentMode: mode)
            } else if showsPlaceholder {
                ZStack {
                    Color(uiColor: .tertiarySystemFill)
                    if let fallbackText, let initial = fallbackText.first { Text(String(initial).uppercased()).font(.system(size: 30, weight: .semibold, design: .rounded)).foregroundStyle(.secondary) }
                    else { Image(systemName: fallbackSymbol).font(.title2).foregroundStyle(.secondary) }
                }
            } else { Color.clear }
        }
        .onDisappear {
            loaded = nil; loadedURL = nil; loadedPixels = nil; loadedKey = nil; visibleKey = nil
        }
        .task(id: key) {
            // Adding a supplemental fallback must not hide/reload an already
            // visible primary icon or banner.
            if loadedURL == candidates.first, loadedPixels == pixels, loaded != nil { return }
            let beganWithCachedImage = cachedImage != nil
            for candidate in candidates.prefix(4) {
                guard !Task.isCancelled else { return }
                if let result = await IPAImagePipeline.shared.image(candidate, pixels: pixels) {
                    guard !Task.isCancelled else { return }
                    // Size callbacks must not inherit the image's fade animation:
                    // otherwise the surrounding page slides as its image arrives.
                    var transaction = Transaction(animation: nil); transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        loaded = result; loadedKey = key; loadedURL = candidate; loadedPixels = pixels
                        if beganWithCachedImage { visibleKey = key }
                        onSize?(result.size)
                    }
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    visibleKey = key
                    return
                }
            }
            if bundledFallback.flatMap(UIImage.init(named:)) == nil { onFailure?() }
        }
    }
}

// Sample the icon's border rather than its central glyph to match its background.
enum IPAIconPalette {
    static func colors(_ image: UIImage?) -> [Color] {
        guard let cgImage = image?.cgImage else { return [Color(white: 0.24), Color(white: 0.10)] }
        var bytes = [UInt8](repeating: 0, count: 16 * 16 * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: 16, height: 16, bitsPerComponent: 8, bytesPerRow: 64, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 16, height: 16)); return true
        }
        guard drawn else { return [Color(white: 0.24), Color(white: 0.10)] }
        func average(_ upper: Bool) -> Color {
            var r = 0.0, g = 0.0, b = 0.0, count = 0.0
            for y in (upper ? 0..<8 : 8..<16) { for x in 0..<16 where x < 3 || x > 12 || y < 3 || y > 12 {
                let i = (y * 16 + x) * 4
                guard bytes[i+3] > 200 else { continue }
                r += Double(bytes[i]); g += Double(bytes[i+1]); b += Double(bytes[i+2]); count += 1
            } }
            guard count > 0 else { return Color(white: 0.16) }
            let divisor = count * 255
            // Keep the original hue while ensuring readable white editorial text.
            return Color(red: r/divisor * 0.62, green: g/divisor * 0.62, blue: b/divisor * 0.62)
        }
        return [average(true), average(false)]
    }
}


struct IPAArtworkStorageView: View {
    @State private var bytes: Int64 = 0
    @State private var clearing = false
    var body: some View {
        Form {
            Section {
                LabeledContent("Cached Artwork", value: ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                Button {
                    clearing = true
                    Task {
                        await IPAImagePipeline.shared.clearCachedArtwork()
                        bytes = await IPAImagePipeline.shared.cachedArtworkBytes(); clearing = false
                    }
                } label: {
                    HStack { Label("Clear Artwork Cache", systemImage: "eraser"); Spacer(); if clearing { ProgressView() } }
                }.disabled(clearing)
            } footer: { Text("Temporary icons and previews can be downloaded again. Your installed apps, app data, libraries and signing files are kept.") }
        }.navigationTitle("Artwork Cache").navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden).background(IPAStyle.canvas)
            .task { bytes = await IPAImagePipeline.shared.cachedArtworkBytes() }
    }
}

// Opt-in production-pipeline exercise using local, synthetic artwork. Does not
// contact publishers, alter libraries, or touch guest app data.
enum IPAArtworkPerformanceChecks {
    @MainActor static func run() async {
        let reportURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("IPAPerformanceChecks.json")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("IPAArtworkCheck-" + UUID().uuidString)
        var report: [String: Any] = ["build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"]
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 768, height: 768))
            let data = renderer.pngData { context in
                UIColor.systemIndigo.setFill(); context.fill(CGRect(x: 0, y: 0, width: 768, height: 768))
                UIColor.systemTeal.setFill(); context.fill(CGRect(x: 70, y: 70, width: 600, height: 600))
            }
            let token = UUID().uuidString
            let urls = (0..<16).map { URL(string: "https://artwork.invalid/\(token)/\($0).png")! }
            for url in urls {
                let name = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined() + ".artwork"
                try data.write(to: directory.appendingPathComponent(name))
            }
            let pipeline = IPAImagePipeline(cacheDirectory: directory)
            var cpuBefore = rusage(); getrusage(RUSAGE_SELF, &cpuBefore)
            let readsBefore = await IPAArtworkDownloads.shared.diskReadCount
            let began = CACurrentMediaTime()
            let samples = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
                for number in 0..<128 {
                    group.addTask {
                        let pixels = [96, 192, 384, 768][number / 16 % 4]
                        let image = await pipeline.image(urls[number % 16], pixels: pixels)
                        return image?.cgImage.map { $0.width <= pixels && $0.height <= pixels } ?? false
                    }
                }
                var values: [Bool] = []; for await value in group { values.append(value) }; return values
            }
            guard samples.count == 128 && samples.allSatisfy({ $0 }) else { throw CocoaError(.fileReadCorruptFile) }
            report["local_artwork_128_requests_ms"] = (CACurrentMediaTime() - began) * 1000
            var cpuAfter = rusage(); getrusage(RUSAGE_SELF, &cpuAfter)
            func milliseconds(_ usage: rusage) -> Double {
                Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) * 1000 + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1000
            }
            report["process_cpu_ms_during_artwork_check"] = milliseconds(cpuAfter) - milliseconds(cpuBefore)
            let diskReads = await IPAArtworkDownloads.shared.diskReadCount - readsBefore
            report["original_disk_reads_for_128_requests"] = diskReads
            guard diskReads == 16 else { throw CocoaError(.fileReadUnknown) }
            report["decode_concurrency_limit"] = IPAArtworkDecoder.queue.maxConcurrentOperationCount
            guard urls.allSatisfy({ IPAImageMemory.cache(for: 192).object(forKey: IPAImageMemory.key($0, 192) as NSString) != nil }) else { throw CocoaError(.fileReadUnknown) }
            report["icons_retained_after_large_artwork"] = "PASS (16)"
            let warm = CACurrentMediaTime()
            for url in urls { _ = await pipeline.image(url, pixels: 192) }
            report["warm_artwork_16_requests_ms"] = (CACurrentMediaTime() - warm) * 1000
            let isolation = IPAInstallCoordinator.verifyProgressIsolation()
            report["progress_publications"] = isolation
            guard isolation["store_updates"] == 0 && isolation["progress_updates"] == 400 else { throw CocoaError(.validationMissingMandatoryProperty) }
            let writerDirectory = directory.appendingPathComponent("epoch-check")
            let writer = IPAArtworkDiskWriter(directory: writerDirectory)
            let target = writerDirectory.appendingPathComponent("sample.artwork")
            await writer.advance(to: 1, clear: true)
            await writer.store(data, at: target, epoch: 0)
            guard !FileManager.default.fileExists(atPath: target.path) else { throw CocoaError(.fileWriteUnknown) }
            await writer.store(data, at: target, epoch: 1)
            guard try Data(contentsOf: target) == data else { throw CocoaError(.fileReadCorruptFile) }
            report["stale_artwork_write_rejected"] = "PASS"
            await pipeline.clearCachedArtwork()
            guard !FileManager.default.fileExists(atPath: directory.path) else { throw CocoaError(.fileWriteUnknown) }
            report["cache_clear"] = "PASS"
            report["status"] = "PASS"
        } catch { report["status"] = "FAIL"; report["reason"] = error.localizedDescription }
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: reportURL, options: .atomic) }
    }
}
