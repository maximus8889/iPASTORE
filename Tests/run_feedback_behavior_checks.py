"""Exercise actual feedback scheduling against instrumented UIKit/audio boundaries."""
from pathlib import Path
import subprocess, tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'LiveContainerSwiftUI/Models/IPAFeedback.swift').read_text().replace('import UIKit','import Foundation\nimport CoreFoundation').replace('import AudioToolbox','').replace('UserDefaults.standard', 'FeedbackTestDefaults.standard')
stubs='''
@MainActor final class FeedbackTestDefaults {
 static let standard = FeedbackTestDefaults()
 private var values: [String: Any] = [:]
 func object(forKey key: String) -> Any? { values[key] }
 func set(_ value: Bool, forKey key: String) { values[key] = value }
}
typealias SystemSoundID = UInt32
@MainActor enum Calls {
 static var events: [String] = []
}
@MainActor final class UIApplication {
 enum State { case active, background }
 static let shared = UIApplication()
 var applicationState: State = .active
}
@MainActor final class UIImpactFeedbackGenerator {
 enum Style { case soft, rigid }
 let style: Style
 init(style: Style) { self.style = style }
 func prepare() {}
 func impactOccurred(intensity: Double) { Calls.events.append(style == .soft ? "lift" : "settle") }
}
@MainActor final class UINotificationFeedbackGenerator {
 enum Feedback { case success }
 func notificationOccurred(_ value: Feedback) { Calls.events.append("success") }
}
@MainActor func AudioServicesCreateSystemSoundID(_ url: CFURL, _ sound: UnsafeMutablePointer<SystemSoundID>) -> Int32 { sound.pointee = 1; return 0 }
@MainActor func AudioServicesPlaySystemSound(_ sound: SystemSoundID) { Calls.events.append("sound") }
'''
runner='''
@main struct Check {
 @MainActor static func main() async throws {
  let defaults = FeedbackTestDefaults.standard
  defaults.set(true, forKey: "IPAHapticsEnabled"); defaults.set(true, forKey: "IPASoundsEnabled")
  IPAFeedback.appWillOpen(); assert(Calls.events == ["lift"])
  try await Task.sleep(for: .milliseconds(90)); assert(Calls.events == ["lift", "settle"])
  Calls.events = []; IPAFeedback.appWillOpen(); IPAFeedback.appWillOpen()
  try await Task.sleep(for: .milliseconds(90)); assert(Calls.events == ["lift", "lift", "settle"])
  Calls.events = []; IPAFeedback.appWillOpen(); UIApplication.shared.applicationState = .background
  try await Task.sleep(for: .milliseconds(90)); assert(Calls.events == ["lift"])
  Calls.events = []; IPAFeedback.appWillOpen(); IPAFeedback.success(); assert(Calls.events.isEmpty)
  UIApplication.shared.applicationState = .active
  IPAFeedback.appWillOpen(); defaults.set(false, forKey: "IPAHapticsEnabled")
  try await Task.sleep(for: .milliseconds(90)); assert(Calls.events == ["lift"])
  Calls.events = []; IPAFeedback.appWillOpen(); assert(Calls.events.isEmpty)
  IPAFeedback.success(); assert(Calls.events == ["sound"])
  IPAFeedback.success(); assert(Calls.events == ["sound"])
  try await Task.sleep(for: .milliseconds(400))
  Calls.events = []; defaults.set(true, forKey: "IPAHapticsEnabled"); defaults.set(false, forKey: "IPASoundsEnabled")
  IPAFeedback.success(); assert(Calls.events == ["success"])
  try await Task.sleep(for: .milliseconds(400))
  Calls.events = []; defaults.set(true, forKey: "IPASoundsEnabled")
  IPAFeedback.appWillOpen(); IPAFeedback.success()
  try await Task.sleep(for: .milliseconds(90)); assert(Calls.events == ["lift", "success", "sound"])
  print("PASS: real feedback scheduling, cancellation, background/toggle suppression, independent controls and duplicate-success coalescing")
 }
}
'''
with tempfile.TemporaryDirectory(prefix='ipastore-feedback-') as temp:
 folder=Path(temp); (folder/'Success.wav').write_bytes((root/'Resources/Success.wav').read_bytes())
 (folder/'Check.swift').write_text(source+'\n'+stubs+'\n'+runner)
 subprocess.run(['swiftc',str(folder/'Check.swift'),'-parse-as-library','-module-cache-path',str(folder/'ModuleCache'),'-o',str(folder/'check')],check=True)
 subprocess.run([str(folder/'check')],check=True)
