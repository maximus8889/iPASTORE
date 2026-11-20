// Integration smoke checks for the actual upstream catalog decoder used by the storefront.
import Foundation

enum CatalogChecks {
    static func run() throws {
        let base = URL(string: "https://example.org/catalog/source.json")!
        let modern = Data("""
        {"name":"Test Store","apps":[{"name":"Example","bundleIdentifier":"test.example","category":"utilities","versions":[{"version":"2.0","downloadURL":"files/example.ipa","size":1024}]}]}
        """.utf8)
        let source = try AltStoreSourceLoader.decode(from: modern, baseURL: base)
        precondition(source.apps.count == 1, "Modern catalog must expose its app")
        precondition(source.apps[0].latestVersion?.version == "2.0", "Version must survive decoding")
        precondition(source.apps[0].latestVersion?.downloadURL.absoluteString == "https://example.org/catalog/files/example.ipa", "Resolve downloads against the source URL")
        precondition(source.apps[0].category == "utilities", "Decode a single category")
        let legacy = Data("""
        {"name":"Legacy","apps":[{"name":"Legacy App","bundleIdentifier":"test.legacy","category":["games","entertainment"],"version":"1.0","downloadURL":"https://example.org/app.ipa"}]}
        """.utf8)
        let old = try AltStoreSourceLoader.decode(from: legacy, baseURL: base)
        precondition(old.apps.first?.latestVersion?.version == "1.0", "Legacy feeds must remain supported")
        precondition(old.apps.first?.category == "games", "Accept category arrays")
        let repeated = try AltStoreSourceLoader.decode(from: legacy, baseURL: base)
        precondition(old.apps.first?.id == repeated.apps.first?.id, "Stable identity across refreshes")
        do {
            _ = try AltStoreSourceLoader.decode(from: Data("{\"apps\":[]}".utf8), baseURL: base)
            preconditionFailure("Malformed sources must fail")
        } catch { /* expected */ }
        let empty = try AltStoreSourceLoader.decode(from: Data("{\"name\":\"Empty\",\"apps\":[]}".utf8), baseURL: base)
        precondition(empty.apps.isEmpty, "Empty catalogs must not fabricate entries")
        let report = "Catalog decoder: modern feed, relative download URL, legacy feed, malformed feed, empty feed, flexible categories, stable identity — PASS\n"
        let output = ProcessInfo.processInfo.environment["IPASTORE_CHECK_REPORT"].map { URL(fileURLWithPath: $0) } ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("catalog-checks.txt")
        try report.write(to: output, atomically: true, encoding: .utf8)
    }
}
