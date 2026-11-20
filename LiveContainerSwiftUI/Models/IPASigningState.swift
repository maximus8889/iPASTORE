// IPAStore account bridge. Authentication and installation stay in the signing service.
import Foundation
import SwiftUI
import Security
import CryptoKit
import UIKit
import UniformTypeIdentifiers

@MainActor
final class IPASigningState: ObservableObject {
    @Published private(set) var serviceAvailable = false
    @Published private(set) var capabilitiesReady = false
    @Published private(set) var accountSaved = false
    @Published private(set) var pairingImported = false
    @Published private(set) var connectionCheckedAt: Date?
    @Published private(set) var containerCertificateAvailable = false
    @Published private(set) var certificateImported = false
    @Published private(set) var certificateProblem: String?
    @Published private(set) var standaloneCertificateReady = false
    @Published private(set) var profileSummary: String?
    @Published private(set) var profileProblem: String?
    var freeSetupComplete: Bool { serviceAvailable && capabilitiesReady && accountSaved && pairingImported && connectionCheckedAt != nil }
    private static var recovery: Task<Void, Never>?
    private static var attemptedRecovery: String?
    private static var attemptedRecoveryAt = Date.distantPast
    static func restoreAfterUpdateIfNeeded() async {
        await Task.yield()
        if let recovery { await recovery.value; return }
        for _ in 0..<200 where verifying && !Task.isCancelled { try? await Task.sleep(for: .milliseconds(20)) }
        guard !verifying, !IPAInstallCoordinator.shared.busy, !IPARenewalManager.shared.working,
              !UserDefaults.standard.bool(forKey: "IPASigningCertificateRemoved") else { return }
        let state = IPASigningState()
        state.reload()
        guard !verifying else { return }
        #if !IPASTORE_PREVIEW
        let accountOrigin = UserDefaults.standard.string(forKey: "IPACertificateOrigin") == "account"
        if state.freeSetupComplete && (accountOrigin || !state.certificateImported),
           let data = state.readItem("signingCertificate") {
            let password = state.readItem("signingCertificatePassword").flatMap({ String(data: $0, encoding: .utf8) }) ?? ""
            guard LCUtils.getCertTeamId(withKeyData: data, password: password) != nil else { return }
            storeCertificate(data, password: password, origin: "account"); state.reload()
        }
        guard !state.containerCertificateAvailable,
              state.freeSetupComplete || UserDefaults.standard.string(forKey: "IPAVerifiedCertificate") != nil,
              let digest = certificateDigest(), attemptedRecovery != digest || Date().timeIntervalSince(attemptedRecoveryAt) >= 15 else { return }
        attemptedRecovery = digest; attemptedRecoveryAt = Date()
        let task = Task { await state.verifyCertificate(feedback: false) }
        recovery = task; await task.value; recovery = nil
        #endif
    }
    func removeCertificate() {
        #if !IPASTORE_PREVIEW
        guard !busy, !IPAInstallCoordinator.shared.busy, !IPARenewalManager.shared.working else { return }
        for key in ["LCCertificateData", "LCCertificatePassword", "LCCertificateUpdateDate"] {
            LCUtils.appGroupUserDefault.removeObject(forKey: key); UserDefaults.standard.removeObject(forKey: key)
        }
        #endif
        for key in ["IPAVerifiedCertificate", "IPACertificateOrigin", "IPACompleteSigningSetup"] { UserDefaults.standard.removeObject(forKey: key) }
        UserDefaults.standard.set(true, forKey: "IPASigningCertificateRemoved")
        Self.attemptedRecovery = nil; reload()
    }
    func removeProfile() {
        guard !busy, !IPAInstallCoordinator.shared.busy, !IPARenewalManager.shared.working else { return }
        let file = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Signing/Standalone.mobileprovision")
        do { if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }; reload() }
        catch { message = error.localizedDescription }
    }
    static var savedProfile: Data? {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Signing/Standalone.mobileprovision")
        return try? Data(contentsOf: url)
    }
    static func storeProfile(_ data: Data) throws {
        #if !IPASTORE_PREVIEW
        _ = try LCUtils.standaloneProfileInfo(data)
        #endif
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Signing/Standalone.mobileprovision")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        var directory = url.deletingLastPathComponent(); try directory.setResourceValues(values)
    }
    @Published private(set) var busy = false
    @Published var message: String?

    private static var verifying = false
    private static var capabilitiesCache: Bool?
    static var certificateCheckRunning: Bool { verifying }
    init() { reload() }

    func reload() {
        #if !IPASTORE_PREVIEW
        serviceAvailable = UserDefaults.sideStoreExist()
        if let cached = Self.capabilitiesCache { capabilitiesReady = cached }
        else {
        let task = SecTaskCreateFromSelf(nil)
        let groups = SecTaskCopyValueForEntitlement(task, "keychain-access-groups" as CFString, nil)?.takeRetainedValue() as? [String] ?? []
        if let team = LCSharedUtils.teamIdentifier() {
            let groupSet = Set(groups)
            let base = "\(team).com.kdt.livecontainer.shared"
            capabilitiesReady = groupSet.contains(base) && (1..<128).allSatisfy { groupSet.contains("\(base).\($0)") }
        } else { capabilitiesReady = false }
            Self.capabilitiesCache = capabilitiesReady
        }
        accountSaved = serviceAvailable && capabilitiesReady && readItem("appleIDEmailAddress") != nil
        let readiness = UserDefaults.standard.dictionary(forKey: "IPASigningReadiness") ?? [:]
        pairingImported = readiness["pairingImported"] as? Bool ?? false
        connectionCheckedAt = readiness["connectionCheckedAt"] as? Date
        if let dates = LCUtils.certificateDates(), let start = dates["notBefore"], let end = dates["notAfter"] {
            certificateImported = true
            let inDate = start <= Date() && end > Date()
            containerCertificateAvailable = inDate && !Self.verifying && Self.certificateDigest() == UserDefaults.standard.string(forKey: "IPAVerifiedCertificate")
            certificateProblem = !inDate ? "This certificate has expired or is not valid yet. Import a current certificate with its private key." : containerCertificateAvailable ? nil : "Verify this certificate on your iPhone before installing or opening apps. A readable certificate may still be rejected by iOS."
        } else {
            certificateImported = false; containerCertificateAvailable = false
            certificateProblem = "Add an Apple Account certificate or import a .p12 file with its password to sign apps inside iPAStore."
        }
        standaloneCertificateReady = false; profileSummary = nil; profileProblem = nil
        if let profile = Self.savedProfile {
            do {
                let info = try LCUtils.standaloneProfileInfo(profile)
                let entitlement = info["Entitlements"] as? [String: Any] ?? [:]
                let identifier = entitlement["application-identifier"] as? String ?? "Unknown app"
                let name = info["Name"] as? String ?? "Provisioning Profile"
                profileSummary = "\(name) · \(identifier)"
                standaloneCertificateReady = certificateImported && (LCUtils.certificateDates()?["notAfter"] ?? .distantPast) > Date()
            } catch { profileProblem = error.localizedDescription }
        }
        #else
        serviceAvailable = false
        capabilitiesReady = false
        accountSaved = false
        pairingImported = false
        connectionCheckedAt = nil
        containerCertificateAvailable = false
        #endif
    }

    func importInteractiveReadiness(allowCertificateImport: Bool = false) {
        #if !IPASTORE_PREVIEW
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let readiness = IPASigningSetupHandoff.consume(hostDocuments: documents) else { return }
        UserDefaults.standard.set(readiness.propertyList, forKey: "IPASigningReadiness")
        if readiness.accountStored && readiness.certificateAvailable && (allowCertificateImport || !UserDefaults.standard.bool(forKey: "IPASigningCertificateRemoved")) { importServiceCertificate(feedback: false) }
        #endif
    }

    static func completePendingSetup() {
        guard UserDefaults.standard.bool(forKey: "IPACompleteSigningSetup") else { return }
        let state = IPASigningState()
        state.importServiceCertificate(feedback: false)
        if state.containerCertificateAvailable { UserDefaults.standard.removeObject(forKey: "IPACompleteSigningSetup") }
    }

    func importServiceCertificate(feedback: Bool = true) {
        #if !IPASTORE_PREVIEW
        guard serviceAvailable, capabilitiesReady, let data = readItem("signingCertificate") else {
            message = "No certificate is available yet. Connect your signing account and sign iPAStore, then try again."
            return
        }
        let password = readItem("signingCertificatePassword").flatMap { String(data: $0, encoding: .utf8) } ?? ""
        guard LCUtils.getCertTeamId(withKeyData: data, password: password) != nil else {
            message = "The certificate could not be opened. Sign in again and try importing it once more."
            return
        }
        Self.storeCertificate(data, password: password, origin: "account")
        Task { await verifyCertificate(feedback: feedback) }
        #else
        message = "Certificate import requires the device build."
        #endif
    }

    #if !IPASTORE_PREVIEW
    private static func certificateDigest() -> String? {
        guard let data = LCUtils.certificateData() else { return nil }
        var digest = SHA256(); digest.update(data: data)
        if let profile = UserDefaults.lcMainBundle().url(forResource: "embedded", withExtension: "mobileprovision"), let data = try? Data(contentsOf: profile) { digest.update(data: data) }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
    static func storeCertificate(_ data: Data, password: String, origin: String) {
        let unchanged = LCUtils.certificateData() == data && LCSharedUtils.certificatePassword() == password
        LCUtils.appGroupUserDefault.set(data, forKey: "LCCertificateData")
        // The launch path also reads the host defaults when no shared suite exists.
        LCUtils.setCertificatePassword(password)
        LCUtils.appGroupUserDefault.set(Date(), forKey: "LCCertificateUpdateDate")
        UserDefaults.standard.set(origin, forKey: "IPACertificateOrigin")
        UserDefaults.standard.removeObject(forKey: "IPASigningCertificateRemoved")
        UserDefaults.standard.set(LCSharedUtils.appGroupID(), forKey: "LCAppGroupID")
        if !unchanged { UserDefaults.standard.removeObject(forKey: "IPAVerifiedCertificate") }
    }
    #endif

    func verifyCertificate(feedback: Bool = true) async {
        guard !busy, !Self.verifying else { return }
        guard !IPAInstallCoordinator.shared.busy, !IPARenewalManager.shared.working else {
            message = "Wait for the current signing or installation to finish before verifying a certificate."; return
        }
        Self.verifying = true
        busy = true; defer { Self.verifying = false; busy = false; reload() }
        #if !IPASTORE_PREVIEW
        guard let dates = LCUtils.certificateDates(), let start = dates["notBefore"], let end = dates["notAfter"], start <= Date(), end > Date(), let digest = Self.certificateDigest() else {
            message = "The certificate is missing, expired or cannot be opened. Import a current .p12 containing its private key and check its password."; return
        }
        let result: (Bool, NSError?) = await withCheckedContinuation { reply in
            LCUtils.validateJITLessSetup { success, error in reply.resume(returning: (success, error as NSError?)) }
        }
        if let error = result.1, error.domain == "iPAStore.Certificate" {
            UserDefaults.standard.removeObject(forKey: "IPAVerifiedCertificate")
            message = error.localizedDescription
            return
        }
        let accepted = result.0
        // Never mark a different certificate ready if it changed during the check.
        if accepted && digest == Self.certificateDigest() {
            UserDefaults.standard.set(digest, forKey: "IPAVerifiedCertificate")
            if feedback { IPAFeedback.success() }
            message = "iOS accepted a test signature. You can now install apps inside iPAStore."
        } else {
            UserDefaults.standard.removeObject(forKey: "IPAVerifiedCertificate")
            message = "iOS did not accept this certificate for apps inside iPAStore. It may be revoked, lack a matching provisioning profile, or belong to a different signing setup. Use the certificate that signed iPAStore, or reinstall iPAStore with your certificate and its matching profile, then verify again. Importing a .p12 alone does not authorize apps to run."
        }
        #else
        message = "Certificate verification requires the iPhone build."
        #endif
    }

    #if !IPASTORE_PREVIEW
    private func readItem(_ account: String) -> Data? {
        // Same namespace as the embedded service's dynamically selected host identity.
        let service = UserDefaults.lcMainBundle().bundleIdentifier ?? Bundle.main.bundleIdentifier ?? "app.ipastore.IPAStore"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }
    #endif
}

struct IPACertificateImportView: View {
    let onImport: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var choosing = false
    @State private var data: Data?
    @State private var filename = "No File Selected"
    @State private var password = ""
    @State private var failure: String?
    @FocusState private var passwordFocused: Bool
    init(initialData: Data? = nil, onImport: @escaping () -> Void = {}) {
        self.onImport = onImport
        _data = State(initialValue: initialData)
        _filename = State(initialValue: initialData == nil ? "No File Selected" : "Imported Certificate.p12")
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button(filename) { choosing = true }
                    SecureField("Certificate Password", text: $password).focused($passwordFocused).textContentType(.password)
                } header: { Text("Certificate") } footer: { Text("Choose a .p12 containing its private key. For standalone iPhone apps, add its matching provisioning profile after importing. For apps inside iPAStore, use the certificate that signed iPAStore. Import does not change iPAStore’s own signature.") }
                if let failure { Section { Text(failure).foregroundStyle(.secondary) } }
            }.navigationTitle("Add Certificate").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add") { save() }.disabled(data == nil) }
            }
            .onAppear { passwordFocused = data != nil }
            .fileImporter(isPresented: $choosing, allowedContentTypes: [UTType(filenameExtension: "p12") ?? .data]) { result in
                do {
                    let url = try result.get()
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size > 0, size <= 2 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
                    data = try Data(contentsOf: url)
                    filename = url.lastPathComponent
                    failure = nil; passwordFocused = true
                } catch { failure = error.localizedDescription.ipaDisplayMessage }
            }
        }
    }
    private func save() {
        #if !IPASTORE_PREVIEW
        guard let data, LCUtils.getCertTeamId(withKeyData: data, password: password) != nil else {
            failure = "Unable to open the certificate. Check the file and password."
            return
        }
        IPASigningState.storeCertificate(data, password: password, origin: "file")
        onImport()
        dismiss()
        #else
        failure = "Certificate import is available on your iPhone."
        #endif
    }
}
