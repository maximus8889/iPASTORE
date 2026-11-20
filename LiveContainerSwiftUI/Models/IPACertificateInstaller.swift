import Foundation
import Network
import CryptoKit

struct IPACertificateInstallation: Identifiable {
    let id = UUID()
    let name: String
    let identifier: String
    let openURL: URL
}

// A bounded, loopback-only server. Only the random IPA path is served; no
// credentials, profile endpoints or directory browsing are exposed.
final class IPALocalInstallServer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.ipastore.install-server", qos: .userInitiated)
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private let package: URL
    private let token = UUID().uuidString
    private var startup: CheckedContinuation<URL, Error>?
    private var started = false
    init(package: URL) { self.package = package }
    func start() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.startup = continuation
                do {
                    let parameters = NWParameters.tcp
                    parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
                    let listener = try NWListener(using: parameters)
                    self.listener = listener
                    listener.newConnectionHandler = { [weak self] in self?.accept($0) }
                    listener.stateUpdateHandler = { [weak self] state in
                        guard let self else { return }
                        switch state {
                        case .ready:
                            guard !self.started, let port = self.listener?.port else { return }
                            self.started = true
                            let reply = self.startup; self.startup = nil
                            reply?.resume(returning: URL(string: "http://127.0.0.1:\(port.rawValue)/\(self.token).ipa")!)
                        case .failed(let error):
                            let reply = self.startup; self.startup = nil; reply?.resume(throwing: error)
                        default: break
                        }
                    }
                    listener.start(queue: self.queue)
                    self.queue.asyncAfter(deadline: .now() + 10) {
                        guard let reply = self.startup else { return }
                        self.startup = nil; listener.cancel(); reply.resume(throwing: URLError(.timedOut))
                    }
                } catch { self.startup = nil; continuation.resume(throwing: error) }
            }
        }
    }
    func stop() { queue.async { self.listener?.cancel(); self.listener = nil; self.connections.values.forEach { $0.cancel() }; self.connections.removeAll() } }
    private func accept(_ connection: NWConnection) {
        guard connections.count < 8 else { connection.cancel(); return }
        let id = ObjectIdentifier(connection); connections[id] = connection
        connection.stateUpdateHandler = { [weak self] state in
            if case .cancelled = state { self?.connections.removeValue(forKey: id) }
            if case .failed = state { self?.connections.removeValue(forKey: id) }
        }
        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + 600) { [weak self, weak connection] in
            if self?.connections[id] != nil { connection?.cancel() }
        }
        receive(connection, buffer: Data())
    }
    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, complete, error in
            guard let self else { connection.cancel(); return }
            var request = buffer; if let data { request.append(data) }
            guard request.count <= 16_384, error == nil else { connection.cancel(); return }
            if request.range(of: Data("\r\n\r\n".utf8)) != nil { self.respond(connection, request: request) }
            else if complete { connection.cancel() }
            else { self.receive(connection, buffer: request) }
        }
    }
    private func respond(_ connection: NWConnection, request: Data) {
        let line = String(decoding: request, as: UTF8.self).components(separatedBy: "\r\n").first ?? ""
        let fields = line.split(separator: " ")
        guard fields.count == 3, ["GET", "HEAD"].contains(fields[0]), fields[1] == "/\(token).ipa",
              let file = try? FileHandle(forReadingFrom: package), let size = try? file.seekToEnd() else { connection.cancel(); return }
        try? file.seek(toOffset: 0)
        let header = Data("HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length: \(size)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n".utf8)
        connection.send(content: header, completion: .contentProcessed { [weak self] error in
            if error != nil || fields[0] == "HEAD" { try? file.close(); connection.cancel(); return }
            self?.send(connection, file: file)
        })
    }
    private func send(_ connection: NWConnection, file: FileHandle) {
        do {
            let chunk = try file.read(upToCount: 256 * 1024) ?? Data()
            guard !chunk.isEmpty else { try? file.close(); connection.cancel(); return }
            connection.send(content: chunk, completion: .contentProcessed { [weak self] error in
                if error != nil { try? file.close(); connection.cancel() }
                else if let self { self.send(connection, file: file) }
                else { try? file.close(); connection.cancel() }
            })
        } catch { try? file.close(); connection.cancel() }
    }
}

enum IPACertificatePolicy {
    static func launchURL(identifier: String) -> URL {
        let hash = SHA256.hash(data: Data(identifier.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
        return URL(string: "ipastore-app-\(hash)://")!
    }
    static func acceptsLaunchURL(_ url: URL, identifier: String, resignedIdentifier: String) -> Bool {
        url == launchURL(identifier: identifier) || (url.scheme == "sidestore-" + resignedIdentifier && url.host?.isEmpty != false)
    }
    static func installURL(payload: URL, identifier: String, name: String, version: String) -> URL? {
        var manifest = URLComponents(string: "https://api.palera.in/genPlist")!
        manifest.queryItems = [URLQueryItem(name: "bundleid", value: identifier), URLQueryItem(name: "name", value: name), URLQueryItem(name: "version", value: version), URLQueryItem(name: "fetchurl", value: payload.absoluteString)]
        var install = URLComponents(string: "itms-services://")!
        install.queryItems = [URLQueryItem(name: "action", value: "download-manifest"), URLQueryItem(name: "url", value: manifest.url!.absoluteString)]
        return install.url
    }
}
