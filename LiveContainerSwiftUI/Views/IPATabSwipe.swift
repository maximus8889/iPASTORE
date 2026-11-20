import SwiftUI
import UIKit

// Own the native tab controller so UIKit can drive the real page transition.
// SwiftUI's newer TabView does not expose an interactive transition delegate.
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
            let host = UIHostingController(rootView: page)
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
        coordinator.reduceMotion = reduceMotion
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
        var hosts: [UIHostingController<AnyView>] = []
        weak var tabs: UITabBarController?
        private var pan: UIPanGestureRecognizer?
        private var interaction: IPATabInteractionController?
        private var synchronizing = false
        private var animating = false
        private var tracking = false
        private var stableIndex = 0
        private var selectingProgrammatically = false
        private var lastSearchReselection: CFTimeInterval = 0
        private var activeAnimator: IPATabSlideAnimator?
        var reduceMotion = false
        var lastTint: UIColor?
        var lastStyle: UIUserInterfaceStyle?
        private var origin: CGPoint?
        private var direction = 1
        private var fromIndex = 0
        private var targetIndex = 0
        #if IPASTORE_PREVIEW
        var diagnosticEvents: [String] = []
        #endif
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
            interaction?.cancel(); interaction = nil; tracking = false
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
            guard !animating, !tracking else { return }
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
            if !synchronizing && !animating && !tracking && interaction == nil { stableIndex = selectedIndex; publish(selectedIndex) }
        }
        @available(iOS 18.0, *)
        func tabBarController(_ tabBarController: UITabBarController, didSelectTab selectedTab: UITab, previousTab: UITab?) {
            if !synchronizing && !animating && !tracking && interaction == nil { stableIndex = selectedIndex; publish(selectedIndex) }
        }
        func tabBarController(_ tabBarController: UITabBarController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
            #if IPASTORE_PREVIEW
            diagnosticEvents.append("interactive driver requested: \(interaction != nil)")
            #endif
            return interaction
        }
        private func shouldSelect(_ index: Int?) -> Bool {
            let accepted = selectingProgrammatically || (!animating && !tracking)
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
        func tabBarController(_ tabBarController: UITabBarController, animationControllerForTransitionFrom fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
            guard !synchronizing else { return nil }
            let from = index(of: fromVC) ?? (tracking ? fromIndex : stableIndex)
            let to = index(of: toVC) ?? selectedIndex
            guard from != to else { return nil }
            animating = true
            #if IPASTORE_PREVIEW
            diagnosticEvents.append("animator: \(from) -> \(to), interactive \(interaction != nil)")
            #endif
            let animator = IPATabSlideAnimator(direction: to > from ? 1 : -1, interactive: interaction != nil, reduceMotion: reduceMotion) { [weak self] completed in
                guard let self else { return }
                self.animating = false; self.tracking = false; self.interaction = nil
                self.activeAnimator = nil
                let final = completed ? to : from
                self.stableIndex = final
                self.synchronize(index: final); self.publish(final)
            }
            activeAnimator = animator
            return animator
        }
        private func isRoot(_ controller: UIViewController?) -> Bool {
            guard let controller, controller.presentedViewController == nil else { return false }
            if let navigation = controller as? UINavigationController { return navigation.viewControllers.count == 1 && isRoot(navigation.visibleViewController) }
            return controller.children.filter { $0.viewIfLoaded?.window != nil && $0.viewIfLoaded?.isHidden != true }.allSatisfy { isRoot($0) }
        }
        func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let tabs, !animating, isRoot(tabs.selectedViewController) else { return false }
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
            guard let pan = recognizer as? UIPanGestureRecognizer, let tabs, !animating else { return false }
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
        var interactiveProgress: CGFloat? { interaction?.progress }
        var interactiveContextStarted: Bool { interaction?.started == true }
        var interactiveVisualOffset: CGFloat? { activeAnimator?.visibleOffset }
        var interactiveSourceOffset: CGFloat? { activeAnimator?.sourceOffset }
        var transitionInProgress: Bool { animating || tracking }
        @discardableResult func beginInteractive(direction: Int) -> Bool {
            guard let tabs, !animating, !tracking,
                  let target = IPATabPagingPolicy.adjacent(to: selectedIndex, direction: direction, count: hosts.count) else { return false }
            fromIndex = selectedIndex; stableIndex = fromIndex
            self.direction = direction; targetIndex = target; tracking = true
            if reduceMotion { return true }
            let driver = IPATabInteractionController()
            interaction = driver
            selectNative(target)
            return true
        }
        func updateInteractive(distance: CGFloat) {
            guard tracking, let tabs else { return }
            interaction?.update(IPATabPagingPolicy.progress(distance: distance, width: tabs.view.bounds.width, direction: direction))
        }
        func endInteractive(distance: CGFloat, velocity: CGFloat, cancelled: Bool = false) {
            guard tracking, let tabs else { return }
            let commit = !cancelled && IPATabPagingPolicy.commits(distance: distance, velocity: velocity, width: tabs.view.bounds.width, direction: direction)
            if reduceMotion {
                tracking = false
                if commit { selectNative(targetIndex) }
            } else {
                updateInteractive(distance: distance)
                if commit { interaction?.finish() } else { interaction?.cancel() }
            }
        }
        @objc private func moved(_ gesture: UIPanGestureRecognizer) {
            guard let tabs else { return }
            let current = gesture.location(in: tabs.view)
            let movement = origin.map { current.x - $0.x } ?? gesture.translation(in: tabs.view).x
            let velocity = gesture.velocity(in: tabs.view).x
            switch gesture.state {
            case .began:
                guard let direction = IPATabPagingPolicy.direction(velocity: velocity, translation: movement), beginInteractive(direction: direction) else { return }
                updateInteractive(distance: movement)
            case .changed: updateInteractive(distance: movement)
            case .ended:
                endInteractive(distance: movement, velocity: velocity); origin = nil
            case .cancelled, .failed:
                endInteractive(distance: movement, velocity: velocity, cancelled: true); origin = nil
            default: break
            }
        }

    }
}

// One interruptible animator is used for both taps and finger-driven swipes.
// UIKit owns the views/appearance lifecycle; no native roots are reparented.
private final class IPATabSlideAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let direction: CGFloat
    let interactive: Bool
    let reduceMotion: Bool
    let completion: (Bool) -> Void
    private var animator: UIViewPropertyAnimator?
    private weak var targetView: UIView?
    private weak var sourceView: UIView?
    var sourceOffset: CGFloat? { sourceView?.layer.presentation()?.transform.m41 }
    var visibleOffset: CGFloat? { targetView?.layer.presentation()?.transform.m41 }
    init(direction: Int, interactive: Bool, reduceMotion: Bool, completion: @escaping (Bool) -> Void) {
        self.direction = CGFloat(direction); self.interactive = interactive; self.reduceMotion = reduceMotion; self.completion = completion
    }
    func transitionDuration(using context: UIViewControllerContextTransitioning?) -> TimeInterval { reduceMotion ? 0.16 : IPATabPagingPolicy.transitionDuration }
    func interruptibleAnimator(using context: UIViewControllerContextTransitioning) -> UIViewImplicitlyAnimating {
        if let animator { return animator }
        let container = context.containerView
        guard let from = context.view(forKey: .from), let to = context.view(forKey: .to), let target = context.viewController(forKey: .to) else {
            let fallback = UIViewPropertyAnimator(duration: 0, curve: .linear)
            fallback.addCompletion { [weak self] _ in context.completeTransition(false); self?.completion(false) }
            animator = fallback
            return fallback
        }
        targetView = to; sourceView = from
        to.frame = context.finalFrame(for: target)
        to.layoutIfNeeded()
        if reduceMotion { to.alpha = 0 }
        else { to.transform = CGAffineTransform(translationX: direction * container.bounds.width, y: 0) }
        if direction < 0, from.superview === container { container.insertSubview(to, belowSubview: from) }
        else { container.addSubview(to) }
        let animator = UIViewPropertyAnimator(duration: transitionDuration(using: context), curve: interactive ? .linear : .easeOut) {
            if self.reduceMotion { from.alpha = 0; to.alpha = 1 }
            else {
                from.transform = CGAffineTransform(translationX: -self.direction * container.bounds.width, y: 0)
                to.transform = .identity
            }
        }
        animator.addCompletion { [weak self] position in
            let completed = position == .end && !context.transitionWasCancelled
            from.transform = .identity; to.transform = .identity; from.alpha = 1; to.alpha = 1
            if !completed { to.removeFromSuperview() }
            context.completeTransition(completed)
            self?.animator = nil; self?.completion(completed)
        }
        self.animator = animator
        return animator
    }
    func animateTransition(using context: UIViewControllerContextTransitioning) {
        interruptibleAnimator(using: context).startAnimation()
    }
}

// Buffer very fast gestures until UIKit has created the transition context.
// Percent-driven progress is linear under the finger; release settles smoothly.
private final class IPATabInteractionController: UIPercentDrivenInteractiveTransition {
    private(set) var started = false
    private(set) var progress: CGFloat = 0
    private var ending: Bool?
    override init() { super.init(); wantsInteractiveStart = true }
    override func startInteractiveTransition(_ context: UIViewControllerContextTransitioning) {
        super.startInteractiveTransition(context)
        // UIKit must finish attaching its transition before consuming an end
        // event buffered by a one-frame flick. Settle on the next main turn.
        DispatchQueue.main.async { [weak self] in self?.activate() }
    }
    private func activate() {
        started = true
        super.update(progress)
        if let ending { settle(ending) }
    }
    override func update(_ value: CGFloat) {
        progress = min(1, max(0, value))
        if started { super.update(progress) }
    }
    override func finish() { ending = true; if started { settle(true) } }
    override func cancel() { ending = false; if started { settle(false) } }
    private func settle(_ completed: Bool) {
        completionCurve = .easeOut
        completionSpeed = IPATabPagingPolicy.completionSpeed(progress: progress, completed: completed)
        if completed { super.finish() } else { super.cancel() }
    }
}

@MainActor private final class IPAMotionFrameSampler: NSObject {
    private var link: CADisplayLink?
    private var previous: CFTimeInterval?
    private var expected: CFTimeInterval = 1.0 / 60
    private var gaps: [Double] = []
    private var missed = 0
    func start() {
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        self.link = link; link.add(to: .main, forMode: .common)
    }
    @objc private func tick(_ link: CADisplayLink) {
        let currentExpected = max(1.0 / 240, link.targetTimestamp - link.timestamp)
        if let previous, gaps.count < 4096 {
            let gap = link.timestamp - previous; gaps.append(gap * 1000)
            if gap > max(expected, currentExpected) * 1.8 { missed += 1 }
        }
        previous = link.timestamp; expected = currentExpected
    }
    func stop() -> [String: Any] {
        link?.invalidate(); link = nil
        let ordered = gaps.sorted()
        return ["samples": gaps.count, "p95_frame_interval_ms": ordered.isEmpty ? 0 : ordered[min(ordered.count - 1, Int(Double(ordered.count) * 0.95))], "max_frame_interval_ms": ordered.last ?? 0, "delayed_frames": missed, "device_max_fps": UIScreen.main.maximumFramesPerSecond]
    }
}

// Opt-in native integration check for development candidates. A temporary window
// uses synthetic pages; it never opens guest apps or modifies accounts/catalogs.
enum IPATabMotionChecks {
    @MainActor private static var ran = false
    @MainActor static func run() async {
        guard !ran else { return }; ran = true
        let file = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("IPAMotionChecks.json")
        var report: [String: Any] = ["build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"]
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "iPAStore.MotionCheck", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        guard let original = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap(\.windows).first(where: \.isKeyWindow), let scene = original.windowScene else { return }
        func findTabs(_ controller: UIViewController) -> UITabBarController? {
            if let tabs = controller as? UITabBarController { return tabs }
            for child in controller.children { if let result = findTabs(child) { return result } }
            return nil
        }
        let productionTabs = original.rootViewController.flatMap(findTabs)
        let productionCoordinator = productionTabs?.delegate as? IPATabPager.Coordinator
        let sampler = IPAMotionFrameSampler(); sampler.start()
        var choice = LCTabIdentifier.today
        let pages = (0..<5).map { index in AnyView(Text("Motion Check \(index + 1)").font(.largeTitle).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(uiColor: .systemBackground))) }
        let coordinator = IPATabPager.Coordinator(selection: Binding(get: { choice }, set: { choice = $0 }))
        let tabs = IPATabPager.makeNativeController(pages: pages, selection: .today, coordinator: coordinator)
        coordinator.reduceMotion = UIAccessibility.isReduceMotionEnabled
        tabs.overrideUserInterfaceStyle = .dark
        let window = UIWindow(windowScene: scene)
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 5)
        window.frame = original.bounds
        window.rootViewController = tabs; window.makeKeyAndVisible()
        window.layoutIfNeeded(); tabs.view.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil; original.makeKeyAndVisible() }
        do {
            try await Task.sleep(for: .milliseconds(150))
            defer { coordinator.detach() }
            @MainActor func settled() async throws {
                for _ in 0..<100 where coordinator.transitionInProgress { try await Task.sleep(nanoseconds: 40_000_000) }
                report["last_native_index"] = coordinator.selectedIndex
                report["last_context_started"] = coordinator.interactiveContextStarted
                report["last_progress"] = coordinator.interactiveProgress.map(Double.init) ?? NSNull()
                try require(!coordinator.transitionInProgress, "Transition failed to settle")
                for root in coordinator.hosts {
                    try require(root.view.transform.isIdentity && root.view.alpha == 1, "A page retained its transition transform/opacity")
                }
            }
            let width = tabs.view.bounds.width
            try require(width > 0, "No content width")
            if !coordinator.reduceMotion {
                try require(coordinator.beginInteractive(direction: 1), "Held swipe failed to begin")
                for _ in 0..<50 where !coordinator.interactiveContextStarted { try await Task.sleep(nanoseconds: 20_000_000) }
                try require(coordinator.interactiveContextStarted, "UIKit did not start the interactive context")
                try require(!coordinator.tabBarController(tabs, shouldSelect: coordinator.hosts[2]), "Tab taps were accepted during an unfinished swipe")
                coordinator.updateInteractive(distance: -width * 0.45)
                try await Task.sleep(nanoseconds: 900_000_000)
                let offset = coordinator.interactiveVisualOffset
                report["held_offset"] = offset.map(Double.init) ?? NSNull()
                report["width"] = Double(width)
                try require(offset.map { abs($0) > width * 0.1 && abs($0) < width * 0.9 } == true, "Held swipe did not reveal part of the adjacent page")
                let cancelledAt = CACurrentMediaTime()
                coordinator.endInteractive(distance: -width * 0.45, velocity: 0, cancelled: true)
                try await settled()
                let cancelDuration = CACurrentMediaTime() - cancelledAt
                report["held_cancel_release_ms"] = cancelDuration * 1000
                try require(cancelDuration < 0.4, "Held cancellation settled too slowly")
                try require(coordinator.selectedIndex == 0 && choice == .today, "Cancellation lost selection")
                report["held_cancel"] = "PASS"
                // Hold near the destination, then release without flick velocity.
                // This must not acquire the slow tail reported after a long hold.
                for direction in [1, -1] {
                    try require(coordinator.beginInteractive(direction: direction), "Long-held completion failed to begin")
                    for _ in 0..<50 where !coordinator.interactiveContextStarted { try await Task.sleep(nanoseconds: 20_000_000) }
                    coordinator.updateInteractive(distance: -CGFloat(direction) * width * 0.85)
                    try await Task.sleep(nanoseconds: 900_000_000)
                    let outgoing = coordinator.interactiveSourceOffset, incoming = coordinator.interactiveVisualOffset
                    try require(outgoing != nil && incoming != nil, "Missing page presentation positions")
                    try require(abs((incoming! - outgoing!) - CGFloat(direction) * width) < 2, "Tab pages overlapped or separated during a held swipe")
                    try require(abs(outgoing! + CGFloat(direction) * width * 0.85) < 2, "Outgoing page did not follow the finger")
                    report["parallel_paging_\(direction)"] = "PASS"
                    let releasedAt = CACurrentMediaTime()
                    coordinator.endInteractive(distance: -CGFloat(direction) * width * 0.85, velocity: 0)
                    try await settled()
                    let seconds = CACurrentMediaTime() - releasedAt
                    report["held_finish_\(direction)_release_ms"] = seconds * 1000
                    try require(seconds < 0.4, "Long-held completion settled too slowly")
                    let expected = direction == 1 ? 1 : 0
                    try require(coordinator.selectedIndex == expected, "Long-held completion lost selection")
                }
                report["held_release_timing"] = "PASS (cancel + both directions)"
                for number in 0..<6 {
                    report["stage"] = "rapid-\(number)"
                    let direction = number.isMultiple(of: 2) ? 1 : -1
                    try require(coordinator.beginInteractive(direction: direction), "Rapid swipe failed to begin")
                    coordinator.updateInteractive(distance: -CGFloat(direction) * width * 0.72)
                    coordinator.endInteractive(distance: -CGFloat(direction) * width * 0.72, velocity: -CGFloat(direction) * 500)
                    try await settled()
                    let expected = number.isMultiple(of: 2) ? 1 : 0
                    try require(coordinator.selectedIndex == expected && choice == IPATabPager.order[expected], "Rapid/reverse swipe lost selection")
                }
                report["rapid_reverse_buffered_finish"] = "PASS (6)"
                for target in Array(1...4) + Array((0...3).reversed()) {
                    report["stage"] = "boundary-\(target)"
                    let direction = target > coordinator.selectedIndex ? 1 : -1
                    try require(coordinator.beginInteractive(direction: direction), "Adjacent tab failed to start")
                    coordinator.endInteractive(distance: -CGFloat(direction) * width * 0.65, velocity: -CGFloat(direction) * 400)
                    try await settled()
                    try require(coordinator.selectedIndex == target && choice == IPATabPager.order[target], "A tab boundary lost page/selection synchronization")
                }
                report["all_tab_boundaries"] = "PASS (8)"
            } else { report["held_cancel"] = "SKIPPED: system Reduce Motion enabled" }
            report["stage"] = "reduce-motion"
            coordinator.reduceMotion = true
            let start = coordinator.selectedIndex, direction = start == 4 ? -1 : 1
            try require(coordinator.beginInteractive(direction: direction), "Reduced-motion gesture failed")
            coordinator.updateInteractive(distance: -CGFloat(direction) * width * 0.7)
            try require(coordinator.selectedIndex == start, "Reduce Motion moved a page under the finger")
            coordinator.endInteractive(distance: -CGFloat(direction) * width * 0.7, velocity: 0)
            try await settled()
            try require(coordinator.selectedIndex == start + direction && choice == IPATabPager.order[start + direction], "Reduced-motion commit lost selection")
            report["reduce_motion"] = "PASS"
            let reducedIndex = coordinator.selectedIndex
            try require(coordinator.beginInteractive(direction: -direction), "Reduced-motion cancel failed to start")
            coordinator.endInteractive(distance: 0, velocity: 0, cancelled: true)
            try await settled()
            try require(coordinator.selectedIndex == reducedIndex, "Reduced-motion cancellation changed tabs")
            // Exercise the actual store roots after the synthetic edge cases.
            // Selection is restored even if a content-page transition fails.
            window.isHidden = true; original.makeKeyAndVisible()
            if let real = productionCoordinator, let actualTabs = productionTabs {
                let initial = real.selectedIndex, wasReduced = real.reduceMotion
                defer { real.reduceMotion = wasReduced; real.selection.wrappedValue = IPATabPager.order[initial]; real.synchronize(index: initial) }
                real.reduceMotion = false
                real.selection.wrappedValue = .today; real.synchronize(index: 0)
                var releaseTimes: [Double] = []
                for target in Array(1...4) + Array((0...3).reversed()) {
                    let direction = target > real.selectedIndex ? 1 : -1
                    try require(real.beginInteractive(direction: direction), "Store content swipe failed to begin")
                    for _ in 0..<100 where !real.interactiveContextStarted { try await Task.sleep(for: .milliseconds(10)) }
                    let width = actualTabs.view.bounds.width
                    real.updateInteractive(distance: -CGFloat(direction) * width * 0.7)
                    let began = CACurrentMediaTime()
                    real.endInteractive(distance: -CGFloat(direction) * width * 0.7, velocity: -CGFloat(direction) * 400)
                    for _ in 0..<150 where real.transitionInProgress { try await Task.sleep(for: .milliseconds(10)) }
                    try require(!real.transitionInProgress && real.selectedIndex == target, "Store content swipe did not settle on the right page")
                    try require(real.hosts.allSatisfy { $0.view.transform.isIdentity && $0.view.alpha == 1 }, "Store content retained an animation transform")
                    releaseTimes.append((CACurrentMediaTime() - began) * 1000)
                }
                report["production_tab_boundaries"] = "PASS (8)"
                report["production_release_ms"] = releaseTimes
            } else { throw NSError(domain: "iPAStore.MotionCheck", code: 2, userInfo: [NSLocalizedDescriptionKey: "Production tab controller was not available"]) }
            report["status"] = "PASS"
        } catch { report["status"] = "FAIL"; report["reason"] = error.localizedDescription }
        report["frames"] = sampler.stop()
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: file, options: .atomic) }
    }
}
