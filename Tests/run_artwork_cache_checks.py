"""Run actual artwork disk/decode logic using AppKit's image wrapper on macOS."""
from pathlib import Path
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
import json, subprocess, threading, time

root = Path(__file__).resolve().parents[1]
scratch = root / '.build/ArtworkCacheChecks'
scratch.mkdir(parents=True, exist_ok=True)
payload = (root / 'Resources/Assets.xcassets/AppIcon.appiconset/IPAStore-Black.png').read_bytes()
counts = {}
lock = threading.Lock()
class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    def log_message(self, *args): pass
    def do_GET(self):
        with lock: counts[self.path] = counts.get(self.path, 0) + 1
        if self.path in ['/slow', '/shared', '/abandon']: time.sleep(.25)
        self.send_response(200); self.send_header('Content-Length', str(len(payload))); self.end_headers()
        try: self.wfile.write(payload)
        except (BrokenPipeError, ConnectionResetError): pass

server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
source = (root / 'LiveContainerSwiftUI/Views/IPAImagePipeline.swift').read_text().split('struct IPARemoteImage: View')[0]
source = source.replace('import SwiftUI\n', '').replace('import UIKit\n', 'import Foundation\nimport AppKit\n')
source += '''\ntypealias UIImage = NSImage
extension NSImage {
    var cgImage: CGImage? { cgImage(forProposedRect: nil, context: nil, hints: nil) }
    convenience init(cgImage: CGImage) {
        self.init(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height))
    }
}
'''
source += r'''
func verifyQueuedDecodeCancellation(_ data: Data) async -> Bool {
    IPAArtworkDecoder.queue.isSuspended = true
    defer { IPAArtworkDecoder.queue.isSuspended = false }
    let task = Task { await IPAArtworkDecoder.thumbnail(data, pixels: 128) }
    for _ in 0..<100 where IPAArtworkDecoder.queue.operationCount == 0 { try? await Task.sleep(for: .milliseconds(1)) }
    task.cancel()
    return await task.value == nil
}
'''
(scratch / 'Artwork.swift').write_text(source)
(scratch / 'Runner.swift').write_text(r'''import Foundation
import CryptoKit
@main struct Runner {
    static func main() async throws {
        let base = URL(string: CommandLine.arguments[1])!
        let original = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let queuedCancelled = await verifyQueuedDecodeCancellation(original)
        precondition(queuedCancelled, "A queued cancelled decode must return without waiting for the queue to resume")
        let pipeline = IPAImagePipeline(cacheDirectory: root)
        let icon = base.appendingPathComponent("icon")
        async let small = pipeline.image(icon, pixels: 64)
        async let hero = pipeline.image(icon, pixels: 512)
        let pair = await (small, hero)
        precondition(pair.0?.size.width == 64 && pair.1?.size.width == 512)
        // Writes deliberately follow image delivery. Wait for the stable
        // original, ignoring atomic-write temporary files in the directory.
        for _ in 0..<100 {
            let complete = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil))?.contains { $0.pathExtension == "artwork" } ?? false
            if complete { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).filter { $0.pathExtension == "artwork" }
        precondition(files.count == 1 && files[0].pathExtension == "artwork", "Different sizes must share one compressed original on disk")
        let stored = try Data(contentsOf: files[0])
        precondition(stored == original, "The stored original must match publisher bytes exactly")
        await pipeline.trimMemory()
        precondition(FileManager.default.fileExists(atPath: files[0].path), "Background memory trim must keep disk artwork")
        let uncachedSize = await pipeline.image(icon, pixels: 256)
        precondition(uncachedSize?.size.width == 256, "A new decoded size must reuse the on-disk original without the network")
        let sharedURL = base.appendingPathComponent("shared")
        let departing = Task { await pipeline.image(sharedURL, pixels: 200) }
        try await Task.sleep(for: .milliseconds(20))
        let remaining = Task { await pipeline.image(sharedURL, pixels: 200) }
        try await Task.sleep(for: .milliseconds(40))
        let cancelBegan = ContinuousClock.now
        departing.cancel(); let departed = await departing.value
        precondition(departed == nil && cancelBegan.duration(to: .now) < .milliseconds(150))
        let survivor = await remaining.value
        precondition(survivor?.size.width == 200, "One leaving row must not cancel another row's shared image")
        let abandonedURL = base.appendingPathComponent("abandon")
        let last = Task { await pipeline.image(abandonedURL, pixels: 220) }
        try await Task.sleep(for: .milliseconds(60))
        let lastBegan = ContinuousClock.now
        last.cancel(); let cancelledLast = await last.value
        precondition(cancelledLast == nil && lastBegan.duration(to: .now) < .milliseconds(150), "Last subscriber cancellation must release promptly")
        let retried = await pipeline.image(abandonedURL, pixels: 220)
        precondition(retried?.size.width == 220, "An immediately retried request must survive an older cancelled completion")
        let slow = base.appendingPathComponent("slow")
        let loading = Task { await pipeline.image(slow, pixels: 300) }
        try await Task.sleep(nanoseconds: 60_000_000)
        await pipeline.clearCachedArtwork()
        let abandoned = await loading.value
        precondition(abandoned == nil, "An old in-flight decode must not survive Clear Artwork Cache")
        let remainingFiles = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        precondition(remainingFiles.isEmpty, "A cleared cache must not be recreated by an older completion")
        let fresh = await pipeline.image(slow, pixels: 300)
        precondition(fresh?.size.width == 300, "Requests must recover normally after clearing in-flight work")
        // Legacy per-size PNGs remain usable, so upgrading does not force every
        // existing icon to download before its first display.
        let legacyURL = base.appendingPathComponent("legacy")
        let legacyKey = legacyURL.absoluteString + "|180"
        let legacyFile = root.appendingPathComponent(SHA256.hash(data: Data(legacyKey.utf8)).map { String(format: "%02x", $0) }.joined() + ".png")
        try original.write(to: legacyFile)
        let legacy = await pipeline.image(legacyURL, pixels: 180)
        precondition(legacy?.size.width == 180)
        let corruptURL = base.appendingPathComponent("corrupt")
        let corruptFile = root.appendingPathComponent(SHA256.hash(data: Data(corruptURL.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined() + ".artwork")
        try Data("broken image".utf8).write(to: corruptFile)
        let recovered = await pipeline.image(corruptURL, pixels: 181)
        for _ in 0..<100 {
            if (try? Data(contentsOf: corruptFile)) == original { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let recoveredBytes = try Data(contentsOf: corruptFile)
        precondition(recovered?.size.width == 181 && recoveredBytes == original, "A fresh but corrupt disk file must be replaced after network recovery")
        print("PASS: real image downsampling at three sizes, one exact compressed original, disk-only new size, clear/in-flight cancellation, post-clear recovery, legacy cache reuse and corrupt-cache replacement")
        print("stored_original_bytes=" + String(stored.count) + " disk_files_for_two_sizes=" + String(files.count))
    }
}
''')
try:
    subprocess.run(['swiftc', str(scratch / 'Artwork.swift'), str(scratch / 'Runner.swift'), '-parse-as-library', '-swift-version', '5', '-module-cache-path', str(root / '.build/ReleaseChecks/ModuleCache'), '-o', str(scratch / 'checks')], check=True)
    result = subprocess.run([str(scratch / 'checks'), f'http://127.0.0.1:{server.server_port}', str(root / 'Resources/Assets.xcassets/AppIcon.appiconset/IPAStore-Black.png')], capture_output=True, text=True)
    if result.returncode: print(result.stdout, result.stderr)
    result.check_returncode()
    assert counts.get('/icon') == 1 and counts.get('/shared') == 1 and counts.get('/legacy', 0) == 0 and counts.get('/corrupt') == 1, counts
    report = result.stdout + json.dumps(counts) + '\n'
    (root / 'Validation/artwork-cache-checks.txt').write_text(report)
    print(report)
finally:
    server.shutdown(); server.server_close()
