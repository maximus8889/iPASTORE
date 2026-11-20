import Foundation
import SwiftUI

enum IPADistribution {
    static let repository = "maximus8889/iPAStore"
    static let installer = URL(string: "https://maximus8889.github.io/iPAStore/install.html")!
    static let latestReleaseEndpoint = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!

    struct Release: Decodable {
        let tag: String
        let page: URL
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case tag = "tag_name"
            case page = "html_url"
            case draft, prerelease, assets
        }

        struct Asset: Decodable {
            let name: String
            let state: String
            let size: Int
            let download: URL

            enum CodingKeys: String, CodingKey {
                case name, state, size
                case download = "browser_download_url"
            }
        }

        var build: Int? {
            guard !draft, !prerelease,
                  tag.range(of: #"^v[0-9]+\.[0-9]+\.[0-9]+-build[0-9]+$"#, options: .regularExpression) != nil,
                  page.absoluteString == "https://github.com/\(repository)/releases/tag/\(tag)" else { return nil }
            return tag.components(separatedBy: "-build").last.flatMap(Int.init)
        }

        var ipa: URL? {
            guard build != nil else { return nil }
            let download = "https://github.com/\(repository)/releases/download/\(tag)/iPAStore.ipa"
            return assets.first {
                $0.name == "iPAStore.ipa" && $0.state == "uploaded" && $0.size > 0 && $0.download.absoluteString == download
            }?.download
        }
    }
}

struct IPAUpdatesView: View {
    @State private var checking = false
    @State private var result: String?
    @State private var release: IPADistribution.Release?
    private var installedBuild: Int? {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String).flatMap(Int.init)
    }

    var body: some View {
        Form {
            Section {
                Label("iPAStore", systemImage: "arrow.triangle.2.circlepath").ipaFont(.headline)
                LabeledContent("Installed Version", value: "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—") (\(installedBuild.map(String.init) ?? "—"))")
                Button { Task { await check() } } label: {
                    HStack {
                        Text(checking ? "Checking…" : "Check for Updates")
                        Spacer()
                        if checking { ProgressView() }
                    }
                }.disabled(checking)
                if let result { Text(result).foregroundStyle(.secondary) }
                if let release {
                    if let build = release.build, let installedBuild, build > installedBuild, let ipa = release.ipa {
                        Link("Download Build \(build)", destination: ipa)
                    }
                    Link("View Latest Release", destination: release.page)
                }
            }
            Section {
                Link("Open Download & Install Page", destination: IPADistribution.installer)
            } footer: {
                Text("To keep your apps and data, install over your current copy with the same signing team and bundle identifier. Use the installer you used for your current copy.")
            }
        }.navigationTitle("Updates").navigationBarTitleDisplayMode(.inline).ipaNativePage()
    }

    private func check() async {
        checking = true
        result = nil
        release = nil
        defer { checking = false }
        do {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 20
            configuration.httpCookieStorage = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            let session = URLSession(configuration: configuration)
            defer { session.invalidateAndCancel() }
            let (data, response) = try await session.data(from: IPADistribution.latestReleaseEndpoint)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            if http.statusCode == 404 {
                result = "No public release is available yet."
                return
            }
            guard http.statusCode == 200, data.count <= 1_048_576 else { throw URLError(.badServerResponse) }
            let latest = try JSONDecoder().decode(IPADistribution.Release.self, from: data)
            guard let build = latest.build else { throw URLError(.badServerResponse) }
            release = latest
            if let installedBuild, build <= installedBuild {
                result = "You’re up to date."
            } else if latest.ipa != nil {
                result = "Build \(build) is available."
            } else {
                result = "Build \(build) is listed. Its download isn’t available yet."
            }
        } catch {
            result = "Couldn’t check for updates. Check your connection and try again."
        }
    }
}
