import Foundation

struct IPAGuestLifecycle {
    private(set) var wasInterrupted = false
    private(set) var inBackground = false
    private(set) var activationTime: TimeInterval?
    private var resumed = false
    var allowsCompatibilityDecision: Bool { !wasInterrupted && !inBackground }
    mutating func interrupt() { wasInterrupted = true; inBackground = true; resumed = false }
    mutating func foreground() { inBackground = false }
    mutating func activate(at time: TimeInterval) { if activationTime == nil { activationTime = time } }
    mutating func claimResume() -> Bool {
        guard wasInterrupted, !inBackground, !resumed else { return false }
        resumed = true; return true
    }
}

struct IPAGuestResumeRecord: Codable, Equatable {
    let appFolder: String
    let dataFolder: String
    let revision: String
    let name: String
    static let key = "IPAGuestResume.v1"
    static func component(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 255 && value != "." && value != ".." && !value.contains("/") && !value.contains("\\") && !value.contains("\0")
    }
    static func read(from defaults: UserDefaults) -> Self? {
        guard let data = defaults.data(forKey: key), data.count <= 4096,
              let record = try? JSONDecoder().decode(Self.self, from: data),
              component(record.appFolder), component(record.dataFolder), record.revision.count <= 256, record.name.count <= 160 else { return nil }
        return record
    }
    func save(to defaults: UserDefaults) {
        guard Self.component(appFolder), Self.component(dataFolder), let data = try? JSONEncoder().encode(self), data.count <= 4096 else { return }
        defaults.set(data, forKey: Self.key)
    }
}
