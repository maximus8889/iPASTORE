import Foundation
import SwiftUI

enum IPADistribution {
    static let repository = "maximus8889/iPAStore"
    static let homepage = URL(string: "https://maximus8889.github.io/iPAStore/")!
    static var latestIPA: URL? { URL(string: "https://github.com/\(repository)/releases/latest/download/iPAStore.ipa") }

}

struct IPAUpdatesView: View {
    @State private var checking = false
    @State private var result: String?
    @State private var releaseURL: URL?
    var body: some View {
        Form {
            Section {
                Label("iPAStore", systemImage: "arrow.triangle.2.circlepath").ipaFont(.headline)
                LabeledContent("Installed Version", value: "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"))")
                Button { Task { await check() } } label: {
                    HStack { Text(checking ? "Checking…" : "Check for Updates"); Spacer(); if checking { ProgressView() } }
                }.disabled(checking)
                if let result { Text(result).foregroundStyle(.secondary) }
            }
            Section {
                if let releaseURL { Link("View Latest Release", destination: releaseURL) }
                Link("Open Download Page", destination: IPADistribution.homepage)
            } footer: { Text("Updates are published through GitHub. iOS requires you to approve and sign an updated IPA with a valid installation method. Existing data normally stays when the bundle identity and signing setup are retained.") }
        }.navigationTitle("Updates").navigationBarTitleDisplayMode(.inline).ipaNativePage()
    }
    private func check() async {
        checking = true; defer { checking = false }
        do {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 20
            configuration.httpCookieStorage = nil
            let session = URLSession(configuration: configuration); defer { session.invalidateAndCancel() }
            let (data, response) = try await session.data(from: URL(string: "https://api.github.com/repos/\(IPADistribution.repository)/releases/latest")!)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            if http.statusCode == 404 { result = "No public release is available yet."; return }
            guard http.statusCode == 200, data.count <= 1_048_576,
                  let info = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let name = info["tag_name"] as? String, let raw = info["html_url"] as? String,
                  let url = URL(string: raw), url.scheme == "https", url.host == "github.com" else { throw URLError(.badServerResponse) }
            releaseURL = url
            result = "Latest release: \(name). Open the release to compare its version and review the changes."
        } catch { result = "Couldn’t check for updates. Check your connection and try again." }
    }
}
