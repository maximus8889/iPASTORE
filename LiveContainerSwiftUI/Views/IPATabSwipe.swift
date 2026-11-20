import SwiftUI
import UIKit

// Keep each native navigation stack alive while switching tabs.
struct IPATabPager: UIViewControllerRepresentable {
    @Binding var selection: LCTabIdentifier
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let pages: [AnyView]
    let accent: Color
    let appearance: String
    static let order: [LCTabIdentifier] = [.today, .sources, .apps, .settings, .search]
    func makeCoordinator() -> Coordinator { Coordinator(selection: $selection) }
    func makeUIViewController(context: Context) -> UITabBarController {
        let tabs = Self.makeNativeController(pages: pages, selection: selection, coordinator: context.coordinator)
        updateUIViewController(tabs, context: context)
        return tabs
    }
    // Production and opt-in native checks create the exact same tab controller.
    @MainActor static func makeNativeController(pages: [AnyView], selection: LCTabIdentifier, coordinator: Coordinator) -> UITabBarController {
        let tabs = UITabBarController()
        let titles = ["Today", "Stores", "Apps", "Settings", "Search"]
        let symbols = ["newspaper", IPAStyle.storeSymbol, IPAStyle.appsSymbol, "gearshape", "magnifyingglass"]
        let hosts = pages.enumerated().map { index, page in
            let host = IPAInitialTabHost(rootView: page)
            host.fadesOnFirstAppearance = index == 0 || index == 2
            host.tabBarItem = UITabBarItem(title: titles[index], image: UIImage(systemName: symbols[index]), tag: index)
            host.viewIfLoaded?.backgroundColor = .clear
            return host
        }
        coordinator.hosts = hosts
        coordinator.tabs = tabs
        if #available(iOS 18.0, *) {
            tabs.mode = .tabBar
            tabs.tabs = hosts.enumerated().map { index, host in
                if index == 4 { return UISearchTab { _ in host } }
                return UITab(title: titles[index], image: UIImage(systemName: symbols[index]), identifier: "ipastore.\(index)") { _ in host }
            }
        } else { tabs.setViewControllers(hosts, animated: false) }
        let initial = Self.order.firstIndex(of: selection) ?? 0
        if #available(iOS 18.0, *) { tabs.selectedTab = tabs.tabs[initial] }
        else { tabs.selectedIndex = initial }
        tabs.delegate = coordinator
        coordinator.attach()
        return tabs
    }
    func updateUIViewController(_ tabs: UITabBarController, context: Context) {
        let coordinator = context.coordinator
        coordinator.selection = $selection
        for host in coordinator.hosts { host.reduceMotion = reduceMotion }
        // Roots retain their own state and observable references. Replacing all
        // five AnyView trees on every selection caused unnecessary navigation work.
        let tint = UIColor(accent)
        // Compare resolved colors, not the identity of a new dynamic provider.
        let resolvedTint = tint.resolvedColor(with: tabs.traitCollection)
        let style: UIUserInterfaceStyle = appearance == "dark" ? .dark : appearance == "light" ? .light : .unspecified
        if coordinator.lastTint?.isEqual(resolvedTint) != true || coordinator.lastStyle != style {
            coordinator.lastTint = resolvedTint; coordinator.lastStyle = style
            for host in coordinator.hosts {
                host.viewIfLoaded?.tintColor = tint
                host.overrideUserInterfaceStyle = style
            }
            tabs.view.tintColor = tint; tabs.tabBar.tintColor = tint
            tabs.overrideUserInterfaceStyle = style
        }
        coordinator.synchronize(index: Self.order.firstIndex(of: selection) ?? 0)
    }
    static func dismantleUIViewController(_ controller: UITabBarController, coordinator: Coordinator) { coordinator.detach() }

    final class Coordinator: NSObject, UITabBarControllerDelegate, UIGestureRecognizerDelegate {
        var selection: Binding<LCTabIdentifier>
        var hosts: [IPAInitialTabHost] = []
        weak var tabs: UITabBarController?
        private var pan: UIPanGestureRecognizer?
        private var synchronizing = false
        private var tracking = false
        private var stableIndex = 0
        private var selectingProgrammatically = false
        private var lastSearchReselection: CFTimeInterval = 0
        var lastTint: UIColor?
        var lastStyle: UIUserInterfaceStyle?
        private var origin: CGPoint?
        private var direction = 1
        private var targetIndex = 0
        init(selection: Binding<LCTabIdentifier>) { self.selection = selection }
        func attach() {
            guard let tabs else { return }
            let pan = UIPanGestureRecognizer(target: self, action: #selector(moved(_:)))
            pan.delegate = self; pan.maximumNumberOfTouches = 1
            pan.cancelsTouchesInView = true
            tabs.view.addGestureRecognizer(pan); self.pan = pan
        }
        func detach() {
            if let pan { pan.view?.removeGestureRecognizer(pan) }
            tracking = false
        }
        var selectedIndex: Int {
            guard let tabs else { return stableIndex }
            if #available(iOS 18.0, *), let selected = tabs.selectedTab,
               let index = tabs.tabs.firstIndex(where: { $0 === selected }) { return index }
            return tabs.selectedIndex
        }
        private func selectNative(_ index: Int) {
            guard let tabs else { return }
            selectingProgrammatically = true
            defer { selectingProgrammatically = false }
            if #available(iOS 18.0, *), tabs.tabs.indices.contains(index) { tabs.selectedTab = tabs.tabs[index] }
            else { tabs.selectedIndex = index }
        }
        func synchronize(index: Int) {
            guard !tracking else { return }
            stableIndex = index
            guard selectedIndex != index else { return }
            synchronizing = true
            UIView.performWithoutAnimation { selectNative(index) }
            synchronizing = false
        }
        private func publish(_ index: Int) {
            guard IPATabPager.order.indices.contains(index), selection.wrappedValue != IPATabPager.order[index] else { return }
            selection.wrappedValue = IPATabPager.order[index]
        }
        func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
            if !synchronizing && !tracking { stableIndex = selectedIndex; publish(selectedIndex) }
        }
        @available(iOS 18.0, *)
        func tabBarController(_ tabBarController: UITabBarController, didSelectTab selectedTab: UITab, previousTab: UITab?) {
            if !synchronizing && !tracking { stableIndex = selectedIndex; publish(selectedIndex) }
        }
        private func shouldSelect(_ index: Int?) -> Bool {
            let accepted = selectingProgrammatically || !tracking
            if accepted, !selectingProgrammatically, !synchronizing, index == 4, selectedIndex == 4 {
                let now = CACurrentMediaTime()
                // Some UIKit versions invoke both delegate forms for one tap.
                if now - lastSearchReselection > 0.1 {
                    lastSearchReselection = now
                    NotificationCenter.default.post(name: .ipaSearchTabReselected, object: nil)
                }
            }
            return accepted
        }
        func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool { shouldSelect(index(of: viewController)) }
        @available(iOS 18.0, *)
        func tabBarController(_ tabBarController: UITabBarController, shouldSelectTab tab: UITab) -> Bool { shouldSelect(tabs?.tabs.firstIndex(where: { $0 === tab })) }
        private func index(of controller: UIViewController) -> Int? {
            if let index = hosts.firstIndex(where: { $0 === controller }) { return index }
            return controller.children.compactMap { index(of: $0) }.first
        }
        private func isRoot(_ controller: UIViewController?) -> Bool {
            guard let controller, controller.presentedViewController == nil else { return false }
            if let navigation = controller as? UINavigationController { return navigation.viewControllers.count == 1 && isRoot(navigation.visibleViewController) }
            return controller.children.filter { $0.viewIfLoaded?.window != nil && $0.viewIfLoaded?.isHidden != true }.allSatisfy { isRoot($0) }
        }
        func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let tabs, !tracking, isRoot(tabs.selectedViewController) else { return false }
            let point = touch.location(in: tabs.view)
            let bar = tabs.tabBar.convert(tabs.tabBar.bounds, to: tabs.view)
            guard point.x > 28, point.x < tabs.view.bounds.width - 28,
                  point.y > tabs.view.safeAreaInsets.top + 44, !bar.contains(point) else { return false }
            var view = touch.view
            while let candidate = view, candidate !== tabs.view {
                if candidate is UIControl || candidate is UITextView { return false }
                if let scroll = candidate as? UIScrollView, scroll.contentSize.width > scroll.bounds.width + 2 || scroll.alwaysBounceHorizontal { return false }
                view = candidate.superview
            }
            origin = point; return true
        }
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer, let tabs, !tracking else { return false }
            let velocity = pan.velocity(in: tabs.view)
            let distance = pan.translation(in: tabs.view)
            guard let direction = IPATabPagingPolicy.direction(velocity: velocity.x, translation: distance.x) else { return false }
            let target = selectedIndex + direction
            return IPATabPagingPolicy.acceptsPan(velocityX: velocity.x, velocityY: velocity.y, translationX: distance.x, translationY: distance.y) && hosts.indices.contains(target) && isRoot(tabs.selectedViewController)
        }
        func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            guard let scroll = other.view as? UIScrollView else { return false }
            return scroll.contentSize.width <= scroll.bounds.width + 2 && !scroll.alwaysBounceHorizontal
        }
        var transitionInProgress: Bool { tracking }
        @discardableResult func beginInteractive(direction: Int) -> Bool {
            guard !tracking,
                  let target = IPATabPagingPolicy.adjacent(to: selectedIndex, direction: direction, count: hosts.count) else { return false }
            self.direction = direction
            targetIndex = target
            tracking = true
            return true
        }
        func endInteractive(distance: CGFloat, velocity: CGFloat, cancelled: Bool = false) {
            guard tracking, let tabs else { return }
            tracking = false
            guard !cancelled,
                  IPATabPagingPolicy.commits(distance: distance, velocity: velocity, width: tabs.view.bounds.width, direction: direction) else { return }
            synchronize(index: targetIndex)
            publish(targetIndex)
        }
        @objc private func moved(_ gesture: UIPanGestureRecognizer) {
            guard let tabs else { return }
            let current = gesture.location(in: tabs.view)
            let movement = origin.map { current.x - $0.x } ?? gesture.translation(in: tabs.view).x
            let velocity = gesture.velocity(in: tabs.view).x
            switch gesture.state {
            case .began:
                if let direction = IPATabPagingPolicy.direction(velocity: velocity, translation: movement) { beginInteractive(direction: direction) }
            case .ended:
                endInteractive(distance: movement, velocity: velocity); origin = nil
            case .cancelled, .failed:
                endInteractive(distance: movement, velocity: velocity, cancelled: true); origin = nil
            default: break
            }
        }

    }
}

final class IPAInitialTabHost: UIHostingController<AnyView> {
    var fadesOnFirstAppearance = false
    var reduceMotion = false
    private(set) var firstAppearanceCompleted = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if fadesOnFirstAppearance, !firstAppearanceCompleted, !reduceMotion, !UIAccessibility.isReduceMotionEnabled {
            view.alpha = 0
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !firstAppearanceCompleted else { return }
        firstAppearanceCompleted = true
        if view.alpha == 0 {
            UIView.animate(withDuration: 0.20, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
                self.view.alpha = 1
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.layer.removeAllAnimations()
        view.alpha = 1
    }
}

enum IPATabMotionChecks {
    @MainActor private static var ran = false
    @MainActor static func run() async {
        guard !ran, let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        ran = true
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let previousWindow = scene.keyWindow
        var selection = LCTabIdentifier.today
        let coordinator = IPATabPager.Coordinator(selection: Binding(get: { selection }, set: { selection = $0 }))
        let tabs = IPATabPager.makeNativeController(
            pages: IPATabPager.order.map { _ in AnyView(Color.clear) }, selection: selection, coordinator: coordinator
        )
        let window = UIWindow(windowScene: scene)
        window.rootViewController = tabs
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previousWindow?.makeKey(); coordinator.detach() }
        try? await Task.sleep(for: .milliseconds(250))
        let width = tabs.view.bounds.width
        let started = coordinator.beginInteractive(direction: 1)
        let heldOriginal = coordinator.selectedIndex == 0
        coordinator.endInteractive(distance: -width, velocity: 0, cancelled: true)
        let cancelled = coordinator.selectedIndex == 0 && selection == .today
        let restarted = coordinator.beginInteractive(direction: 1)
        coordinator.endInteractive(distance: -width, velocity: 0)
        let committed = coordinator.selectedIndex == 1 && selection == .sources && !coordinator.transitionInProgress
        let report: [String: Any] = [
            "status": (started && heldOriginal && cancelled && restarted && committed) ? "PASS" : "FAIL",
            "cancelled_without_transition": cancelled,
            "committed_without_transition": committed
        ]
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: directory.appendingPathComponent("IPATabMotionChecks.json"), options: .atomic)
        }
    }
}
