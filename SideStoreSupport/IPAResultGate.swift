import Foundation

/// A one-shot result that tolerates completion before waiting and duplicate callbacks.
/// State is protected because XPC, task cancellation and extension events use different queues.
final class IPAResultGate<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<Value, Error>?
    private var waiters: [CheckedContinuation<Value, Error>] = []
    func wait() async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if let result { lock.unlock(); continuation.resume(with: result) }
            else { waiters.append(continuation); lock.unlock() }
        }
    }
    @discardableResult func finish(_ value: Result<Value, Error>) -> Bool {
        lock.lock()
        guard result == nil else { lock.unlock(); return false }
        result = value
        let pending = waiters; waiters.removeAll()
        lock.unlock()
        pending.forEach { $0.resume(with: value) }
        return true
    }
}
