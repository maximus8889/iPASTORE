import Foundation

// A real early guest failure can select legacy launch. A timer or a running
// app closing cannot. v3 ignores choices made before interruption-aware handling.
struct IPACompatibilityLaunchPolicy {
    enum Failure { case initialization, exited(activationAge: TimeInterval?), timeout }
    let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    static func shouldRetry(_ failure: Failure, alreadyRetried: Bool, wasInterrupted: Bool = false) -> Bool {
        guard !alreadyRetried, !wasInterrupted else { return false }
        switch failure {
        case .initialization: return true
        case .timeout: return false
        case .exited(let age):
            guard let age else { return true }
            return age.isFinite && age >= 0 && age <= 3
        }
    }
    func prefersCompatibility(identifier: String, revision: String) -> Bool {
        !identifier.isEmpty && defaults.string(forKey: key(identifier)) == revision
    }
    func remember(identifier: String, revision: String) {
        guard !identifier.isEmpty else { return }
        defaults.set(revision, forKey: key(identifier))
    }
    func forget(identifier: String) { defaults.removeObject(forKey: key(identifier)) }
    private func key(_ identifier: String) -> String { "IPACompatibilityLaunch.v3." + identifier.lowercased() }
}
