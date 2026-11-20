"""Exercise production listing metadata with a local publisher and cancellable consumers."""
from pathlib import Path
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
import json, subprocess, threading

root = Path(__file__).resolve().parents[1]
scratch = root / '.build/MetadataChecks'
scratch.mkdir(parents=True, exist_ok=True)
counts = {}
lock = threading.Lock()
good = json.dumps({'results': [{'kind': 'software', 'bundleId': 'org.test.app',
    'artworkUrl512': 'https://example.org/icon.png', 'screenshotUrls': ['https://example.org/screen.jpg']}]}).encode()

class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    def log_message(self, *args): pass
    def do_GET(self):
        with lock: counts[self.path] = counts.get(self.path, 0) + 1
        code, body = 200, good
        if self.path == '/missing': body = b'{"results":[]}'
        if self.path == '/broken': body = b'not JSON'
        if self.path == '/failure': code, body = 503, b'offline'
        if self.path == '/large': body = b'x' * (2 * 1024 * 1024 + 1)
        self.send_response(code)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        try: self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError): pass

server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
(scratch / 'Runner.swift').write_text(r'''import Foundation
import CryptoKit
actor Fixture {
    var calls: [String: Int] = [:]
    func count(_ id: String) -> Int { calls[id] ?? 0 }
    func load(_ id: String) async throws -> IPAProductMetadata? {
        calls[id, default: 0] += 1
        if id == "org.transient", calls[id] == 1 { throw URLError(.notConnectedToInternet) }
        if id == "org.absent" { return nil }
        if id.hasPrefix("org.cancel") { try await Task.sleep(nanoseconds: 100_000_000) }
        return .init(bundleIdentifier: id, icon: URL(string: "https://example.org/icon.png"), screenshots: [], rating: nil, ratingCount: nil, ageRating: nil, category: nil, languages: [], listing: nil)
    }
}
struct Saved: Codable { let date: Date; let metadata: IPAProductMetadata? }
@main struct Runner {
    static func main() async throws {
        let base = URL(string: CommandLine.arguments[1])!
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let good = try await IPAProductMetadataResolver.fetch(from: base.appendingPathComponent("good"), matching: "org.test.app")
        precondition(good?.icon != nil)
        let absent = try await IPAProductMetadataResolver.fetch(from: base.appendingPathComponent("missing"), matching: "org.test.app")
        precondition(absent == nil)
        for path in ["broken", "failure", "large"] {
            do { _ = try await IPAProductMetadataResolver.fetch(from: base.appendingPathComponent(path), matching: "org.test.app"); preconditionFailure("Invalid HTTP/body accepted") }
            catch { }
        }
        do { _ = try await IPAProductMetadataResolver.fetch(from: base.appendingPathComponent("good"), matching: "org.wrong.app"); preconditionFailure("Wrong app matched") } catch { }
        let resolver = IPAProductMetadataResolver(cacheDirectory: root.appendingPathComponent("shared"), minimumRequestInterval: 0, lookup: { id in
            try await IPAProductMetadataResolver.fetch(from: base.appendingPathComponent("shared"), matching: id)
        })
        async let one = resolver.resolve("org.test.app")
        async let two = resolver.resolve("org.test.app")
        let pair = await (one, two)
        precondition(pair.0 == good && pair.1 == good)
        let cached = await resolver.resolve("org.test.app")
        precondition(cached == good)
        let fixture = Fixture()
        let model = IPAProductMetadataResolver(cacheDirectory: root.appendingPathComponent("fixture"), minimumRequestInterval: 0, retryInterval: 0, lookup: { try await fixture.load($0) })
        let firstFailure = await model.resolve("org.transient")
        let recovered = await model.resolve("org.transient")
        precondition(firstFailure == nil && recovered != nil, "Transient failures must not become a day-long missing listing")
        _ = await model.resolve("org.absent"); _ = await model.resolve("org.absent")
        let absentCalls = await fixture.count("org.absent")
        precondition(absentCalls == 1, "A genuine missing listing remains negatively cached")
        let cancelled = Task { await model.resolve("org.cancel.shared") }
        let retained = Task { await model.resolve("org.cancel.shared") }
        while await fixture.count("org.cancel.shared") == 0 { await Task.yield() }
        try await Task.sleep(nanoseconds: 15_000_000)
        cancelled.cancel()
        let cancelledValue = await cancelled.value, retainedValue = await retained.value
        let sharedCalls = await fixture.count("org.cancel.shared")
        precondition(cancelledValue == nil && retainedValue != nil && sharedCalls == 1, "One cancelled page must not cancel another page's shared lookup")
        let abandoned = Task { await model.resolve("org.cancel.all") }
        while await fixture.count("org.cancel.all") == 0 { await Task.yield() }
        abandoned.cancel(); _ = await abandoned.value
        let retried = await model.resolve("org.cancel.all")
        let retriedCalls = await fixture.count("org.cancel.all")
        precondition(retried != nil && retriedCalls == 2, "Cancelled work cannot cache a missing result or erase a replacement request")
        for number in 0..<130 { _ = await model.resolve("org.bulk." + String(number)) }
        _ = await model.resolve("org.bulk.120")
        let kept = await fixture.count("org.bulk.120")
        precondition(kept == 1, "A full memory cache evicts the oldest entry, not the entire cache")
        let staleDirectory = root.appendingPathComponent("stale")
        try FileManager.default.createDirectory(at: staleDirectory, withIntermediateDirectories: true)
        let filename = SHA256.hash(data: Data("org.test.app".utf8)).map { String(format: "%02x", $0) }.joined() + ".json"
        let staleFile = staleDirectory.appendingPathComponent(filename)
        let bytes = try JSONEncoder().encode(Saved(date: Date().addingTimeInterval(-8 * 86400), metadata: good))
        try bytes.write(to: staleFile)
        let offline = IPAProductMetadataResolver(cacheDirectory: staleDirectory, minimumRequestInterval: 0, lookup: { _ in throw URLError(.notConnectedToInternet) })
        let offlineValue = await offline.resolve("org.test.app")
        precondition(offlineValue == good && (try? Data(contentsOf: staleFile)) == bytes, "Offline lookup must preserve usable older artwork and its disk cache")
        let rate = IPAProductMetadataResolver(cacheDirectory: root.appendingPathComponent("rate"), minimumRequestInterval: 0.15, lookup: { try await fixture.load($0) })
        _ = await rate.resolve("org.rate.first")
        let queued = (0..<10).map { number in Task { await rate.resolve("org.rate." + String(number)) } }
        try await Task.sleep(nanoseconds: 10_000_000)
        for task in queued { task.cancel() }
        for task in queued { _ = await task.value }
        let start = Date()
        let current = await rate.resolve("org.rate.current")
        precondition(current != nil && Date().timeIntervalSince(start) < 1, "Abandoned pages must not reserve many future rate-limit slots")
        print("PASS: bounded pooled HTTP, exact identity, genuine absence, transient recovery, shared cancellation, abandoned lookup retry, stale offline artwork, bounded cache retention and current-page rate scheduling")
    }
}
''')
try:
    subprocess.run(['swiftc', str(root / 'LiveContainerSwiftUI/Models/IPAProductMetadata.swift'), str(scratch / 'Runner.swift'), '-parse-as-library', '-swift-version', '5', '-module-cache-path', str(scratch / 'ModuleCache'), '-o', str(scratch / 'checks')], check=True)
    result = subprocess.run([str(scratch / 'checks'), f'http://127.0.0.1:{server.server_port}'], capture_output=True, text=True)
    if result.returncode: print(result.stdout, result.stderr)
    result.check_returncode()
    assert counts.get('/shared') == 1, counts
    report = result.stdout + json.dumps(counts) + '\n'
    (root / 'Validation/metadata-checks.txt').write_text(report)
    print(report)
finally:
    server.shutdown(); server.server_close()
