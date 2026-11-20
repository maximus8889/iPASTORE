import SwiftUI

struct IPASigningSetupPage: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var state: IPASigningState
    @ObservedObject private var renewal = IPARenewalManager.shared
    @ObservedObject private var installer = IPAInstallCoordinator.shared
    var body: some View {
        Group {
            #if IPASTORE_PREVIEW
            IPAEmptyState(title: "Signing Setup", subtitle: "Account and device pairing setup is available in the complete iPhone build.", symbol: "checkmark.shield")
            #else
            if renewal.working || installer.busy {
                IPAEmptyState(title: "Signing in Progress", subtitle: "Let signing finish before changing your setup.", symbol: "clock")
            } else if !state.serviceAvailable || !state.capabilitiesReady {
                IPAEmptyState(title: "Complete Build Required", subtitle: "Install iPAStore with all its app extensions retained to use signing setup.", symbol: "checkmark.shield")
            } else {
                IPAInteractiveSigningScene(state: state) { dismiss() }.ignoresSafeArea()
                    .toolbar(.hidden, for: .navigationBar, .tabBar)
            }
            #endif
        }.background(IPAStyle.canvas).navigationTitle("Signing Setup").navigationBarTitleDisplayMode(.inline)
            .onAppear { UserDefaults.standard.set(true, forKey: "IPASigningSetupOpen") }
            .onDisappear { UserDefaults.standard.set(false, forKey: "IPASigningSetupOpen"); state.importInteractiveReadiness(allowCertificateImport: true) }
    }
}

#if !IPASTORE_PREVIEW
private struct IPAInteractiveSigningScene: UIViewControllerRepresentable {
    let state: IPASigningState
    let done: () -> Void
    func makeUIViewController(context: Context) -> IPAInteractiveSigningController { IPAInteractiveSigningController(state: state, done: done) }
    func updateUIViewController(_ controller: IPAInteractiveSigningController, context: Context) {}
    static func dismantleUIViewController(_ controller: IPAInteractiveSigningController, coordinator: ()) { controller.stop() }
}

// Hosts the signing UI in its existing isolated process, without restarting
// iPAStore or loading guest bundle/keychain hooks into the storefront process.
private final class IPAInteractiveSigningController: UIViewController, AppSceneViewControllerDelegate {
    private static let timingQueue = DispatchQueue(label: "app.ipastore.signing-startup", qos: .utility)
    private let createdAt = CACurrentMediaTime()
    private let done: () -> Void
    private let state: IPASigningState
    private var overview: UIViewController?
    private var lastFrame = CGRect.null
    private var lastInsets = UIEdgeInsets.zero
    private var scene: AppSceneViewController?
    private var stopped = false
    private var activated = false
    private let message = UILabel()
    private let cancel = UIButton(type: .system)
    init(state: IPASigningState, done: @escaping () -> Void) { self.state = state; self.done = done; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let local = UIHostingController(rootView: IPAAccountSetupOverview(state: state).modifier(IPATheme()))
        overview = local; addChild(local); local.view.frame = view.bounds
        local.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(local.view); local.didMove(toParent: self)
        message.isHidden = true; message.textColor = .secondaryLabel; message.textAlignment = .center; message.numberOfLines = 0
        message.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(message)
        cancel.setTitle("Back", for: .normal); cancel.translatesAutoresizingMaskIntoConstraints = false
        cancel.addTarget(self, action: #selector(close), for: .touchUpInside); view.addSubview(cancel)
        NSLayoutConstraint.activate([
            message.centerYAnchor.constraint(equalTo: view.centerYAnchor), message.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24), message.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            cancel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8), cancel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20), cancel.heightAnchor.constraint(equalToConstant: 44)
        ])
        // Let the local instructions draw while the isolated tools start. No
        // certificate reads, account prewarming or network request is needed.
        DispatchQueue.main.async { [weak self] in self?.startSigning() }
    }
    private func startSigning() {
        guard !stopped, scene == nil else { return }
        let child = AppSceneViewController(bundleId: "builtinSideStore", dataUUID: "IPAStoreSigningSetup", delegate: self)
        guard let child else { showFailure("Signing setup couldn’t start. Go back and try again."); return }
        scene = child; addChild(child); child.view.frame = view.bounds; child.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(child.view, at: 0); child.didMove(toParent: self); view.setNeedsLayout()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard let self, !self.stopped, !self.activated else { return }
            self.showFailure("Signing setup couldn’t start. Go back and try again.")
        }
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let scene, lastFrame != view.bounds || lastInsets != view.safeAreaInsets else { return }
        lastFrame = view.bounds; lastInsets = view.safeAreaInsets
        scene.view.frame = view.bounds
        scene.updateFrame { [weak self] settings in
            guard let self, let settings else { return }
            settings.setFrame(self.view.bounds)
            settings.safeAreaInsetsPortrait = self.view.safeAreaInsets
            settings.peripheryInsets = self.view.safeAreaInsets
        }
    }
    func appSceneVCWillActivateScene(_ vc: AppSceneViewController!) {
        guard !stopped else { return }
        activated = true; lastFrame = .null
        recordStartupTiming("ready")
        view.setNeedsLayout()
        vc.updateSettings { [weak self] settings in
            guard let self, let settings else { return }
            settings.setValue(false, forKey: "statusBarDisabled")
            settings.safeAreaInsetsPortrait = self.view.safeAreaInsets
            settings.peripheryInsets = self.view.safeAreaInsets
            settings.setFrame(self.view.bounds)
        }
        message.isHidden = true; cancel.isHidden = true
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.stopped, let overview = self.overview else { return }
            UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.12, animations: { overview.view.alpha = 0 }) { [weak self] _ in
                guard let self, self.overview === overview else { return }
                overview.willMove(toParent: nil); overview.view.removeFromSuperview(); overview.removeFromParent(); self.overview = nil
            }
        }
    }
    private func recordStartupTiming(_ phase: String) {
        guard let file = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("iPAStoreSigningSetupTiming.json"),
              let data = try? JSONSerialization.data(withJSONObject: ["phase": phase, "elapsedMilliseconds": Int((CACurrentMediaTime() - createdAt) * 1000)]) else { return }
        Self.timingQueue.async { try? data.write(to: file, options: .atomic) }
    }
    private func showFailure(_ text: String) {
        recordStartupTiming("failed")
        overview?.view.isHidden = true
        message.text = text; message.isHidden = false; cancel.isHidden = false
    }
    func appSceneVC(_ vc: AppSceneViewController!, didInitializeWithError error: (any Error)!) {
        guard !stopped else { return }
        if error != nil { showFailure("Signing setup couldn’t start. Go back and try again.") }
    }
    func appSceneVCAppDidExit(_ vc: AppSceneViewController!) {
        guard !stopped else { return }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let returned = documents.map { FileManager.default.fileExists(atPath: $0.appendingPathComponent("SideStore/Documents/IPAStoreSetupStatus.plist").path) } ?? false
        stop()
        if returned { done() }
        else {
            showFailure("Signing setup closed before finishing. Your installed apps are still here. Go back and try again. If it happens when opening the VPN, open LocalDevVPN from the Home Screen first, connect it, then return to setup.")
        }
    }
    @objc private func close() { stop(); done() }
    func stop() {
        guard !stopped else { return }
        stopped = true
        scene?.terminate()
        scene?.willMove(toParent: nil); scene?.view.removeFromSuperview(); scene?.removeFromParent(); scene = nil
    }
}

// Meaningful local content replaces the empty process-start gap. Readiness is
// informational here; only the live signing service can verify prerequisites.
private struct IPAAccountSetupOverview: View {
    @ObservedObject var state: IPASigningState
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: IPASetupSymbols.free).font(.system(size: 38, weight: .light)).foregroundStyle(.tint)
                Text("Signing Setup").ipaFont(.largeTitle, weight: .bold)
                Text("Connect once. Renew easily.").ipaFont(.title2, weight: .bold)
                Text("Set up your iPhone’s connection and signing account below.").ipaFont(.subheadline).foregroundStyle(.secondary)
                step("Device Pairing", detail: state.pairingImported ? "Pairing file imported" : "Import this iPhone’s pairing file.", symbol: "iphone.and.arrow.forward")
                step("Local Connection", detail: "Connect your local VPN and verify the connection.", symbol: "network")
                step("Signing Account", detail: state.accountSaved ? "Account saved" : "Connect your Apple Account.", symbol: "person.crop.circle.badge.checkmark")
                ProgressView().controlSize(.small).accessibilityLabel("Preparing signing tools")
            }.padding(24).padding(.top, 60).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background(IPAStyle.canvas)
    }
    private func step(_ title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).ipaFont(.title2).foregroundStyle(.tint).frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).ipaFont(.headline)
                Text(detail).ipaFont(.subheadline).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
