import SwiftUI
import UIKit

// FBS scene frames use portrait coordinates; the hosting view uses the actual
// window bounds. Convert once, without changing a guest root-view transform.
enum IPAGuestGeometry {
    static func sceneFrame(in bounds: CGRect, orientation: UIInterfaceOrientation) -> CGRect {
        CGRect(origin: .zero, size: orientation.isLandscape ? CGSize(width: bounds.height, height: bounds.width) : bounds.size)
    }
}

#if !IPASTORE_PREVIEW
@MainActor final class IPAAppSession: ObservableObject {
    static let shared = IPAAppSession()
    struct App: Identifiable {
        let id = UUID()
        let model: LCAppModel
        let bundleID: String
        let dataUUID: String
        let launchURL: String?
        var name: String { model.displayName }
    }
    private var originalOrientation: UIInterfaceOrientation = .portrait
    @Published var active: App?
    @Published private var launchTransition = IPAGuestLaunchTransition()
    var coversStorefront: Bool { launchTransition.coversStorefront }
    fileprivate var controller: IPAHostedGuestController?
    @Published private(set) var interruptedRecord: IPAGuestResumeRecord?
    private var closingID: UUID?
    private var revealAfterDismiss = true
    private var legacyReturnID: UUID?
    private init() {
        interruptedRecord = IPAGuestResumeRecord.read(from: .standard)
        if UserDefaults.standard.bool(forKey: "IPAFadeStorefrontOnReturn") {
            let id = UUID(); legacyReturnID = id; _ = launchTransition.beginReturn(id)
            UserDefaults.standard.removeObject(forKey: "IPAFadeStorefrontOnReturn")
        }
    }
    func storefrontAppeared() async {
        if interruptedRecord != nil { DataManager.shared.model.selectedTab = .apps }
        guard let id = legacyReturnID else { return }
        await Task.yield()
        guard legacyReturnID == id else { return }
        legacyReturnID = nil
        withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : .easeOut(duration: 0.20)) { launchTransition.didPresent(id) }
    }
    fileprivate func makeController(for app: App) -> IPAHostedGuestController {
        if let controller, controller.app.id == app.id { return controller }
        controller?.stop()
        let next = IPAHostedGuestController(app: app); controller = next; return next
    }
    fileprivate func retains(_ value: IPAHostedGuestController) -> Bool {
        active?.id == value.app.id && closingID == nil
    }
    func dismissInterruptedRecord() {
        interruptedRecord = nil; UserDefaults.standard.removeObject(forKey: IPAGuestResumeRecord.key)
    }
    func continueInterruptedSession() async {
        guard let record = interruptedRecord else { return }
        guard let model = DataManager.shared.model.apps.first(where: { $0.appInfo.relativeBundlePath == record.appFolder }),
              model.installedLaunchRevision == record.revision,
              model.uiContainers.contains(where: { $0.folderName == record.dataFolder }) else {
            dismissInterruptedRecord()
            IPAInstallCoordinator.shared.issue = IPAInstallIssue(title: "Previous Session Unavailable", message: "This app or its data container has changed. Open its current entry in Apps.", action: .none)
            return
        }
        do {
            if model.uiIsLocked { guard try await LCUtils.authenticateUser() else { return } }
            try await model.runApp(containerFolderName: record.dataFolder, bundleIdOverride: record.appFolder, directLaunch: true)
        }
        catch { IPAInstallCoordinator.shared.issue = .from(error) }
    }
    func open(_ model: LCAppModel, bundleID: String, dataUUID: String, url: String?) async throws {
        guard closingID == nil else { throw CancellationError() }
        guard active == nil else {
            if active?.dataUUID == dataUUID { return }
            throw IPAInstallIssue(title: "Close the Current App", message: "Return to iPAStore before opening another app.", action: .none)
        }
        let request = App(model: model, bundleID: bundleID, dataUUID: dataUUID, launchURL: url)
        guard launchTransition.requestID == nil else {
            throw IPAInstallIssue(title: "An App Is Opening", message: "Wait for the current app to open before choosing another.", action: .none)
        }
        originalOrientation = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first(where: { $0.activationState == .foregroundActive })?.interfaceOrientation ?? .portrait
        let reduced = UIAccessibility.isReduceMotionEnabled
        withAnimation(reduced ? nil : .easeOut(duration: 0.14)) { _ = launchTransition.begin(request.id) }
        do {
            if !reduced { try await Task.sleep(for: .milliseconds(140)) }
            try Task.checkCancellation()
            guard launchTransition.requestID == request.id else { throw CancellationError() }
            // The already-black storefront hands over to an already-black guest
            // cover. No root snapshot, process restart or modal slide is needed.
            var transaction = Transaction(); transaction.disablesAnimations = true
            let record = IPAGuestResumeRecord(appFolder: bundleID, dataFolder: dataUUID, revision: model.installedLaunchRevision, name: String(model.displayName.prefix(160)))
            if model.uiIsHidden { UserDefaults.standard.removeObject(forKey: IPAGuestResumeRecord.key) }
            else { record.save(to: .standard) }
            interruptedRecord = nil
            withTransaction(transaction) { active = request }
        } catch {
            var transaction = Transaction(); transaction.disablesAnimations = true
            withTransaction(transaction) { launchTransition.cancel(request.id) }
            throw error
        }
    }
    fileprivate func didPresent(_ id: UUID) {
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) { launchTransition.didPresent(id) }
    }
    @discardableResult func close(pid: Int32) -> Bool {
        guard controller?.guest?.pid == pid else { return false }
        close(); return true
    }
    func close(animated: Bool = true, revealStorefront: Bool = true) {
        guard closingID == nil else { return }
        guard let app = active else {
            launchTransition.cancel(); return
        }
        closingID = app.id; revealAfterDismiss = revealStorefront
        let finish = { [weak self] in
            guard let self, self.closingID == app.id, self.active?.id == app.id else { return }
            var transaction = Transaction(); transaction.disablesAnimations = true
            withTransaction(transaction) {
                _ = self.launchTransition.beginReturn(app.id)
                self.dismissInterruptedRecord()
                self.controller?.stop(); self.active = nil
            }
        }
        if animated, let controller { controller.fadeForReturn(completion: finish) }
        else { finish() }
    }
    func presentationDismissed() {
        controller = nil
        restoreOrientation()
        guard let id = closingID else { return }
        closingID = nil
        if revealAfterDismiss {
            withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : .easeOut(duration: 0.20)) { launchTransition.didPresent(id) }
        }
    }
    func releaseCompatibilityCover() {
        withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : .easeOut(duration: 0.20)) { launchTransition.cancel() }
    }
    func restoreOrientation() {
        let mask: UIInterfaceOrientationMask = originalOrientation == .landscapeLeft ? .landscapeLeft : originalOrientation == .landscapeRight ? .landscapeRight : originalOrientation == .portraitUpsideDown ? .portraitUpsideDown : .portrait
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) where scene.activationState == .foregroundActive {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
        }
    }
}

struct IPAAppSessionPresentation: ViewModifier {
    @ObservedObject private var session = IPAAppSession.shared
    func body(content: Content) -> some View {
        content.overlay {
            Color.black.opacity(session.coversStorefront ? 1 : 0)
                .ignoresSafeArea().allowsHitTesting(session.coversStorefront).accessibilityHidden(true)
        }.task { await session.storefrontAppeared() }.fullScreenCover(item: $session.active, onDismiss: { session.presentationDismissed() }) { app in
            IPAHostedGuestView(app: app).ignoresSafeArea()
        }
    }
}

private struct IPAHostedGuestView: UIViewControllerRepresentable {
    let app: IPAAppSession.App
    func makeUIViewController(context: Context) -> IPAHostedGuestController { IPAAppSession.shared.makeController(for: app) }
    func updateUIViewController(_ controller: IPAHostedGuestController, context: Context) {}
    static func dismantleUIViewController(_ controller: IPAHostedGuestController, coordinator: ()) {
        if !IPAAppSession.shared.retains(controller) { controller.stop() }
    }
}

@MainActor fileprivate final class IPAHostedGuestController: UIViewController, AppSceneViewControllerDelegate {
    private static let geometryQueue = DispatchQueue(label: "app.ipastore.guest-layout", qos: .utility)
    let app: IPAAppSession.App
    fileprivate var guest: AppSceneViewController?
    private var stopped = false
    private var returning = false
    private var activated = false
    private var lifecycle = IPAGuestLifecycle()
    private var observers: [NSObjectProtocol] = []
    private var startupWatchdog: Task<Void, Never>?
    private var attemptID = UUID()
    private var launchURLDelivered = false
    private var compatibilityAttempted = false
    private var startupError: NSError?
    private var failed = false
    private var appeared = false
    private var starting = false
    private var revealing = false
    private var coverGeneration = 0
    private var orientationError: String?
    private var lastFrame = CGRect.null
    private var lastOrientation = UIInterfaceOrientation.unknown
    private var lastInsets = UIEdgeInsets.zero
    private var desiredOrientation: UIInterfaceOrientation = .portrait
    private var mask: UIInterfaceOrientationMask = .allButUpsideDown
    private let backdrop = UIView()
    private let panel = UIStackView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let compatibility = UIButton(type: .system)
    private let reopen = UIButton(type: .system)
    init(app: IPAAppSession.App) { self.app = app; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { mask }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { desiredOrientation }
    override var shouldAutorotate: Bool { true }
    override func viewDidLoad() {
        super.viewDidLoad()
        IPAAppSession.shared.controller = self
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.hostInterrupted() }
        })
        observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.hostBecameActive() }
        })
        view.backgroundColor = .black
        if let path = app.model.appInfo.bundlePath(), let info = NSDictionary(contentsOfFile: (path as NSString).appendingPathComponent("Info.plist")),
           let values = (info[UIDevice.current.userInterfaceIdiom == .pad ? "UISupportedInterfaceOrientations~ipad" : "UISupportedInterfaceOrientations"] ?? info["UISupportedInterfaceOrientations"]) as? [String] {
            var supported: UIInterfaceOrientationMask = []
            for value in values {
                switch value { case "UIInterfaceOrientationPortrait": supported.insert(.portrait)
                case "UIInterfaceOrientationPortraitUpsideDown": supported.insert(.portraitUpsideDown)
                case "UIInterfaceOrientationLandscapeLeft": supported.insert(.landscapeLeft)
                case "UIInterfaceOrientationLandscapeRight": supported.insert(.landscapeRight)
                default: break }
            }
            if !supported.isEmpty { mask = supported }
        }
        desiredOrientation = mask.contains(.portrait) ? .portrait : mask.contains(.landscapeRight) ? .landscapeRight : .landscapeLeft
        panel.axis = .vertical; panel.alignment = .center; panel.spacing = 16; panel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .preferredFont(forTextStyle: .headline); titleLabel.textAlignment = .center; titleLabel.numberOfLines = 3
        detailLabel.font = .preferredFont(forTextStyle: .subheadline); detailLabel.textColor = .secondaryLabel; detailLabel.numberOfLines = 0; detailLabel.textAlignment = .center
        let icon = UIImageView(image: app.model.appInfo.iconIsDarkIcon(false))
        icon.contentMode = .scaleAspectFill; icon.clipsToBounds = true
        icon.layer.cornerRadius = 17
        NSLayoutConstraint.activate([icon.widthAnchor.constraint(equalToConstant: 68), icon.heightAnchor.constraint(equalToConstant: 68)])
        let back = UIButton(type: .system)
        var returnStyle = UIButton.Configuration.filled()
        returnStyle.title = "Return to iPAStore"
        returnStyle.image = UIImage(systemName: "arrow.uturn.left")
        returnStyle.imagePadding = 9
        returnStyle.cornerStyle = .capsule
        returnStyle.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 18, bottom: 12, trailing: 18)
        back.configuration = returnStyle
        back.addTarget(self, action: #selector(close), for: .touchUpInside)
        compatibility.setTitle("Use Compatibility Launch", for: .normal); compatibility.addTarget(self, action: #selector(openCompatibility), for: .touchUpInside); compatibility.isHidden = true
        reopen.setTitle("Reopen App", for: .normal); reopen.addTarget(self, action: #selector(reopenApp), for: .touchUpInside); reopen.isHidden = true
        for child in [icon, titleLabel, detailLabel, reopen, compatibility, back] { panel.addArrangedSubview(child) }
        panel.isHidden = true
        backdrop.frame = view.bounds; backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]; backdrop.backgroundColor = .black
        view.addSubview(backdrop); view.addSubview(panel)
        NSLayoutConstraint.activate([panel.centerXAnchor.constraint(equalTo: view.centerXAnchor), panel.centerYAnchor.constraint(equalTo: view.centerYAnchor), panel.widthAnchor.constraint(lessThanOrEqualToConstant: 360), panel.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24), panel.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24)])
    }
    private func startGuestIfReady() {
        guard appeared, !starting, !stopped, !failed, !lifecycle.inBackground, UIApplication.shared.applicationState == .active, guest == nil, let scene = view.window?.windowScene else { return }
        let orientation = scene.interfaceOrientation
        let bit: UIInterfaceOrientationMask = orientation == .landscapeLeft ? .landscapeLeft : orientation == .landscapeRight ? .landscapeRight : orientation == .portraitUpsideDown ? .portraitUpsideDown : .portrait
        guard orientation != .unknown, mask.contains(bit),
              orientation.isLandscape ? view.bounds.width >= view.bounds.height : view.bounds.height >= view.bounds.width else { return }
        starting = true; attemptID = UUID(); armWatchdog()
        let child = AppSceneViewController(bundleId: app.bundleID, dataUUID: app.dataUUID, delegate: self)
        guard let child else { fail(.initialization); return }
        // This is set before its asynchronously created remote scene connects.
        // Older games may capture the initial window size and never rebuild it.
        child.initialInterfaceOrientation = orientation
        guest = child
        addChild(child); child.view.frame = view.bounds; child.view.autoresizingMask = []
        view.insertSubview(child.view, belowSubview: backdrop); child.didMove(toParent: self)
        recordGeometry("starting")
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !appeared { appeared = true; IPAAppSession.shared.didPresent(app.id) }
        hostBecameActive()
        requestOrientation(desiredOrientation); startGuestIfReady(); synchronizeGeometry()
    }
    private func armWatchdog() {
        startupWatchdog?.cancel()
        guard !lifecycle.inBackground, !activated else { return }
        let attempt = attemptID
        startupWatchdog = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(20)) } catch { return }
            guard let self, !self.stopped, !self.returning, !self.lifecycle.inBackground,
                  self.attemptID == attempt, !self.activated, UIApplication.shared.applicationState == .active else { return }
            self.fail(.timeout)
        }
    }
    private func hostInterrupted() {
        guard !stopped, !returning else { return }
        lifecycle.interrupt(); startupWatchdog?.cancel()
        guest?.setBackgroundNotificationEnabled(true)
        recordGeometry("backgrounded")
    }
    private func hostBecameActive() {
        guard !stopped, !returning else { return }
        lifecycle.foreground()
        guest?.setBackgroundNotificationEnabled(true)
        if lifecycle.wasInterrupted, let guest, !guest.isAppRunning, lifecycle.claimResume() {
            restartGuest(); return
        }
        if !activated && starting { armWatchdog() }
        view.setNeedsLayout()
    }
    @objc private func reopenApp() { restartGuest() }
    private func restartGuest() {
        guard !stopped, !returning, UIApplication.shared.applicationState == .active else { return }
        startupWatchdog?.cancel(); attemptID = UUID()
        let old = guest; guest = nil
        old?.delegate = nil; old?.appTerminationCleanUp(); old?.terminate()
        old?.willMove(toParent: nil); old?.view.removeFromSuperview(); old?.removeFromParent()
        failed = false; activated = false; starting = false; lastFrame = .null
        compatibility.isHidden = true; reopen.isHidden = true
        showCover(recovery: false)
        // Old scene/container cleanup is queued first on main. Start the new
        // request after it, keeping the same installed app and data folder.
        DispatchQueue.main.async { [weak self] in self?.startGuestIfReady() }
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.main.async { [weak self] in guard let self else { return }; self.requestOrientation(self.desiredOrientation) }
    }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); startGuestIfReady(); synchronizeGeometry() }
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in self?.view.setNeedsLayout(); self?.view.layoutIfNeeded() }, completion: { [weak self] _ in self?.synchronizeGeometry() })
    }
    private func requestOrientation(_ orientation: UIInterfaceOrientation) {
        guard let scene = view.window?.windowScene else { return }
        let request: UIInterfaceOrientationMask = orientation == .landscapeLeft ? .landscapeLeft : orientation == .landscapeRight ? .landscapeRight : orientation == .portraitUpsideDown ? .portraitUpsideDown : .portrait
        setNeedsUpdateOfSupportedInterfaceOrientations()
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: request)) { [weak self] error in
            Task { @MainActor in self?.orientationError = error.localizedDescription; self?.recordGeometry("orientation-request") }
        }
    }
    private func synchronizeGeometry() {
        guard !stopped, !failed, !lifecycle.inBackground, let guest else { return }
        let orientation = view.window?.windowScene?.interfaceOrientation ?? desiredOrientation
        let bit: UIInterfaceOrientationMask = orientation == .landscapeLeft ? .landscapeLeft : orientation == .landscapeRight ? .landscapeRight : orientation == .portraitUpsideDown ? .portraitUpsideDown : .portrait
        let matchesBounds = orientation.isLandscape ? view.bounds.width >= view.bounds.height : view.bounds.height >= view.bounds.width
        let layoutMatches = mask.contains(bit) && matchesBounds
        let presentation = IPAAppPresentationPolicy.mode(activated: activated, layoutMatches: layoutMatches, failed: failed)
        if presentation == .rotationRequired {
            titleLabel.text = "Currently Playing"
            detailLabel.text = "\(app.name)\nRotate your iPhone to return to the game."
        }
        if presentation == .playing { revealGuest() }
        else { showCover(recovery: presentation != .starting) }
        // The return screen covers unsupported rotations. Preserve the last
        // valid guest geometry instead of sending a portrait resize to a
        // landscape-only game and disturbing its framebuffer/controls.
        guard layoutMatches else { return }
        guest.view.frame = view.bounds
        let frame = IPAGuestGeometry.sceneFrame(in: view.bounds, orientation: orientation)
        let insets = view.safeAreaInsets
        guard frame != lastFrame || orientation != lastOrientation || insets != lastInsets else { return }
        lastFrame = frame; lastOrientation = orientation; lastInsets = insets
        guest.shouldSkipDebounceOnce = true
        guest.updateFrame { settings in
            guard let settings else { return }
            settings.setFrame(frame); settings.setInterfaceOrientation(orientation)
            settings.deviceOrientation = UIDevice.current.orientation
            settings.peripheryInsets = insets
            settings.safeAreaInsetsPortrait = insets; settings.safeAreaInsetsPortraitUpsideDown = insets
            settings.safeAreaInsetsLandscapeLeft = insets; settings.safeAreaInsetsLandscapeRight = insets
            settings.setValue(false, forKey: "statusBarDisabled")
        }
        guest.contentView?.frame = guest.view.bounds
        recordGeometry("layout")
    }
    func appSceneVCWillActivateScene(_ vc: AppSceneViewController!) {
        guard !stopped, !failed, !returning else { return }
        activated = true; failed = false
        lifecycle.activate(at: CACurrentMediaTime()); startupWatchdog?.cancel()
        app.model.forgetCompatibilityLaunch()
        vc.contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        lastFrame = .null
        synchronizeGeometry()
        recordGeometry("activated")
        if !launchURLDelivered, let url = app.launchURL { launchURLDelivered = true; vc.openURLScheme(url) }
    }
    func appSceneVC(_ vc: AppSceneViewController!, didInitializeWithError error: (any Error)!) {
        let attempt = attemptID
        if let error { Task { @MainActor [weak self] in
            guard let self, self.attemptID == attempt else { return }
            guard vc == nil || self.guest == nil || vc === self.guest else { return }
            self.startupError = error as NSError
            self.fail(.exited(activationAge: self.lifecycle.activationTime.map { CACurrentMediaTime() - $0 }))
        } }
    }
    func appSceneVC(_ vc: AppSceneViewController!, didUpdateFrom settings: UIMutableApplicationSceneSettings!, transitionContext context: Any!, lifecycleActionType actionType: UInt32) {
        guard !stopped, let settings else { return }
        let orientation = settings.interfaceOrientation()
        let bit: UIInterfaceOrientationMask = orientation == .landscapeLeft ? .landscapeLeft : orientation == .landscapeRight ? .landscapeRight : orientation == .portraitUpsideDown ? .portraitUpsideDown : .portrait
        if orientation != .unknown && mask.contains(bit) && orientation != view.window?.windowScene?.interfaceOrientation { requestOrientation(orientation) }
        settings.interruptionPolicy = 0
        vc.presenter?.scene.updateSettings(settings, withTransitionContext: context, completion: nil)
        synchronizeGeometry()
    }
    func appSceneVCRequestedReturn(_ vc: AppSceneViewController!) {
        guard !stopped, !returning, vc === guest else { return }
        recordGeometry("return-requested")
        IPAAppSession.shared.close()
    }
    func appSceneVCAppDidExit(_ vc: AppSceneViewController!) {
        guard !stopped, vc === guest else { return }
        fail(.exited(activationAge: lifecycle.activationTime.map { CACurrentMediaTime() - $0 }))
    }
    private func fail(_ failure: IPACompatibilityLaunchPolicy.Failure) {
        guard !stopped, !failed, !returning else { return }
        startupWatchdog?.cancel()
        let wasRunning = activated; activated = false
        if lifecycle.wasInterrupted, UIApplication.shared.applicationState != .active { recordGeometry("closed-in-background"); return }
        if lifecycle.wasInterrupted, lifecycle.claimResume() { restartGuest(); return }
        failed = true
        if IPACompatibilityLaunchPolicy.shouldRetry(failure, alreadyRetried: compatibilityAttempted, wasInterrupted: !lifecycle.allowsCompatibilityDecision || UIApplication.shared.applicationState != .active) {
            recordGeometry("compatibility-required")
            openCompatibility()
            return
        }
        showCover(recovery: true)
        let interrupted = lifecycle.wasInterrupted
        titleLabel.text = interrupted ? "The App Couldn’t Resume" : wasRunning || lifecycle.activationTime != nil ? "The App Closed" : "This App Couldn’t Open Here"
        detailLabel.text = interrupted ? "iOS may close a suspended app to free memory. Reopen it to continue. Saved data is kept, but an unsaved round may restart." : lifecycle.activationTime != nil ? "The app’s process ended. Reopen it to continue. Your saved data is kept." : "Try reopening the app. Compatibility Launch is available if its original launch process is required."
        compatibility.isHidden = interrupted || lifecycle.activationTime != nil
        reopen.isHidden = false
        recordGeometry("failed")
    }
    private func showCover(recovery: Bool) {
        if revealing || backdrop.isHidden || backdrop.alpha != 1 {
            coverGeneration += 1; revealing = false
            backdrop.layer.removeAllAnimations()
        }
        backdrop.alpha = 1; backdrop.isHidden = false
        backdrop.backgroundColor = recovery ? .systemBackground : .black
        panel.isHidden = !recovery
    }
    private func revealGuest() {
        panel.isHidden = true
        guard !revealing, !backdrop.isHidden else { return }
        revealing = true; coverGeneration += 1
        let generation = coverGeneration
        // Activation arrives just before the remote view is attached. Yield
        // once so it is installed and laid out before revealing it.
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.stopped, !self.failed, self.activated, self.coverGeneration == generation else { return }
            self.view.layoutIfNeeded()
            guard self.coverGeneration == generation, !self.stopped, !self.failed else { return }
            UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.20, delay: 0,
                           options: [.curveEaseOut, .beginFromCurrentState], animations: { self.backdrop.alpha = 0 }) { [weak self] _ in
                guard let self, !self.stopped, !self.failed, self.coverGeneration == generation else { return }
                self.backdrop.isHidden = true; self.revealing = false
            }
        }
    }
    override func accessibilityPerformEscape() -> Bool { close(); return true }
    private func recordGeometry(_ phase: String) {
        guard let file = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("iPAStoreGuestLayout.json") else { return }
        let content = guest?.contentView
        let record: [String: Any] = ["phase": phase, "app": app.name, "dataContainer": app.dataUUID, "hostBounds": NSCoder.string(for: view.bounds),
            "hostPID": ProcessInfo.processInfo.processIdentifier, "guestPID": guest?.pid ?? 0,
            "hostOrientation": view.window?.windowScene?.interfaceOrientation.rawValue ?? 0,
            "initialOrientation": guest?.initialInterfaceOrientation.rawValue ?? 0,
            "guestBounds": guest.map { NSCoder.string(for: $0.view.bounds) } ?? "unavailable",
            "contentFrame": content.map { NSCoder.string(for: $0.frame) } ?? "unavailable",
            "contentBounds": content.map { NSCoder.string(for: $0.bounds) } ?? "unavailable",
            "contentTransform": content.map { String(describing: $0.transform) } ?? "unavailable",
            "orientationError": orientationError ?? "", "activated": activated,
            "wasInterrupted": lifecycle.wasInterrupted, "inBackground": lifecycle.inBackground,
            "startupErrorDomain": startupError?.domain ?? "", "startupErrorCode": startupError?.code ?? 0]
        guard let data = try? JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys]) else { return }
        Self.geometryQueue.async { try? data.write(to: file, options: .atomic) }
    }
    func fadeForReturn(completion: @escaping () -> Void) {
        returning = true
        coverGeneration += 1; revealing = false
        let cover = UIView(frame: view.bounds)
        cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]; cover.backgroundColor = .black
        cover.alpha = 0; view.addSubview(cover)
        UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.14, delay: 0,
                       options: [.curveEaseOut, .beginFromCurrentState], animations: { cover.alpha = 1 }) { _ in completion() }
    }
    @objc private func close() { IPAAppSession.shared.close() }
    @objc private func openCompatibility() {
        guard !compatibilityAttempted else { return }
        compatibilityAttempted = true
        let launch = app
        launch.model.rememberCompatibilityLaunch()
        showCover(recovery: false)
        IPAAppSession.shared.close(animated: false, revealStorefront: false)
        Task {
            do {
                try await Task.sleep(for: .milliseconds(350))
                try await launch.model.runApp(containerFolderName: launch.dataUUID, bundleIdOverride: launch.bundleID, urlStr: launch.launchURL, directLaunch: false, provideFeedback: false)
            } catch {
                launch.model.forgetCompatibilityLaunch()
                IPAAppSession.shared.releaseCompatibilityCover()
                IPAInstallCoordinator.shared.issue = .from(error)
            }
        }
    }
    func stop() {
        guard !stopped else { return }; stopped = true
        startupWatchdog?.cancel()
        for observer in observers { NotificationCenter.default.removeObserver(observer) }; observers.removeAll()
        coverGeneration += 1; revealing = false; backdrop.layer.removeAllAnimations()
        guest?.terminate(); guest?.willMove(toParent: nil); guest?.view.removeFromSuperview(); guest?.removeFromParent(); guest = nil
    }
}
#endif
