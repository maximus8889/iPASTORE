import Foundation
import CryptoKit

// Startup is a silent black cover. Recovery controls belong to an actual
// failure or unsupported rotation, never the ordinary launch path.
enum IPAAppPresentationPolicy: Equatable {
    case starting, playing, rotationRequired, failed
    static func mode(activated: Bool, layoutMatches: Bool, failed: Bool) -> Self {
        if failed { return .failed }
        if !activated { return .starting }
        return layoutMatches ? .playing : .rotationRequired
    }
}

// State belongs to one presentation request. Stale completions must not remove
// a newer launch cover or allow two apps to present at once.
struct IPAGuestLaunchTransition {
    private(set) var requestID: UUID?
    private(set) var coversStorefront = false
    mutating func begin(_ id: UUID) -> Bool {
        guard requestID == nil else { return false }
        requestID = id; coversStorefront = true
        return true
    }
    mutating func beginReturn(_ id: UUID) -> Bool {
        guard requestID == nil || requestID == id else { return false }
        requestID = id; coversStorefront = true
        return true
    }
    mutating func didPresent(_ id: UUID) {
        guard requestID == id else { return }
        requestID = nil; coversStorefront = false
    }
    mutating func cancel(_ id: UUID? = nil) {
        guard id == nil || requestID == id else { return }
        requestID = nil; coversStorefront = false
    }
}

// Mode selection changes the next installation destination, never whether an
// already-installed app is visible. Imported certificates can run containers.
enum IPAInstalledModePolicy {
    static func needsFreeMode(selectedMode: String?, importedCertificate: Bool, certificateOrigin: String?) -> Bool {
        selectedMode == "independent" && !(importedCertificate && certificateOrigin == "file")
    }
}

enum IPANativeOriginalCache {
    static func url(identifier: String, directory: URL? = nil) -> URL {
        let digest = SHA256.hash(data: Data(identifier.utf8)).map { String(format: "%02x", $0) }.joined()
        return (directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("OriginalIPAs", isDirectory: true)).appendingPathComponent(digest + ".ipa")
    }
    static func available(identifier: String) -> URL? {
        let file = url(identifier: identifier); return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }
    static func retain(_ source: URL, identifier: String, directory cacheDirectory: URL? = nil, budget: Int64 = 1024 * 1024 * 1024) {
        let fm = FileManager.default, target = url(identifier: identifier, directory: cacheDirectory), directory = url(identifier: identifier, directory: cacheDirectory).deletingLastPathComponent()
        guard let attributes = try? fm.attributesOfItem(atPath: source.path), let size = attributes[.size] as? NSNumber, size.int64Value > 0, size.int64Value < budget / 2 else { return }
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            let files = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]).filter { $0.pathExtension == "ipa" }
            var total = files.reduce(size.int64Value) { $0 + Int64((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
            for file in files.sorted(by: { ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) < ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) }) where total > budget {
                let oldSize = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                try fm.removeItem(at: file); total -= Int64(oldSize)
            }
            let temporary = directory.appendingPathComponent(UUID().uuidString + ".pending")
            defer { try? fm.removeItem(at: temporary) }
            try fm.copyItem(at: source, to: temporary)
            if fm.fileExists(atPath: target.path) { _ = try fm.replaceItemAt(target, withItemAt: temporary) }
            else { try fm.moveItem(at: temporary, to: target) }
        } catch { /* A cache failure never invalidates the completed install. */ }
    }
}
