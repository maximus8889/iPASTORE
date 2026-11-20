import SwiftUI

// One navigation owner: UIKit renders Back and owns its swipe transition.
// No custom pan recognizers, gesture delegates or second floating Back button.
extension View {
    func ipaNativePage() -> some View {
        navigationBarBackButtonHidden(false)
            .toolbar(.visible, for: .navigationBar)
            .onAppear { IPANavigationChecks.recordIfEnabled() }
    }
}

enum IPANavigationChecks {
    @MainActor private static var ran = false
    private static let enabled = ProcessInfo.processInfo.arguments.contains("--ipa-navigation-diagnostics")
    private static let queue = DispatchQueue(label: "app.ipastore.navigation-diagnostics", qos: .utility)
    @MainActor private static func currentNavigation(_ root: UIViewController?) -> UINavigationController? {
        guard let root else { return nil }
        if let tabs = root as? UITabBarController { return currentNavigation(tabs.selectedViewController) }
        if let nav = root as? UINavigationController { return nav }
        for child in root.children.reversed() where child.viewIfLoaded?.window != nil && child.viewIfLoaded?.isHidden == false {
            if let found = currentNavigation(child) { return found }
        }
        return nil
    }
    @MainActor private static func state(_ nav: UINavigationController) -> [String: Any] {
        let top = nav.topViewController?.viewIfLoaded
        func gesture(_ value: UIGestureRecognizer?) -> [String: Any] {
            ["enabled": value?.isEnabled ?? false, "attached": value?.view != nil,
             "containsPage": value?.view.map { host in top.map { $0.isDescendant(of: host) } ?? false } ?? false,
             "view": value?.view.map { String(describing: type(of: $0)) } ?? "none"]
        }
        var result: [String: Any] = ["build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            "depth": nav.viewControllers.count, "barHidden": nav.isNavigationBarHidden,
            "backHidden": nav.topViewController?.navigationItem.hidesBackButton ?? true,
            "edge": gesture(nav.interactivePopGestureRecognizer)]
        if #available(iOS 26.0, *) { result["content"] = gesture(nav.interactiveContentPopGestureRecognizer) }
        return result
    }
    @MainActor static func recordIfEnabled() {
        guard enabled else { return }
        DispatchQueue.main.async {
            guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap(\.windows).first(where: \.isKeyWindow),
                  let nav = currentNavigation(window.rootViewController) else { return }
            let write = {
                guard let file = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("iPAStoreNavigationDiagnostics.json"),
                      let data = try? JSONSerialization.data(withJSONObject: state(nav), options: [.prettyPrinted, .sortedKeys]) else { return }
                queue.async { try? data.write(to: file, options: .atomic) }
            }
            if let transition = nav.transitionCoordinator { transition.animate(alongsideTransition: nil) { _ in DispatchQueue.main.async(execute: write) } }
            else { write() }
        }
    }
    // Native attachment/stack checks. Real interactive swipes require real input;
    // a possible-state recognizer ignores setTranslation and cannot simulate one.
    @MainActor static func run() async {
        guard !ran else { return }; ran = true
        guard UIApplication.shared.applicationState == .active,
              let original = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap(\.windows).first(where: \.isKeyWindow),
              let scene = original.windowScene else { return }
        let file = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("IPANavigationChecks.json")
        var report: [String: Any] = ["build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"]
        let window = UIWindow(windowScene: scene), root = UIViewController(), page = UIViewController()
        root.title = "Navigation Check"; page.title = "Page"
        root.view.backgroundColor = .systemBackground; page.view.backgroundColor = .systemBackground
        let nav = UINavigationController(rootViewController: root)
        let appearance = UINavigationBarAppearance(); appearance.configureWithTransparentBackground()
        nav.navigationBar.standardAppearance = appearance; nav.navigationBar.scrollEdgeAppearance = appearance
        window.frame = original.bounds; window.rootViewController = nav; window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; original.makeKeyAndVisible() }
        do {
            nav.setViewControllers([root, page], animated: false)
            nav.view.layoutIfNeeded(); try await Task.sleep(for: .milliseconds(150))
            report["native_state"] = state(nav)
            guard !nav.isNavigationBarHidden, !page.navigationItem.hidesBackButton,
                  nav.navigationBar.backItem != nil, nav.viewControllers.count == 2,
                  let edge = nav.interactivePopGestureRecognizer, edge.view != nil else {
                throw NSError(domain: "iPAStore.NavigationCheck", code: 1, userInfo: [NSLocalizedDescriptionKey: "Standard native back navigation did not attach"])
            }
            guard nav.popViewController(animated: false) === page, nav.viewControllers.count == 1 else {
                throw NSError(domain: "iPAStore.NavigationCheck", code: 2, userInfo: [NSLocalizedDescriptionKey: "Native pop did not restore its root"])
            }
            report["stack_and_native_attachment"] = "PASS"
            report["root_restoration"] = "PASS"
            report["physical_swipe"] = "Requires real input"
            report["status"] = "PASS"
        } catch { report["status"] = "FAIL"; report["reason"] = error.localizedDescription }
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: file, options: .atomic) }
    }
}

// Opt-in integration check of the real Search scroll owner and pinned field.
// It restores the previous tab/offset and never changes the query or app data.
enum IPASearchLayoutChecks {
    @MainActor private static var ran = false
    @MainActor static func run() async {
        guard !ran, UIApplication.shared.applicationState == .active else { return }; ran = true
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        var report: [String: Any] = ["build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"]
        func findTabs(_ root: UIViewController) -> UITabBarController? {
            if let tabs = root as? UITabBarController { return tabs }
            for child in root.children { if let tabs = findTabs(child) { return tabs } }
            return nil
        }
        func allViews(_ root: UIView) -> [UIView] { [root] + root.subviews.flatMap(allViews) }
        do {
            guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap(\.windows).first(where: \.isKeyWindow),
                  let root = window.rootViewController, let tabs = findTabs(root),
                  let coordinator = tabs.delegate as? IPATabPager.Coordinator,
                  let searchIndex = IPATabPager.order.firstIndex(of: .search) else { throw CocoaError(.validationMissingMandatoryProperty) }
            let initial = coordinator.selectedIndex
            defer { coordinator.selection.wrappedValue = IPATabPager.order[initial]; coordinator.synchronize(index: initial) }
            coordinator.selection.wrappedValue = .search; coordinator.synchronize(index: searchIndex)
            try await Task.sleep(for: .milliseconds(500))
            guard let page = tabs.selectedViewController?.view else { throw CocoaError(.validationMissingMandatoryProperty) }
            let views = allViews(page)
            guard let bar = views.compactMap({ $0 as? UISearchBar }).first,
                  let scroll = views.compactMap({ $0 as? UIScrollView }).first(where: { $0.contentSize.height > $0.bounds.height + 220 && $0.bounds.height > 200 }) else { throw CocoaError(.validationMissingMandatoryProperty) }
            let initialOffset = scroll.contentOffset
            defer { scroll.setContentOffset(initialOffset, animated: false) }
            scroll.setContentOffset(CGPoint(x: 0, y: -scroll.adjustedContentInset.top), animated: false)
            try await Task.sleep(for: .milliseconds(120))
            func visibleFieldFrame() -> CGRect {
                let frames = allViews(page).compactMap { $0 as? UISearchBar }.map { $0.searchTextField.convert($0.searchTextField.bounds, to: window) }
                return frames.filter { $0.width > 100 && $0.height > 20 && $0.intersects(window.bounds) }
                    .min(by: { $0.minY < $1.minY }) ?? bar.searchTextField.convert(bar.searchTextField.bounds, to: window)
            }
            let start = visibleFieldFrame()
            scroll.setContentOffset(CGPoint(x: 0, y: 260), animated: false)
            try await Task.sleep(for: .milliseconds(150))
            let pinned = visibleFieldFrame()
            scroll.setContentOffset(CGPoint(x: 0, y: 400), animated: false)
            try await Task.sleep(for: .milliseconds(150))
            let further = visibleFieldFrame()
            report["field_initial_y"] = Double(start.minY)
            report["field_pinned_y"] = Double(pinned.minY)
            report["field_further_scroll_y"] = Double(further.minY)

            // Kept local for visual review; never included in public release assets.
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
            try? image.pngData()?.write(to: directory.appendingPathComponent("IPASearchPinnedCheck.png"), options: .atomic)
            report["window_safe_top"] = Double(window.safeAreaInsets.top)
            report["bar_frames_after_scroll"] = allViews(page).compactMap { $0 as? UISearchBar }.map { $0.convert($0.bounds, to: window).debugDescription }
            guard start.minY - pinned.minY > 25, abs(pinned.minY - further.minY) < 2,
                  pinned.minY >= window.safeAreaInsets.top - 2, pinned.maxY < window.safeAreaInsets.top + 85 else {
                throw NSError(domain: "iPAStore.SearchLayoutCheck", code: 1, userInfo: [NSLocalizedDescriptionKey: "Search field did not remain at the expected visible pinned position"])
            }
            report["field_pins_without_title"] = "PASS"
            report["status"] = "PASS"
        } catch { report["status"] = "FAIL"; report["reason"] = error.localizedDescription }
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: directory.appendingPathComponent("IPASearchLayoutChecks.json"), options: .atomic) }
    }
}
