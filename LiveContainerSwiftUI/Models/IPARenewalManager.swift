import Foundation
import SwiftUI
import UIKit
import BackgroundTasks
import UserNotifications
#if canImport(SideStoreSupport)
import SideStoreSupport
#endif

private final class IPABackgroundResult: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false
    var isCompleted: Bool { lock.lock(); defer { lock.unlock() }; return completed }
    func finish(_ task: BGTask, success: Bool) {
        lock.lock(); defer { lock.unlock() }
        guard !completed else { return }; completed = true
        task.setTaskCompleted(success: success)
    }
}

@MainActor final class IPARenewalManager: ObservableObject {
    static let shared = IPARenewalManager()
    @Published private(set) var automatic: Bool
    @Published private(set) var remindersEnabled: Bool
    @Published private(set) var profile: IPAProvisioningMetadata?
    @Published private(set) var lastAttempt: Date?
    @Published private(set) var lastSuccess: Date?
    @Published private(set) var lastFailure: String?
    @Published private(set) var working = false
    @Published private(set) var schedulingIssue: String?
    @Published private(set) var updatingReminders = false
    @Published private(set) var reminderIssue: String?
    @Published private(set) var reminderPermissionDenied = false
    private let defaults = UserDefaults.standard
    private var registered = false
    private let reminderIdentifier = "IPAStore.SignatureExpiry"
    var setupReady: Bool {
        let state = IPASigningState()
        return defaults.string(forKey: "IPAInstallMode") != "independent" && !IPASigningState.certificateCheckRunning && !defaults.bool(forKey: "IPASigningSetupOpen") && state.serviceAvailable && state.capabilitiesReady && state.freeSetupComplete
    }
    var decision: IPARenewalPolicy.Decision {
        IPARenewalPolicy.decide(automatic: automatic, ready: setupReady, profile: profile, lastAttempt: lastAttempt, now: Date())
    }
    var status: String {
        if working { return "Signing in progress" }
        switch decision {
        case .manual: return "Sign when you choose"
        case .setupRequired: return "Complete signing setup"
        case .expirationUnknown: return "Signature expiration unavailable"
        case .waiting: return "Automatic renewal is ready"
        case .retryAfter: return lastFailure == nil ? "Waiting for the next check" : "Will retry when conditions allow"
        case .due: return "Renewal is due"
        }
    }
    private init() {
        automatic = defaults.object(forKey: "IPAAutomaticRenewal") as? Bool ?? true
        remindersEnabled = defaults.bool(forKey: "IPARenewalReminders")
        lastAttempt = defaults.object(forKey: "IPARenewalLastAttempt") as? Date
        lastSuccess = defaults.object(forKey: "IPARenewalLastSuccess") as? Date
        lastFailure = defaults.string(forKey: "IPARenewalLastFailure")
        reloadProfile()
        if defaults.bool(forKey: "IPARenewalInProgress") {
            lastFailure = "The previous signing attempt didn’t finish. Check your setup and try again."
            defaults.set(lastFailure, forKey: "IPARenewalLastFailure")
            defaults.set(false, forKey: "IPARenewalInProgress")
        }
    }
    func registerBackgroundTask() {
        #if !IPASTORE_PREVIEW
        guard !registered else { return }
        registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: IPARenewalPolicy.taskIdentifier, using: nil) { task in
            let result = IPABackgroundResult()
            task.expirationHandler = {
                result.finish(task, success: false)
                Task { @MainActor in
                    let manager = IPARenewalManager.shared
                    #if canImport(SideStoreSupport)
                    cancelIPAStoreRefresh()
                    #endif
                    manager.lastFailure = "iOS ended this background attempt before it finished. Open IPAStore to try again."
                    manager.defaults.set(manager.lastFailure, forKey: "IPARenewalLastFailure")
                }
            }
            Task { @MainActor in
                guard !result.isCompleted else { return }
                let manager = IPARenewalManager.shared
                manager.reloadProfile()
                let success: Bool
                if manager.decision == .due { success = await manager.signNow() }
                else { success = true }
                manager.schedule()
                result.finish(task, success: success)
            }
        }
        if !registered { schedulingIssue = "Background renewal couldn’t be registered. Manual signing is still available." }
        schedule()
        #endif
    }
    func setAutomatic(_ enabled: Bool) {
        guard !enabled || setupReady else { return }
        automatic = enabled; defaults.set(enabled, forKey: "IPAAutomaticRenewal")
        schedule()
    }
    func becameActive() async {
        await IPASigningState.restoreAfterUpdateIfNeeded()
        reloadProfile()
        schedule()
        if decision == .due { _ = await signNow() }
    }
    func reloadProfile() {
        #if !IPASTORE_PREVIEW
        if let file = UserDefaults.lcMainBundle().url(forResource: "embedded", withExtension: "mobileprovision"), let data = try? Data(contentsOf: file) { profile = IPAProvisioningMetadata.read(from: data) }
        else { profile = nil }
        #else
        profile = nil
        #endif
    }
    @discardableResult func signNow() async -> Bool {
        guard !working else { return false }
        guard setupReady else { lastFailure = "Complete Signing Setup before signing iPAStore."; return false }
        working = true
        lastAttempt = Date(); defaults.set(lastAttempt, forKey: "IPARenewalLastAttempt")
        defaults.set(true, forKey: "IPARenewalInProgress")
        defer { working = false; defaults.set(false, forKey: "IPARenewalInProgress"); schedule() }
        #if canImport(SideStoreSupport) && !IPASTORE_PREVIEW
        do {
            _ = try await RefreshAllAppsIntent().perform()
            lastSuccess = Date(); lastFailure = nil
            defaults.set(lastSuccess, forKey: "IPARenewalLastSuccess")
            defaults.removeObject(forKey: "IPARenewalLastFailure")
            reloadProfile()
            IPAFeedback.success()
            return true
        } catch {
            // Persist an actionable summary, not raw account/device data from engine errors.
            let failure = error as NSError
            lastFailure = failure.domain == "IPAStore.Signing" ? failure.localizedDescription : "Signing couldn’t finish. Check your local connection, pairing file and signing account, then try again."
            defaults.set(lastFailure, forKey: "IPARenewalLastFailure")
            return false
        }
        #else
        lastFailure = "Signing is available in the iPhone build."
        return false
        #endif
    }
    func schedule() {
        if remindersEnabled { Task { await scheduleReminder() } }
        #if !IPASTORE_PREVIEW
        guard registered else { return }
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: IPARenewalPolicy.taskIdentifier)
        guard automatic else { schedulingIssue = nil; return }
        let earliest: Date
        switch decision {
        case .waiting(let date): earliest = date
        case .retryAfter(let date): earliest = date
        case .due: earliest = Date().addingTimeInterval(15 * 60)
        default: return
        }
        let request = BGProcessingTaskRequest(identifier: IPARenewalPolicy.taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = earliest
        do { try BGTaskScheduler.shared.submit(request); schedulingIssue = nil }
        catch { schedulingIssue = "iOS hasn’t accepted background renewal. Open IPAStore before expiry to sign manually." }
        #endif
    }
    func setReminders(_ enabled: Bool) async {
        guard !updatingReminders, !enabled || setupReady else { return }
        updatingReminders = true; defer { updatingReminders = false }
        reminderIssue = nil; reminderPermissionDenied = false
        if enabled {
            do {
                remindersEnabled = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                if !remindersEnabled {
                    reminderPermissionDenied = true
                    reminderIssue = "Notifications are turned off for iPAStore. Allow them in iPhone Settings, then enable this reminder again."
                }
            } catch {
                remindersEnabled = false
                reminderIssue = "iOS couldn’t request notification permission. Try again while iPAStore is open."
            }
        } else { remindersEnabled = false }
        defaults.set(remindersEnabled, forKey: "IPARenewalReminders")
        if remindersEnabled { await scheduleReminder() }
        else { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderIdentifier]) }
    }
    private func scheduleReminder() async {
        let center = UNUserNotificationCenter.current()
        guard remindersEnabled, setupReady else {
            center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier]); return
        }
        guard let profile else {
            reminderIssue = "The signature expiration is unavailable, so a reminder cannot be scheduled yet. Reinstall a signed iPAStore build to restore its provisioning information."
            return
        }
        guard profile.expiresAt > Date() else {
            reminderIssue = "This signature has already expired. Renew iPAStore now; the next reminder will use the new expiration."
            return
        }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            reminderPermissionDenied = true; reminderIssue = "Allow iPAStore notifications in iPhone Settings to receive expiry reminders."; return
        }
        let date = max(profile.expiresAt.addingTimeInterval(-24 * 3_600), Date().addingTimeInterval(60))
        let content = UNMutableNotificationContent()
        content.title = "Keep iPAStore ready"
        content.body = "Your signature expires soon. Open iPAStore to check renewal."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        do {
            // Replacing the same identifier is atomic; do not remove the old
            // reminder first, or a failed update silently loses it.
            try await center.add(UNNotificationRequest(identifier: reminderIdentifier, content: content, trigger: trigger))
            reminderIssue = nil; reminderPermissionDenied = false
        } catch { reminderIssue = "The reminder couldn’t be saved. Try turning it off and on again." }
    }
}
