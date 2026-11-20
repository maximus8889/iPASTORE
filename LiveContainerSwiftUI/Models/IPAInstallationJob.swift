import SwiftUI

@MainActor final class IPAInstallationJob: ObservableObject, Identifiable {
    let id: String
    let variant: IPAAppVariant
    let independent: Bool
    @Published var status = "Preparing…"
    @Published var fraction: Double?
    @Published var received: Int64 = 0
    @Published var expected: Int64 = 0
    @Published var paused = false
    @Published var downloading = false
    @Published var cancelling = false
    @Published var failure: IPAInstallIssue?
    var transfer: IPADownloadTransfer?
    var task: Task<Void, Never>?
    var terminal: Bool { failure != nil }
    init(variant: IPAAppVariant, independent: Bool) { self.id = variant.id; self.variant = variant; self.independent = independent }
}

struct IPAInstallationJobRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var job: IPAInstallationJob
    @ObservedObject private var installer = IPAInstallCoordinator.shared
    var body: some View {
        HStack(spacing: 12) {
            IPAArtwork(url: job.variant.app.iconURL, size: 58, identifier: job.variant.app.bundleIdentifier)
            VStack(alignment: .leading, spacing: 4) {
                Text(job.variant.app.name).ipaFont(.headline).lineLimit(1)
                Text(job.failure?.title ?? job.status).ipaFont(.caption).foregroundStyle(.secondary).lineLimit(1)
                if job.downloading && job.received > 0 {
                    Text(job.expected > 0 ? "\(ByteCountFormatter.string(fromByteCount: job.received, countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: job.expected, countStyle: .file))" : ByteCountFormatter.string(fromByteCount: job.received, countStyle: .file)).ipaFont(.caption2).foregroundStyle(.secondary)
                }
                if job.failure == nil {
                    if job.downloading, let fraction = job.fraction { ProgressView(value: fraction).animation(reduceMotion ? nil : .linear(duration: 0.12), value: fraction) }
                    else { ProgressView().controlSize(.mini) }
                }
            }
            Spacer(minLength: 0)
            if job.failure != nil {
                Button { installer.showFailure(job.id) } label: { Image(systemName: "exclamationmark.circle") }.accessibilityLabel("Show installation help")
                Button { installer.remove(job.id) } label: { Image(systemName: "xmark.circle") }.accessibilityLabel("Remove download")
            } else {
                if job.downloading {
                    Button { installer.pause(job.id, paused: !job.paused) } label: { Image(systemName: job.paused ? "play.fill" : "pause.fill") }.accessibilityLabel(job.paused ? "Resume download" : "Pause download")
                }
                Button { installer.cancel(job.id) } label: { Image(systemName: "xmark.circle") }.disabled(job.cancelling).accessibilityLabel("Cancel download")
            }
        }.buttonStyle(IPAControlPressStyle()).padding(.vertical, 8)
    }
}

struct IPAJobProgressButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var job: IPAInstallationJob
    var showsStatus = false
    @ObservedObject private var installer = IPAInstallCoordinator.shared
    var body: some View {
        HStack(spacing: 8) {
            Button { installer.cancel(job.id) } label: {
                ZStack {
                    Circle().stroke(.tint.opacity(0.18), lineWidth: 2.5)
                    if job.downloading, let fraction = job.fraction {
                        Circle().trim(from: 0, to: min(1, max(0, fraction))).stroke(.tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round)).rotationEffect(.degrees(-90)).animation(reduceMotion ? nil : .linear(duration: 0.12), value: fraction)
                    } else { ProgressView().controlSize(.small) }
                    if job.downloading && job.fraction != nil { Image(systemName: job.paused ? "pause.fill" : "stop.fill").font(.system(size: 10)).contentTransition(.opacity) }
                }.frame(width: 30, height: 30).padding(6)
            }.buttonStyle(IPAControlPressStyle()).disabled(job.cancelling)
                .accessibilityLabel("Cancel installation of \(job.variant.app.name)")
                .accessibilityValue((job.downloading ? job.fraction : nil).map { "\(Int($0 * 100)) percent, \(job.status)" } ?? job.status)
            if showsStatus { Text(job.status.replacingOccurrences(of: "…", with: "")).ipaFont(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.85).contentTransition(.opacity) }
        }.animation(IPAMotion.state(reduced: reduceMotion), value: job.paused)
            .animation(.easeOut(duration: 0.15), value: job.status)
    }
}
