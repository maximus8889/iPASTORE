//
//  SideStore.swift
//  SideStoreSupport
//
//  Created by s s on 2025/7/20.
//

import Foundation
import AppIntents
import UserNotifications

@available(iOS 17.0, *)
func performIntentRefresh(identifier: String, mangledTypeName: String, intentProgress: Progress) async throws {
    intentProgress.totalUnitCount = 100
    if UserDefaults.isSideStore() {
        try await SideStoreIntentCaller.shared.callRefreshIntent(mangledTypeName: mangledTypeName)
    } else {
        try await RefreshHandler.shared.startRefresh(identifier: identifier, mangledName: mangledTypeName, taskProgress: intentProgress)
    }
}

@available(iOS 17.0, *)
public struct RefreshAllAppsWidgetIntent: AppIntent, ProgressReportingIntent
{
    public static var title: LocalizedStringResource { "Refresh Apps via Widget" }
    public static var isDiscoverable: Bool { false } // Don't show in Shortcuts or Spotlight.
    
    public init() {}
    
    public func perform() async throws -> some IntentResult
    {
        try await performIntentRefresh(identifier: "RefreshAllAppsWidgetIntent", mangledTypeName: "9SideStore26RefreshAllAppsWidgetIntentV", intentProgress: progress)
        return .result()
    }
}

@available(iOS 17.0, *)
public struct RefreshAllAppsIntent: AppIntent, CustomIntentMigratedAppIntent, PredictableIntent, ProgressReportingIntent, ForegroundContinuableIntent
{
    public static let intentClassName = "RefreshAllIntent"
    
    public static var title: LocalizedStringResource = "Refresh"
    public static var description = IntentDescription("Refreshes your sideloaded apps to prevent them from expiring.")
    
    public init() {}
    
    public static var parameterSummary: some ParameterSummary {
        Summary("Refresh")
    }
    
    public static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction {
            DisplayRepresentation(
                title: "Refresh",
                subtitle: ""
            )
        }
    }
    
    public func perform() async throws -> some IntentResult & ProvidesDialog
    {
        try await performIntentRefresh(identifier: "RefreshAllIntent", mangledTypeName: "9SideStore20RefreshAllAppsIntentV", intentProgress: progress)
        return .result(dialog: "Signing completed.")
    }
    
}


class RefreshHandler: NSObject, RefreshServer {
    static let shared = RefreshHandler()
    private let lock = NSLock()
    private var active = false
    private var cancellationRequested = false
    private var nativeResult: [String: String]?
    private var resultGate: IPAResultGate<Void>?
    private var launchGate: IPAResultGate<Void>?
    private var generation = UUID()
    private var _progress: Progress?
    private var listener: NSXPCListener?
    private var sideStorePid: Int32 = 0
    private var client: RefreshClient?
    private var connection: NSXPCConnection?
    private var ext: NSExtension?
    var progress: Progress? {
        get { lock.withLock { _progress } }
        set { lock.withLock { _progress = newValue } }
    }

    @discardableResult func startRefresh(identifier: String, mangledName: String, request: [String: String]? = nil, taskProgress: Progress? = nil) async throws -> [String: String] {
        let acquired = lock.withLock {
            guard !active else { return false }
            active = true; cancellationRequested = false; nativeResult = nil; _progress = taskProgress
            return true
        }
        guard acquired else { throw failure("Another signing task is in progress.") }
        defer { lock.withLock { active = false; resultGate = nil; launchGate = nil } }
        try Task.checkCancellation()
        if listener == nil {
            guard let listener = startAnonymousListener(self) else { throw failure("Unable to start signing. Please try again.") }
            self.listener = listener
        }
        guard let listener else { throw failure("Unable to start signing. Please try again.") }
        let needsLaunch = lock.withLock { sideStorePid <= 0 || getpgid(sideStorePid) <= 0 || client == nil }
        if needsLaunch {
            guard let home = getenv("LC_HOME_PATH") else { throw failure("The signing storage location is unavailable.") }
            let serviceHome = URL(fileURLWithPath: String(cString: home)).appendingPathComponent("Documents/SideStore")
            try FileManager.default.createDirectory(at: serviceHome, withIntermediateDirectories: true)
            guard let bookmark = bookmarkForURL(serviceHome) else { throw failure("Unable to access signing storage.") }
            guard let url = UserDefaults.lcMainBundle().builtInPlugInsURL?.appendingPathComponent("LiveProcess.appex"), let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier else { throw failure("Reinstall IPAStore with all app extensions retained.") }
            let process = try NSExtension(identifier: identifier)
            let gate = IPAResultGate<Void>()
            let token = UUID()
            let oldConnection = lock.withLock { () -> NSXPCConnection? in
                let old = connection
                generation = token; launchGate = gate; ext = process; client = nil; connection = nil
                return old
            }
            oldConnection?.invalidate()
            process.setRequestInterruptionBlock { [weak self] _ in self?.workerFailed(token: token, message: "The signing service stopped unexpectedly. Please try again.") }
            let item = NSExtensionItem()
            item.userInfo = ["selected": "builtinSideStore", "bookmarks": [bookmark], "endpoint": listener.endpoint]
            try Task.checkCancellation()
            if lock.withLock({ cancellationRequested }) { throw CancellationError() }
            let request = await process.beginRequest(withInputItems: [item])
            lock.withLock { sideStorePid = process.pid(forRequestIdentifier: request) }
            DispatchQueue.global().asyncAfter(deadline: .now() + 60) {
                let error = NSError(domain: "IPAStore.Signing", code: 1, userInfo: [NSLocalizedDescriptionKey: "Signing could not start. Please try again."])
                if gate.finish(.failure(error)) { process._kill(9) }
            }
            if lock.withLock({ cancellationRequested }) { gate.finish(.failure(CancellationError())) }
            do { try await gate.wait() }
            catch {
                process._kill(9)
                lock.withLock { if generation == token { sideStorePid = 0; client = nil } }
                throw error
            }
        }
        let gate = IPAResultGate<Void>()
        let worker: RefreshClient? = lock.withLock { resultGate = gate; return client }
        guard let worker else { throw failure("The signing connection is unavailable. Please try again.") }
        try Task.checkCancellation()
        guard !lock.withLock({ cancellationRequested }) else { throw CancellationError() }
        // Install the reply gate before dispatching, including fast setup failures.
        if let request {
            worker.performIPAStoreTask(withRequest: request) { [weak self] result, error in
                if let error { gate.finish(.failure(error)) }
                else {
                    self?.lock.withLock { self?.nativeResult = result }
                    gate.finish(.success(()))
                }
            }
        } else { worker.refreshAllApps(withIdentifier: identifier, mangledTypeName: mangledName) }
        if lock.withLock({ cancellationRequested }) { worker.cancelRefresh() }
        try await gate.wait()
        return lock.withLock { nativeResult ?? [:] }
    }
    func performNativeTask(_ request: [String: String], progress: Progress) async throws -> [String: String] {
        progress.totalUnitCount = 100
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await startRefresh(identifier: "IPAStoreInstallation", mangledName: "", request: request, taskProgress: progress)
        } onCancel: { self.requestCancellation() }
    }
    func requestCancellation() {
        let state = lock.withLock { () -> (Bool, RefreshClient?, IPAResultGate<Void>?, Bool) in
            guard active else { return (false, nil, nil, false) }
            cancellationRequested = true
            return (true, client, launchGate, resultGate != nil)
        }
        guard state.0 else { return }
        if state.3 { state.1?.cancelRefresh() }
        else { state.2?.finish(.failure(CancellationError())) }
    }
    private func workerFailed(token: UUID, message: String) {
        let gates = lock.withLock { () -> (IPAResultGate<Void>?, IPAResultGate<Void>?) in
            guard generation == token else { return (nil, nil) }
            sideStorePid = 0; client = nil
            return (launchGate, resultGate)
        }
        gates.0?.finish(.failure(failure(message)))
        gates.1?.finish(.failure(failure(message)))
    }
    private func failure(_ message: String) -> NSError { NSError(domain: "IPAStore.Signing", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    func updateProgress(_ value: Double) { progress?.completedUnitCount = Int64(min(max(value, 0), 1) * 100) }
    func finish(_ error: String?) {
        let gate = lock.withLock { resultGate }
        if let error { gate?.finish(.failure(failure(error))) }
        else { gate?.finish(.success(())) }
    }
    func onConnection(_ connection: NSXPCConnection!) {
        guard let connection else { return }
        connection.remoteObjectInterface = NSXPCInterface(with: RefreshClient.self)
        let token = lock.withLock { generation }
        let proxy = connection.remoteObjectProxyWithErrorHandler { [weak self] _ in self?.workerFailed(token: token, message: "The signing connection was interrupted. Please try again.") } as? RefreshClient
        lock.withLock { self.connection = connection; client = proxy }
    }
    func finishedLaunching() { lock.withLock { launchGate }?.finish(.success(())) }
    func add(_ request: UNNotificationRequest) { UNUserNotificationCenter.current().add(request) { _ in } }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers) }
}

@available(iOS 17.0, *)
public func cancelIPAStoreRefresh() { RefreshHandler.shared.requestCancellation() }

@available(iOS 17.0, *)
public func performIPAStoreSigningTask(_ request: [String: String], progress: Progress) async throws -> [String: String] {
    try await RefreshHandler.shared.performNativeTask(request, progress: progress)
}
