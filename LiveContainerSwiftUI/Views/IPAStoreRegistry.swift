import Foundation

struct IPAStoreSuggestion: Identifiable, Hashable {
    let id: String
    let name: String
    let summary: String
    let url: URL
    let publisher: URL
    var developer: String? = nil
    var artwork: URL? = nil
    var marketplaceOnly = false
    var webURL: URL? = nil
}

enum IPAStoreDirectory {
    // Publisher-hosted feeds checked on 2026-11-07. No app downloads occur here.
    private static let curated: [IPAStoreSuggestion] = [
        .init(id: "altstore", name: "AltStore", summary: "Independent apps from the creators of Delta and Clip.", url: URL(string: "https://apps.altstore.io/")!, publisher: URL(string: "https://altstore.io/")!),
        .init(id: "community", name: "Community Picks", summary: "A community-maintained collection of open-source apps.", url: URL(string: "https://community-apps.sidestore.io/sidecommunity.json")!, publisher: URL(string: "https://sidestore.io/")!),
        .init(id: "utm", name: "UTM", summary: "Virtual machines and computing tools for iPhone and iPad.", url: URL(string: "https://alt.getutm.app/")!, publisher: URL(string: "https://getutm.app/")!),
        .init(id: "ish", name: "iSH", summary: "A Linux shell environment for iOS.", url: URL(string: "https://ish.app/altstore.json")!, publisher: URL(string: "https://ish.app/")!),
        .init(id: "dolphinios", name: "OatmealDome", summary: "DolphiniOS releases from its developer.", url: URL(string: "https://altstore.oatmealdome.me/")!, publisher: URL(string: "https://dolphinios.oatmealdome.me/")!),
        .init(id: "provenance", name: "Provenance", summary: "A multi-system emulator and its release channels.", url: URL(string: "https://provenance-emu.com/apps.json")!, publisher: URL(string: "https://provenance-emu.com/")!),
        .init(id: "flycast", name: "Flyinghead", summary: "Flycast builds published by its developer.", url: URL(string: "https://flyinghead.github.io/flycast-builds/altstore.json")!, publisher: URL(string: "https://github.com/flyinghead/flycast")!),
        .init(id: "stikdebug", name: "StikDebug", summary: "On-device debugging tools from the StikDebug project.", url: URL(string: "https://stikdebug.xyz/index.json")!, publisher: URL(string: "https://github.com/StikDebug/StikDebug")!),
        .init(id: "ignited", name: "Ignited", summary: "A polished multi-system emulator from LitRitt.", url: URL(string: "https://altstore.ignitedemulator.com/")!, publisher: URL(string: "https://docs.ignitedemulator.com/")!),
        .init(id: "feather", name: "Feather", summary: "An open-source app manager for developer certificates.", url: URL(string: "https://raw.githubusercontent.com/khcrysalis/Feather/main/app-repo.json")!, publisher: URL(string: "https://github.com/claration/feather")!)
    ]
    private struct Snapshot: Decodable { let libraries: [Record] }
    private struct Record: Decodable {
        let id: String; let name: String; let summary: String; let url: URL; let publisher: URL
        let developer: String?; let artwork: URL?; let marketplaceOnly: Bool; let webURL: URL?
    }
    // Bundled registry snapshot: the complete iOS Hub list remains visible even
    // when an endpoint is offline. A live feed is validated before it is added.
    static let suggestions: [IPAStoreSuggestion] = {
        guard let file = Bundle.main.url(forResource: "LibraryDirectory", withExtension: "json"), let data = try? Data(contentsOf: file) else { return curated }
        return mergingSnapshot(data)
    }()
    static func mergingSnapshot(_ data: Data) -> [IPAStoreSuggestion] {
        guard let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return curated }
        var result = curated
        var urls = Set(result.map { canonical($0.url) })
        for item in snapshot.libraries {
            if let index = result.firstIndex(where: { canonical($0.url) == canonical(item.url) }) {
                result[index].artwork = item.artwork ?? result[index].artwork
                result[index].marketplaceOnly = item.marketplaceOnly
                result[index].developer = item.developer
                result[index].webURL = item.webURL
                continue
            }
            guard urls.insert(canonical(item.url)).inserted else { continue }
            result.append(.init(id: item.id, name: item.name, summary: item.summary, url: item.url, publisher: item.publisher,
                                developer: item.developer, artwork: item.artwork, marketplaceOnly: item.marketplaceOnly, webURL: item.webURL))
        }
        return result
    }
    private static let byURL: [String: IPAStoreSuggestion] = Dictionary(suggestions.map { (canonical($0.url), $0) }, uniquingKeysWith: { first, _ in first })
    static func suggestion(for url: URL) -> IPAStoreSuggestion? { byURL[canonical(url)] }
    static func title(for item: AltStoreSourcesViewModel.SourceItem) -> String {
        suggestion(for: item.url)?.name ?? item.displayName
    }
    static func canonical(_ url: URL) -> String { AltStoreSourceLoader.canonical(url) }
}

extension IPAStoreSuggestion {
    var editorialDescription: String {
        switch id {
        case "altstore": return "A focused collection from Riley Testut and the AltStore team. Explore Delta for classic game systems and Clip for clipboard tools, with available editions listed inside each app. Add this library to browse its releases from IPAStore."
        case "community": return "A varied, community-maintained collection of independent and open-source apps. Discover emulators, utilities and experiments in one library. Each app keeps its original developer information and download source."
        case "utm": return "A home for UTM and UTM SE, published by the UTM project. Explore different approaches to virtual machines and computer emulation. Availability of features such as JIT depends on your device and installation method."
        case "ish": return "A small library dedicated to iSH: a Linux shell environment for iPhone and iPad. Explore the project's published app and release information, all from its official source."
        case "dolphinios": return "DolphiniOS releases published by OatmealDome. Compare the available editions from the app's details. Emulation features and JIT requirements depend on your iOS version and device setup."
        case "provenance": return "Explore the Provenance project's multi-system emulator and related apps. Published release channels are grouped into clear app listings, with individual editions available in their details."
        case "flycast": return "Flycast builds published by its developer, Flyinghead. A focused library for following the project's iOS releases. Device support and runtime requirements vary by build."
        case "stikdebug": return "Debugging utilities published by the StikDebug project. Browse the available tools and their own setup requirements. Adding this library does not configure JIT or device pairing automatically."
        case "ignited": return "Ignited is LitRitt's multi-system emulator, with a library focused on the developer's published releases. Explore version details and previews before choosing an edition."
        case "feather": return "Feather is an open-source application manager for iPhone and iPad. Its own signing features require compatible certificates and provisioning. Browse the developer's published release here."
        default: return summary
        }
    }
}


extension IPAStoreSuggestion {
    var bundledIconName: String { "Library-" + id }
    var iconURL: URL? { artwork ?? Self.publisherIcons[id].flatMap(URL.init(string:)) }
    private static let publisherIcons: [String: String] = [
        "altstore": "https://user-images.githubusercontent.com/705880/65270980-1eb96f80-dad1-11e9-9367-78ccd25ceb02.png",
        "community": "https://sidestore.io/assets/icon.png",
        "utm": "https://alt.getutm.app/icon.png",
        "ish": "https://ish.app/assets/icon-full.png",
        "dolphinios": "https://cdn.oatmealdome.me/dolphinios/AppIcon.appiconset/ios_marketing1024x1024.png",
        "provenance": "https://raw.githubusercontent.com/Provenance-Emu/Provenance/develop/Provenance/Resources/Assets.xcassets/AppIcon.appiconset/iTunesArtwork%402x.png",
        "flycast": "https://github.com/flyinghead/flycast/raw/master/shell/linux/flycast.png",
        "stikdebug": "https://github.com/StikDebug/StikDebug/blob/main/assets/StikDebug.png?raw=true",
        "ignited": "https://cdn.ignitedemulator.com/assets/altstore-icon.png",
        "feather": "https://github.com/khcrysalis/Feather/blob/v1.x/iOS/Resources/Icons/Main/Mac@3x.png?raw=true"
    ]
}
