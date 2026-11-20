import Foundation

struct IPAInstallIssue: LocalizedError, Identifiable {
    enum Action { case retry, signing, containerMode, storage, compatibleBuild, none }
    let id = UUID()
    let title: String
    let message: String
    let action: Action
    var errorDescription: String? { message }
    static let signing = Self(title: "Finish Signing Setup", message: "To install or open apps inside iPAStore, open Settings → Manage. Choose Apple Account setup, or import your .p12 and password, then tap Verify Certificate. A certificate must be accepted by iOS; importing it alone is not enough.", action: .signing)
    static let certificateProfile = Self(title: "Add a Provisioning Profile", message: "For real Home Screen apps, add the .mobileprovision file matching your .p12 in Settings → Manage. Its app identifier and device coverage must authorize the app you install.", action: .signing)
    static let independentSetup = Self(title: "Set Up iPhone Installation", message: "Choose a certificate with its matching provisioning profile, or finish Apple Account, pairing and local connection setup. Apps installed inside iPAStore use Home Screen shortcuts that return to iPAStore; installing on iPhone creates a separate app.", action: .containerMode)
    static let incompatible = Self(title: "Compatible Version Required", message: "This app needs a different iOS version or device. Choose a compatible edition from its publisher. Changing its version label will not make it compatible.", action: .compatibleBuild)
    static func launch(_ diagnostic: String) -> Self {
        let text = diagnostic.lowercased()
        if text.contains("sign") || text.contains("certificat") {
            return Self(title: "App Signature Needs Attention", message: "The app could not start with its current signature. Verify your certificate in Settings → Manage, then re-sign the app in its settings. If you imported a different certificate, use the certificate and provisioning profile that signed iPAStore. Your app data has been kept.", action: .signing)
        }
        if text.contains("jit") || text.contains("32-bit") || text.contains("32bit") {
            return Self(title: "Runtime Setup Required", message: "This app requires a compatible JIT or emulator setup. Review its launch settings and the developer’s iOS requirements before trying again. Signing alone cannot add a missing runtime.", action: .compatibleBuild)
        }
        if text.contains("library not loaded") || text.contains("symbol not found") || text.contains("dyld") {
            return Self(title: "App Runtime Couldn’t Load", message: "The app depends on a library or system feature that could not load. Check its developer’s supported iOS versions, try a current build, or review this app’s compatibility settings. Your data has been kept.", action: .compatibleBuild)
        }
        return Self(title: "App Couldn’t Start", message: "The previous launch did not finish. Verify your signing certificate and check the app’s iOS and runtime requirements. You can change its launch options in app settings or try a current build from its developer. Your installed app data has been kept.", action: .signing)
    }
    static func from(_ error: Error) -> Self {
        if let issue = error as? Self { return issue }
        let cocoa = error as NSError
        if cocoa.domain == NSCocoaErrorDomain && [NSFileWriteOutOfSpaceError, NSFileReadTooLargeError].contains(cocoa.code) {
            return Self(title: "More Space Needed", message: "Free space in iPhone Storage, then try again. Installation needs space for both the download and its extracted files.", action: .storage)
        }
        if cocoa.domain == "iPAStore.DownloadHTTP" {
            let explanation: String
            switch cocoa.code {
            case 401, 403: explanation = "The publisher denied this download. It may require access through its website or a fresh download link."
            case 404, 410: explanation = "The publisher’s download link is no longer available."
            case 429: explanation = "The publisher is limiting downloads. Wait a little before trying again."
            default: explanation = "The download server returned an error (HTTP \(cocoa.code))."
            }
            return Self(title: "Download Unavailable", message: explanation + " Refresh the library or visit its Web link for an original IPA, then import it in Apps.", action: .retry)
        }
        if ["iPAStore.Profile", "iPAStore.Signing", "iPAStore.Archive"].contains(cocoa.domain) {
            return Self(title: "Installation Needs Attention", message: cocoa.localizedDescription, action: .signing)
        }
        if let network = error as? URLError {
            return Self(title: "Download Interrupted", message: network.code == .timedOut ? "The server took too long to respond. Try again on a reliable connection. If it continues, check for an updated link from the library’s publisher." : "Check your internet connection and try again. If this download is no longer available, refresh its library or contact its publisher.", action: .retry)
        }
        return Self(title: "Installation Couldn’t Finish", message: "Try again after checking Settings → Manage. If this file still fails, use a current compatible IPA from its publisher. Your existing apps have been kept.", action: .signing)
    }
}

enum IPACompatibility {
    // Explicit publisher declarations take precedence. The UTM mapping is from
    // its official iOS installation guide; SE is deliberately excluded.
    static func requiresJIT(identifier: String, declared: Bool = false) -> Bool {
        declared || ["com.utmapp.utm", "com.utmapp.utm-hv"].contains(identifier.lowercased())
    }
    static var runtimeIssue: IPAInstallIssue {
        IPAInstallIssue(title: "Additional Runtime Required", message: "This edition requires JIT and a compatible launch setup. Guided JIT installation is not yet available in this candidate, so its download hasn’t started. Choose a version that works without JIT, such as UTM SE, or follow the publisher’s supported installation guide.", action: .compatibleBuild)
    }
    static func version(_ raw: String) -> [Int]? {
        let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...4).contains(parts.count), parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }), parts.allSatisfy({ Int($0) != nil }) else { return nil }
        return parts.map { Int($0)! }
    }
    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult? {
        guard let a = version(lhs), let b = version(rhs) else { return nil }
        for index in 0..<max(a.count, b.count) {
            let x = index < a.count ? a[index] : 0, y = index < b.count ? b[index] : 0
            if x < y { return .orderedAscending }; if x > y { return .orderedDescending }
        }
        return .orderedSame
    }
    static func issue(minimum: String?, maximum: String?, current: String) -> IPAInstallIssue? {
        if let minimum {
            guard let result = compare(current, minimum) else { return IPAInstallIssue(title: "Requirements Unavailable", message: "The publisher supplied an unreadable iOS requirement. Refresh this library or ask its publisher to correct the version information.", action: .compatibleBuild) }
            if result == .orderedAscending { return IPAInstallIssue(title: "iOS \(minimum) Required", message: "This version requires iOS \(minimum) or later. Check Software Update, or choose an older compatible edition from the publisher.", action: .compatibleBuild) }
        }
        if let maximum {
            guard let result = compare(current, maximum) else { return IPAInstallIssue.incompatible }
            if result == .orderedDescending { return IPAInstallIssue(title: "Different Edition Required", message: "The publisher supports this version only through iOS \(maximum). Choose a newer compatible edition for iOS \(current).", action: .compatibleBuild) }
        }
        return nil
    }
}

// Bounds-checked read-only validation. This does not decrypt or modify binaries.
// Validate every embedded framework too: an arm64 main executable alone is insufficient.
enum IPABinaryInspector {
    struct Slice { let cpu: UInt32; let subtype: UInt32; let encrypted: Bool; let minimumOS: String?; let platform: UInt32?; let fileType: UInt32 }
    static func inspect(_ url: URL) throws -> [Slice] {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let length = try file.seekToEnd()
        func read(_ offset: UInt64, _ count: Int) throws -> Data {
            guard offset <= length, count >= 0, UInt64(count) <= length - offset else { throw IPAInstallIssue.incompatible }
            try file.seek(toOffset: offset)
            guard let data = try file.read(upToCount: count), data.count == count else { throw IPAInstallIssue.incompatible }
            return data
        }
        func u32(_ data: Data, _ at: Int, _ big: Bool = false) -> UInt32 {
            let bytes = Array(data[at..<at+4])
            return big ? bytes.reduce(0) { ($0 << 8) | UInt32($1) } : bytes.reversed().reduce(0) { ($0 << 8) | UInt32($1) }
        }
        func u64(_ data: Data, _ at: Int) -> UInt64 { (UInt64(u32(data, at, true)) << 32) | UInt64(u32(data, at+4, true)) }
        func packedVersion(_ value: UInt32) -> String { "\(value >> 16).\((value >> 8) & 255).\(value & 255)" }
        func slice(_ offset: UInt64, _ size: UInt64) throws -> Slice? {
            guard size >= 32 else { throw IPAInstallIssue.incompatible }
            let header = try read(offset, 32)
            guard u32(header, 0) == 0xfeedfacf else { return nil }
            let commands = Int(u32(header, 16)), bytes = Int(u32(header, 20))
            guard commands <= 65536, bytes <= 16 * 1024 * 1024, UInt64(bytes) <= size - 32 else { throw IPAInstallIssue.incompatible }
            let data = try read(offset+32, bytes)
            var cursor = 0, encrypted = false, minimum: String?, platform: UInt32?
            for _ in 0..<commands {
                guard cursor <= data.count-8 else { throw IPAInstallIssue.incompatible }
                let command = u32(data, cursor), count = Int(u32(data, cursor+4))
                guard count >= 8, count <= data.count-cursor else { throw IPAInstallIssue.incompatible }
                if command == 0x2c || command == 0x21 {
                    guard count >= (command == 0x2c ? 24 : 20) else { throw IPAInstallIssue.incompatible }
                    encrypted = encrypted || u32(data, cursor+16) != 0
                }
                if command == 0x32 {
                    guard count >= 24 else { throw IPAInstallIssue.incompatible }
                    platform = u32(data, cursor+8); minimum = packedVersion(u32(data, cursor+12))
                } else if command == 0x25 {
                    guard count >= 16 else { throw IPAInstallIssue.incompatible }
                    platform = 2; minimum = packedVersion(u32(data, cursor+8))
                } else if [UInt32(0x24), 0x2f, 0x30].contains(command) {
                    guard count >= 16 else { throw IPAInstallIssue.incompatible }
                    platform = command == 0x24 ? 1 : (command == 0x2f ? 3 : 4)
                    minimum = packedVersion(u32(data, cursor+8))
                }
                cursor += count
            }
            guard cursor == data.count else { throw IPAInstallIssue.incompatible }
            return Slice(cpu: u32(header, 4), subtype: u32(header, 8), encrypted: encrypted, minimumOS: minimum, platform: platform, fileType: u32(header, 12))
        }
        let first = try read(0, min(8, Int(length)))
        guard first.count == 8 else { throw IPAInstallIssue.incompatible }
        let magic = u32(first, 0, true)
        if magic == 0xcafebabe || magic == 0xcafebabf {
            let wide = magic == 0xcafebabf, count = Int(u32(first, 4, true))
            guard count > 0, count <= 64 else { throw IPAInstallIssue.incompatible }
            let table = try read(8, count * (wide ? 32 : 20))
            var slices: [Slice] = []
            for index in 0..<count {
                let start = index * (wide ? 32 : 20)
                let offset = wide ? u64(table, start+8) : UInt64(u32(table, start+8, true))
                let size = wide ? u64(table, start+16) : UInt64(u32(table, start+12, true))
                guard offset <= length, size <= length-offset else { throw IPAInstallIssue.incompatible }
                if let value = try slice(offset, size) { slices.append(value) }
            }
            return slices
        }
        return try slice(0, length).map { [$0] } ?? []
    }
    static func validate(_ url: URL, currentOS: String, executable: Bool) throws {
        let slices = try inspect(url)
        guard let arm = slices.first(where: { $0.cpu == 0x0100000c && ($0.subtype & 0x00ffffff) == 0 }),
              arm.fileType == (executable ? 2 : 6), arm.platform == nil || arm.platform == 2 else {
            throw IPAInstallIssue(title: "Unsupported App Build", message: "This download does not contain a standard arm64 iPhone build. Choose a 64-bit iOS edition from the publisher. Simulator and 32-bit builds cannot run through this installation mode.", action: .compatibleBuild)
        }
        if arm.encrypted { throw IPAInstallIssue(title: "Protected App Build", message: "This binary is encrypted and cannot be re-signed for IPAStore. Use an unencrypted build provided or authorized by its developer.", action: .compatibleBuild) }
        if let issue = IPACompatibility.issue(minimum: arm.minimumOS, maximum: nil, current: currentOS) { throw issue }
    }
}
