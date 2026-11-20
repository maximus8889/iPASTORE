import UIKit
import AudioToolbox

@MainActor enum IPAFeedback {
    private static let lift = UIImpactFeedbackGenerator(style: .soft)
    private static let settle = UIImpactFeedbackGenerator(style: .rigid)
    private static let confirmation = UINotificationFeedbackGenerator()
    private static var launchTail: Task<Void, Never>?
    private static var successSound: SystemSoundID = 0
    private static var lastSuccess: TimeInterval = -.infinity
    private static var hapticsEnabled: Bool { UserDefaults.standard.object(forKey: "IPAHapticsEnabled") as? Bool ?? true }
    private static var soundsEnabled: Bool { UserDefaults.standard.object(forKey: "IPASoundsEnabled") as? Bool ?? true }
    static func appWillOpen() {
        launchTail?.cancel()
        guard UIApplication.shared.applicationState == .active, hapticsEnabled else { return }
        // A soft lift followed by a lighter, crisp landing. UIKit owns the
        // actuator; no engine/audio-session startup delays the app launch.
        settle.prepare()
        lift.impactOccurred(intensity: 0.58)
        launchTail = Task {
            do { try await Task.sleep(for: .milliseconds(55)) } catch { return }
            guard !Task.isCancelled, UIApplication.shared.applicationState == .active, hapticsEnabled else { return }
            settle.impactOccurred(intensity: 0.28)
        }
    }
    static func confirmationHaptic() {
        guard UIApplication.shared.applicationState == .active, hapticsEnabled else { return }
        confirmation.notificationOccurred(.success)
    }
    static func success() {
        guard UIApplication.shared.applicationState == .active else { return }
        // Coalesce simultaneous successful operations rather than stack tones.
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastSuccess >= 0.38 else { return }
        lastSuccess = now
        launchTail?.cancel()
        confirmationHaptic()
        guard soundsEnabled else { return }
        if successSound == 0, let url = Bundle.main.url(forResource: "Success", withExtension: "wav") {
            AudioServicesCreateSystemSoundID(url as CFURL, &successSound)
        }
        // System-sound playback follows the iPhone's silent/sound controls.
        // Do not change AVAudioSession or play success feedback in background.
        if successSound != 0 { AudioServicesPlaySystemSound(successSound) }
    }
}
