import Foundation

struct IPASigningSetupReadiness: Equatable {
    let pairingImported: Bool
    let accountStored: Bool
    let certificateAvailable: Bool
    let connectionCheckedAt: Date?
    var propertyList: [String: Any] {
        var value: [String: Any] = ["pairingImported": pairingImported, "accountStored": accountStored, "certificateAvailable": certificateAvailable]
        if let date = connectionCheckedAt { value["connectionCheckedAt"] = date }
        return value
    }
}

enum IPASigningSetupHandoff {
    static func consumeCertificate(hostDocuments: URL) -> Data? {
        let file = hostDocuments.appendingPathComponent("SideStore/Documents/IPAStoreCertificateImport.p12")
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        defer { try? FileManager.default.removeItem(at: file) }
        guard let values = try? file.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey, .isRegularFileKey]),
              values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size > 0, size <= 2 * 1024 * 1024,
              let data = try? Data(contentsOf: file), data.count <= 2 * 1024 * 1024 else { return nil }
        return data
    }

    static func consume(hostDocuments: URL) -> IPASigningSetupReadiness? {
        // The signing process HOME is host Documents/SideStore. Its document
        // directory therefore adds another Documents component. Keep the old
        // location as a migration fallback, never as the primary contract.
        for relative in ["SideStore/Documents/IPAStoreSetupStatus.plist", "SideStore/IPAStoreSetupStatus.plist"] {
            let file = hostDocuments.appendingPathComponent(relative)
            guard let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0, size < 4096,
                  let data = try? Data(contentsOf: file), data.count < 4096,
                  let value = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  let pairing = value["pairingImported"] as? Bool,
                  let account = value["accountStored"] as? Bool,
                  let certificate = value["certificateAvailable"] as? Bool else { continue }
            let readiness = IPASigningSetupReadiness(pairingImported: pairing, accountStored: account, certificateAvailable: certificate, connectionCheckedAt: value["connectionCheckedAt"] as? Date)
            try? FileManager.default.removeItem(at: file)
            return readiness
        }
        return nil
    }
}
