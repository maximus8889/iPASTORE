import Foundation

struct IPAProvisioningMetadata: Equatable {
    let createdAt: Date?
    let expiresAt: Date
    // Read the metadata payload of the installed profile. This is not a certificate/trust verifier.
    static func read(from data: Data) -> IPAProvisioningMetadata? {
        let start = Data("<?xml".utf8), end = Data("</plist>".utf8)
        guard let opening = data.range(of: start), let closing = data.range(of: end, in: opening.lowerBound..<data.endIndex), closing.upperBound - opening.lowerBound < 4_194_304 else { return nil }
        let payload = data.subdata(in: opening.lowerBound..<closing.upperBound)
        guard let plist = try? PropertyListSerialization.propertyList(from: payload, format: nil) as? [String: Any], let expiration = plist["ExpirationDate"] as? Date else { return nil }
        let creation = plist["CreationDate"] as? Date
        guard creation == nil || creation! < expiration else { return nil }
        return .init(createdAt: creation, expiresAt: expiration)
    }
}

enum IPARenewalPolicy {
    static func successMessage(profile: IPAProvisioningMetadata?, now: Date = Date()) -> String {
        guard let profile, profile.expiresAt > now else {
            return "Signing completed. Reopen iPAStore to check the updated signature’s expiry."
        }
        let days = max(1, Int(ceil(profile.expiresAt.timeIntervalSince(now) / 86_400)))
        let remaining = days == 1 ? "less than a day" : "about \(days) days"
        return "Signing completed. Your installed signature has \(remaining) remaining and expires \(profile.expiresAt.formatted(date: .abbreviated, time: .shortened))."
    }
    static let taskIdentifier = "app.ipastore.renewal"
    static let retryInterval: TimeInterval = 4 * 3_600
    enum Decision: Equatable {
        case manual, setupRequired, expirationUnknown
        case waiting(until: Date), retryAfter(Date), due
    }
    static func targetDate(for profile: IPAProvisioningMetadata) -> Date {
        let lifetime = profile.createdAt.map { profile.expiresAt.timeIntervalSince($0) } ?? 7 * 86_400
        let lead = min(48 * 3_600, max(15 * 60, lifetime * 0.25))
        return profile.expiresAt.addingTimeInterval(-lead)
    }
    static func decide(automatic: Bool, ready: Bool, profile: IPAProvisioningMetadata?, lastAttempt: Date?, now: Date) -> Decision {
        guard automatic else { return .manual }
        guard ready else { return .setupRequired }
        guard let profile else { return .expirationUnknown }
        let target = targetDate(for: profile)
        guard now >= target else { return .waiting(until: target) }
        if let lastAttempt, now.timeIntervalSince(lastAttempt) < retryInterval { return .retryAfter(lastAttempt.addingTimeInterval(retryInterval)) }
        return .due
    }
}
