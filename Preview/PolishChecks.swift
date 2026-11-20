// Simulator-only integration checks against the actual native tab coordinator.
// Runs inside the preview; no OS input events, credentials or phone data.
import SwiftUI
import UIKit

enum PolishChecks {
    @MainActor static func run() async {
        let file = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("polish-checks.json")
        var report: [String: Any] = [:]
        var cleanup: (() -> Void)?
        let savedAccent = UserDefaults.standard.object(forKey: "IPAAccentHex")
        defer {
            cleanup?()
            if let savedAccent { UserDefaults.standard.set(savedAccent, forKey: "IPAAccentHex") } else { UserDefaults.standard.removeObject(forKey: "IPAAccentHex") }
        }
        func require(_ value: Bool, _ message: String) throws {
            if !value { throw NSError(domain: "iPAStore.PreviewCheck", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        @MainActor func settle(_ coordinator: IPATabPager.Coordinator) async throws {
            let deadline = Date().addingTimeInterval(4)
            while coordinator.transitionInProgress && Date() < deadline { try await Task.sleep(for: .milliseconds(40)) }
            try require(!coordinator.transitionInProgress, "Tab transition did not settle")
            await Task.yield()
        }
        func find(_ root: UIViewController) -> UITabBarController? {
            if let tabs = root as? UITabBarController { return tabs }
            for child in root.children { if let found = find(child) { return found } }
            return nil
        }
        do {
            for name in ["Library-hub-yattee", "Library-hub-kodi-ios", "Library-hub-nineanimator", "Library-hub-bringyour", "Library-hub-wayfarer", "Library-hub-burrito-source", "Library-hub-winston"] {
                try require(UIImage(named: name).map { $0.size.width > 0 && $0.size.height > 0 } == true, "Bundled library icon failed: \(name)")
            }
            report["recovered_library_icons"] = "PASS (7)"
            for orientation in [UIInterfaceOrientation.portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight] {
                let bounds = orientation.isLandscape ? CGRect(x: 0, y: 0, width: 852, height: 393) : CGRect(x: 0, y: 0, width: 393, height: 852)
                let scene = IPAGuestGeometry.sceneFrame(in: bounds, orientation: orientation)
                let rendered = orientation.isLandscape ? CGSize(width: scene.height, height: scene.width) : scene.size
                try require(rendered == bounds.size, "Guest scene was cropped or swapped twice")
            }
            report["guest_orientation_geometry"] = "PASS (4)"
            let documents = file.deletingLastPathComponent()
            let archive = documents.appendingPathComponent("archive-input.ipa")
            if FileManager.default.fileExists(atPath: archive.path) {
                let destination = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("ArchiveRuntime-\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
                defer { try? FileManager.default.removeItem(at: destination) }
                let result = await Task.detached { extract(archive.path, destination.path, Progress(totalUnitCount: 0)) }.value
                report["ios_archive_result"] = result
                try require(result == 0, "iOS extractor rejected real compressed IPA: \(result)")
            }
            try await Task.sleep(for: .milliseconds(800))
            let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
            guard let root = windows.first(where: \.isKeyWindow)?.rootViewController,
                  let tabs = find(root), let coordinator = tabs.delegate as? IPATabPager.Coordinator else {
                throw NSError(domain: "iPAStore.PreviewCheck", code: 2, userInfo: [NSLocalizedDescriptionKey: "Native tab coordinator not found"])
            }
            report["loaded_roots_before_interaction"] = coordinator.hosts.filter { $0.isViewLoaded }.count
            let original = coordinator.selectedIndex
            cleanup = { coordinator.endInteractive(distance: 0, velocity: 0, cancelled: true); coordinator.selection.wrappedValue = IPATabPager.order[original] }
            let direction = original == 4 ? -1 : 1
            let target = original + direction
            let width = tabs.view.bounds.width
            try require(width > 0, "Tab content has no layout")
            try require(coordinator.beginInteractive(direction: direction), "Interactive transition did not start")
            try await Task.sleep(for: .milliseconds(120))
            if !UIAccessibility.isReduceMotionEnabled {
                coordinator.updateInteractive(distance: -CGFloat(direction) * width * 0.45)
                try await Task.sleep(for: .milliseconds(100))
                report["events"] = coordinator.diagnosticEvents
                report["progress"] = coordinator.interactiveProgress.map(Double.init) ?? NSNull()
                report["selected"] = coordinator.selectedIndex
                let presentation = coordinator.interactiveVisualOffset
                report["mid_drag_translation"] = presentation.map(Double.init) ?? NSNull()
                try require(presentation.map { abs($0) > 1 && abs($0) < width - 1 } == true, "Adjacent page was not visibly between its start and end positions")
                coordinator.endInteractive(distance: -CGFloat(direction) * width * 0.1, velocity: 0, cancelled: true)
                try await settle(coordinator)
                try require(coordinator.selectedIndex == original && coordinator.selection.wrappedValue == IPATabPager.order[original], "Cancelled transition lost selected tab")
                report["interactive_cancel"] = "PASS"
            } else { coordinator.endInteractive(distance: 0, velocity: 0, cancelled: true) }
            try require(coordinator.beginInteractive(direction: direction), "Second transition could not start")
            try await Task.sleep(for: .milliseconds(80))
            coordinator.updateInteractive(distance: -CGFloat(direction) * width * 0.65)
            coordinator.endInteractive(distance: -CGFloat(direction) * width * 0.65, velocity: -CGFloat(direction) * 400)
            try await settle(coordinator)
            try require(coordinator.selectedIndex == target && coordinator.selection.wrappedValue == IPATabPager.order[target], "Completed swipe did not update native and app selection together")
            report["interactive_commit"] = "PASS"
            try require(coordinator.beginInteractive(direction: -direction), "Reverse swipe could not start")
            try await Task.sleep(for: .milliseconds(80))
            coordinator.updateInteractive(distance: CGFloat(direction) * width * 0.6)
            coordinator.endInteractive(distance: CGFloat(direction) * width * 0.6, velocity: CGFloat(direction) * 400)
            try await settle(coordinator)
            try require(coordinator.selectedIndex == original && coordinator.selection.wrappedValue == IPATabPager.order[original], "Reverse swipe lost selection")
            report["interactive_reverse"] = "PASS"
            UserDefaults.standard.set("FF9500", forKey: "IPAAccentHex")
            try await Task.sleep(for: .milliseconds(350))
            let expected = UIColor(IPAAppearance.accent("FF9500"))
            try require(tabs.view.tintColor.isEqual(expected) && tabs.tabBar.tintColor.isEqual(expected), "Native tab tint did not update immediately")
            report["live_native_tint"] = "PASS"
            let blue = UIColor(IPAAppearance.accent("systemBlue"))
            for style in [UIUserInterfaceStyle.light, .dark] {
                let trait = UITraitCollection(userInterfaceStyle: style)
                try require(blue.resolvedColor(with: trait).isEqual(UIColor.systemBlue.resolvedColor(with: trait)), "Default blue lost its native appearance variant")
            }
            report["adaptive_blue"] = "PASS"
            coordinator.selection.wrappedValue = IPATabPager.order[original]
            coordinator.synchronize(index: original)
            report["status"] = "PASS"
        } catch { report["status"] = "FAIL"; report["reason"] = error.localizedDescription }
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: file, options: .atomic) }
    }
}
