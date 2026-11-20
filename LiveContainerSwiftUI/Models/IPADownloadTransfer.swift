import Foundation

// Own the temporary file before URLSession removes it at delegate return.
// Progress describes received bytes; an absent Content-Length stays unknown.
final class IPADownloadTransfer: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    struct Update: Sendable { let received: Int64; let expected: Int64 }
    private let lock = NSLock()
    private var continuation: CheckedContinuation<URL, Error>?
    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    private var owned: URL?
    private var pendingOutcome: Result<URL, Error>?
    private var failure: Error?
    private var cancelled = false
    private var paused = false
    private var lastUpdate = Date.distantPast
    private let maximumBytes: Int64?
    private var finalURL: URL?
    var resolvedURL: URL? { lock.lock(); defer { lock.unlock() }; return finalURL }
    private let update: @Sendable (Update) -> Void
    private let requestTimeout: TimeInterval
    private let resourceTimeout: TimeInterval
    private let headers: [String: String]
    private let cachePolicy: URLRequest.CachePolicy
    private let priority: Float
    private let expectedBytes: Int64?
    init(maximumBytes: Int64? = nil, requestTimeout: TimeInterval = 60, resourceTimeout: TimeInterval = 3600,
         headers: [String: String] = [:], cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
         priority: Float = URLSessionTask.defaultPriority, expectedBytes: Int64? = nil,
         update: @escaping @Sendable (Update) -> Void) {
        self.maximumBytes = maximumBytes; self.requestTimeout = requestTimeout; self.resourceTimeout = resourceTimeout
        self.headers = headers; self.cachePolicy = cachePolicy; self.update = update
        self.priority = priority.isFinite ? min(1, max(0, priority)) : URLSessionTask.defaultPriority
        self.expectedBytes = expectedBytes
    }
    func download(_ url: URL) async throws -> URL {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { reply in
                lock.lock()
                if cancelled { lock.unlock(); reply.resume(throwing: CancellationError()); return }
                continuation = reply
                let config = URLSessionConfiguration.ephemeral
                config.httpCookieStorage = nil; config.urlCredentialStorage = nil
                config.timeoutIntervalForRequest = requestTimeout; config.timeoutIntervalForResource = resourceTimeout
                let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
                self.session = session
                var request = URLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: requestTimeout)
                for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
                let task = session.downloadTask(with: request); self.task = task
                task.priority = priority
                if let expectedBytes, expectedBytes > 0 { task.countOfBytesClientExpectsToReceive = expectedBytes }
                if !paused { task.resume() }
                lock.unlock()
            }
        } onCancel: { self.cancel() }
    }
    func setPaused(_ value: Bool) {
        lock.lock()
        guard paused != value, !cancelled else { lock.unlock(); return }
        paused = value
        if value { task?.suspend() } else { task?.resume() }
        // A completion already in flight may arrive after suspend. Keep the file
        // paused too; it must never advance to installation until Resume.
        let outcome = value ? nil : pendingOutcome
        let reply = outcome == nil ? nil : continuation
        if outcome != nil { pendingOutcome = nil; continuation = nil }
        lock.unlock()
        if let outcome { reply?.resume(with: outcome) }
    }
    func cancel() {
        lock.lock(); cancelled = true
        let session = session; let task = task
        let outcome = pendingOutcome; pendingOutcome = nil
        let reply = outcome == nil ? nil : continuation
        if outcome != nil { continuation = nil }
        lock.unlock()
        if case .success(let file) = outcome { try? FileManager.default.removeItem(at: file) }
        reply?.resume(throwing: CancellationError())
        task?.cancel(); session?.invalidateAndCancel()
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let now = Date()
        lock.lock()
        if let maximumBytes, max(totalBytesWritten, totalBytesExpectedToWrite) > maximumBytes {
            failure = URLError(.dataLengthExceedsMaximum); lock.unlock(); downloadTask.cancel(); return
        }
        let send = !paused && !cancelled && (now.timeIntervalSince(lastUpdate) >= 0.1 || totalBytesWritten == totalBytesExpectedToWrite)
        if send { lastUpdate = now }
        lock.unlock()
        if send { update(Update(received: totalBytesWritten, expected: totalBytesExpectedToWrite)) }
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            if let maximumBytes, (try location.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) > maximumBytes { throw URLError(.dataLengthExceedsMaximum) }
            guard let response = downloadTask.response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            guard (200...299).contains(response.statusCode) else {
                throw NSError(domain: "iPAStore.DownloadHTTP", code: response.statusCode)
            }
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent("IPAStore-Download-\(UUID().uuidString).ipa")
            try FileManager.default.moveItem(at: location, to: destination)
            lock.lock(); owned = destination; finalURL = response.url; lock.unlock()
        } catch { lock.lock(); failure = error; lock.unlock() }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let file = owned; owned = nil
        let failure: Error? = cancelled ? CancellationError() : (self.failure ?? error)
        let outcome: Result<URL, Error> = failure.map { .failure($0) } ?? file.map { .success($0) } ?? .failure(URLError(.cannotCreateFile))
        let hold = paused && !cancelled
        let reply = hold ? nil : continuation
        if hold { pendingOutcome = outcome } else { continuation = nil }
        self.task = nil; self.session = nil
        lock.unlock()
        session.finishTasksAndInvalidate()
        if failure != nil, let file { try? FileManager.default.removeItem(at: file) }
        if !hold { reply?.resume(with: outcome) }
    }
}
