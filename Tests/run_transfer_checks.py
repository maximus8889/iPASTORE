"""Exercise the real download delegate with HTTP, pause/resume and cancellation."""
from pathlib import Path
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
import threading, subprocess, hashlib, json, time
root=Path(__file__).resolve().parents[1]
scratch=root/'.build/TransferChecks';scratch.mkdir(parents=True,exist_ok=True)
payload=bytes(range(256))*16384
class Handler(BaseHTTPRequestHandler):
    def log_message(self,*a):pass
    def do_GET(self):
        if self.path=='/error':self.send_error(404);return
        self.send_response(200)
        if self.path!='/unknown':self.send_header('Content-Length',str(len(payload)))
        self.end_headers()
        try:
            for offset in range(0,len(payload),32768):
                self.wfile.write(payload[offset:offset+32768]);self.wfile.flush();time.sleep(.008)
        except (BrokenPipeError,ConnectionResetError):pass
server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
runner=scratch/'TransferMain.swift'
runner.write_text('''import Foundation
import CryptoKit
final class Counter: @unchecked Sendable {
    let lock = NSLock(); var bytes: Int64 = 0; var unknown = false
    func update(_ value: IPADownloadTransfer.Update) { lock.lock(); bytes = value.received; unknown = unknown || value.expected <= 0; lock.unlock() }
    func current() -> Int64 { lock.lock(); defer { lock.unlock() }; return bytes }
}
@main struct TransferMain {
    static func main() async throws {
        let base = CommandLine.arguments[1]
        let counter = Counter()
        let first = IPADownloadTransfer(priority: URLSessionTask.highPriority, expectedBytes: 4194304) { counter.update($0) }
        let operation = Task { try await first.download(URL(string: base + "/valid")!) }
        try await Task.sleep(for: .milliseconds(200))
        first.setPaused(true)
        try await Task.sleep(for: .milliseconds(150))
        let pausedBytes = counter.current()
        let second = IPADownloadTransfer { _ in }
        let secondFile = try await second.download(URL(string: base + "/valid")!)
        defer { try? FileManager.default.removeItem(at: secondFile) }
        guard counter.current() == pausedBytes else { fatalError("Paused transfer continued receiving data") }
        first.setPaused(false)
        let firstFile = try await operation.value
        defer { try? FileManager.default.removeItem(at: firstFile) }
        let digest = SHA256.hash(data: try Data(contentsOf: firstFile)).map { String(format: "%02x", $0) }.joined()
        guard digest == CommandLine.arguments[2], try Data(contentsOf: firstFile) == Data(contentsOf: secondFile) else { fatalError("Downloaded bytes changed") }
        let unknownCounter = Counter()
        let unknown = IPADownloadTransfer(priority: URLSessionTask.highPriority, expectedBytes: 123) { unknownCounter.update($0) }
        let unknownFile = try await unknown.download(URL(string: base + "/unknown")!)
        defer { try? FileManager.default.removeItem(at: unknownFile) }
        guard unknownCounter.unknown else { fatalError("A catalog size hint must not fabricate HTTP progress") }
        let cancelled = IPADownloadTransfer { _ in }
        let cancelTask = Task { try await cancelled.download(URL(string: base + "/valid")!) }
        try await Task.sleep(for: .milliseconds(100)); cancelled.cancel()
        do { _ = try await cancelTask.value; fatalError("Cancelled download succeeded") } catch is CancellationError {} 
        let http = IPADownloadTransfer { _ in }
        do { _ = try await http.download(URL(string: base + "/error")!); fatalError("HTTP failure succeeded") } catch { guard (error as NSError).domain == "iPAStore.DownloadHTTP", (error as NSError).code == 404 else { throw error } }
        for path in ["/valid", "/unknown"] {
            let bounded = IPADownloadTransfer(maximumBytes: 1024) { _ in }
            do { _ = try await bounded.download(URL(string: base + path)!); fatalError("Oversized download succeeded") }
            catch { guard (error as? URLError)?.code == .dataLengthExceedsMaximum else { throw error } }
        }
        let beforeStart = IPADownloadTransfer { _ in }
        beforeStart.cancel()
        do { _ = try await beforeStart.download(URL(string: base + "/valid")!); fatalError("Pre-cancelled transfer succeeded") } catch is CancellationError {}
        let paused = IPADownloadTransfer { _ in }
        paused.setPaused(true)
        let pausedTask = Task { try await paused.download(URL(string: base + "/valid")!) }
        try await Task.sleep(for: .milliseconds(60)); paused.cancel(); paused.cancel()
        do { _ = try await pausedTask.value; fatalError("Paused cancellation succeeded") } catch is CancellationError {}
        print("PASS: preserved bytes, owned file lifetime, pause/resume, concurrent download while paused, cancellation, unknown length, HTTP failure")
    }
}
''')
try:
    subprocess.run(['swiftc',str(root/'LiveContainerSwiftUI/Models/IPADownloadTransfer.swift'),str(runner),'-o',str(scratch/'transfer-check')],check=True)
    result=subprocess.check_output([str(scratch/'transfer-check'),f'http://127.0.0.1:{server.server_port}',hashlib.sha256(payload).hexdigest()],text=True)
    (root/'Validation/transfer-checks.txt').write_text(result);print(result)
finally:server.shutdown();server.server_close()
