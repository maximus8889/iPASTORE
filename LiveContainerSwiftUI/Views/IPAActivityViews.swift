import SwiftUI

struct IPAHistoryRow: View {
    let record: IPAActivityRecord
    @EnvironmentObject private var index: IPAAllAppsIndex
    private var entry: IPAAppEntry? {
        guard let candidate = index.entry(identifier: record.identifier) else { return nil }
        // Keep the actual publisher when a history entry came from a specific library.
        if let url = record.libraryURL,
           let variant = candidate.variants.first(where: { $0.store.id == IPAStoreDirectory.canonical(url) }) { return .init(id: candidate.id, variants: [variant]) }
        return candidate
    }
    var body: some View {
        Group {
            if let entry { IPAAppRow(entry: entry) }
            else {
                NavigationLink { IPAHistoryDetail(record: record) } label: {
                    HStack(spacing: 12) {
                        IPAArtwork(url: record.iconURL, size: 60, identifier: record.identifier)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.name).ipaFont(.headline, weight: .semibold).lineLimit(1)
                            Text(record.libraryName ?? "Imported from Files").ipaFont(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right").ipaFont(.caption).foregroundStyle(.tertiary)
                    }.padding(.vertical, 9).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
    }
}

struct IPAHistoryList: View {
    var downloaded = false
    @ObservedObject private var history = IPAActivityHistory.shared
    @State private var query = ""
    @State private var order = "recent"
    @State private var searching = false
    private var records: [IPAActivityRecord] {
        let all = (downloaded ? history.downloads : history.recent).filter {
            query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || ($0.libraryName ?? "").localizedCaseInsensitiveContains(query)
        }
        return order == "name" ? all.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } : order == "oldest" ? all.sorted { $0.date < $1.date } : all
    }
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if records.isEmpty { IPAEmptyState(title: query.isEmpty ? (downloaded ? "No Downloads Yet" : "No Recent Apps") : "No Results", subtitle: query.isEmpty ? "Apps you \(downloaded ? "install" : "view") will appear here." : "Try another app or library name.", symbol: downloaded ? "arrow.down.circle" : "clock") }
                ForEach(records) { record in
                    IPAHistoryRow(record: record).contextMenu {
                        Button("Remove from History", systemImage: "minus.circle", role: .destructive) { history.remove(record, downloaded: downloaded) }
                    }
                    Divider().padding(.leading, 72)
                }
            }.padding(.horizontal, 20).padding(.bottom, 24).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background(IPAStyle.canvas).navigationTitle(downloaded ? "Downloaded Apps" : "Recent Apps").navigationBarTitleDisplayMode(.inline).ipaNativePage()
            .modifier(IPACollectionSearch(query: $query, presented: $searching))
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Menu { Button("Search", systemImage: "magnifyingglass") { searching = true }; Divider(); Picker("Sort", selection: $order) { Text("Most Recent").tag("recent"); Text("Oldest First").tag("oldest"); Text("Name").tag("name") } } label: { Image(systemName: "arrow.up.arrow.down") }.accessibilityLabel("Sort history")
            } }
    }
}

private struct IPAHistoryDetail: View {
    let record: IPAActivityRecord
    @EnvironmentObject private var model: SharedModel
    @ObservedObject private var installer = IPAInstallCoordinator.shared
    private var installed: Bool { model.apps.contains { $0.appInfo.bundleIdentifier() == record.identifier } || installer.independentApps.contains { $0.identifier == record.identifier } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 18) {
                    IPAArtwork(url: record.iconURL, size: 100, identifier: record.identifier)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(record.name).ipaFont(.title2, weight: .bold)
                        if installed { Button("Open") {
                            #if !IPASTORE_PREVIEW
                            Task { await installer.open(record.identifier) }
                            #endif
                        }.buttonStyle(IPAPillStyle(prominent: true)) }
                    }
                }
                if let version = record.version { LabeledContent("Recorded Version", value: version) }
                Text("This app’s current library listing is unavailable. Refresh its library to see current download options.").foregroundStyle(.secondary)
                if let url = record.libraryURL { NavigationLink { IPAStorePage(reference: .init(url: url, name: record.libraryName ?? "App Library", summary: "An independent app library.", publisher: nil)) } label: { Label("Open Library", systemImage: IPAStyle.storeSymbol) } }
            }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background(IPAStyle.canvas).navigationBarTitleDisplayMode(.inline).ipaNativePage()
    }
}

struct IPARecentShelf: View {
    @ObservedObject private var history = IPAActivityHistory.shared
    @ScaledMetric(relativeTo: .body) private var rowHeight = 88.0
    private var pages: [[IPAActivityRecord]] {
        IPACatalogPresentation.shelfPages(history.recent)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink { IPAHistoryList() } label: {
                HStack(spacing: 6) { Text("Recent").ipaFont(.title2, weight: .bold); Image(systemName: "chevron.right").ipaFont(.subheadline, weight: .semibold).foregroundStyle(.tertiary) }.foregroundStyle(.primary)
            }.buttonStyle(.plain)
            GeometryReader { geometry in
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 20) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { _, page in
                            VStack(spacing: 0) {
                                ForEach(page) { record in
                                    IPAHistoryRow(record: record).frame(minHeight: rowHeight)
                                    if record.id != page.last?.id { Divider().padding(.leading, 72) }
                                }
                                Spacer(minLength: 0)
                            }.frame(width: max(220, geometry.size.width - 34), alignment: .topLeading)
                        }
                    }.scrollTargetLayout()
                }.scrollIndicators(.hidden).scrollTargetBehavior(.viewAligned).scrollClipDisabled()
            }.frame(height: rowHeight * CGFloat(min(3, history.recent.count)) + 4)
        }
    }
}

// A stable, shared search field. The collection stays mounted while the Sort
// menu reveals it, preserving scroll position and avoiding navigation rebuilds.
struct IPACollectionSearch: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var query: String
    @Binding var presented: Bool
    var prompt = "Search Apps"
    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .top, spacing: 0) {
            if presented { IPACollectionSearchField(query: $query, presented: $presented, prompt: prompt).transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)) }
        }.animation(reduceMotion ? nil : IPAMotion.state(reduced: false), value: presented).scrollDismissesKeyboard(.interactively)
    }
}
private struct IPACollectionSearchField: View {
    @Binding var query: String
    @Binding var presented: Bool
    let prompt: String
    @FocusState private var focused: Bool
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(prompt, text: $query).textInputAutocapitalization(.never).autocorrectionDisabled().focused($focused).submitLabel(.search)
                if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.accessibilityLabel("Clear search") }
            }.padding(10).background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
            Button("Cancel") { focused = false; query = ""; presented = false }
        }.padding(.horizontal, 20).padding(.vertical, 8).frame(maxWidth: 760).frame(maxWidth: .infinity)
            .background(.bar).task { focused = true }
    }
}

struct IPAArrangeLibraries: View {
    let items: [AltStoreSourcesViewModel.SourceItem]
    @Binding var storedOrder: String
    @Environment(\.dismiss) private var dismiss
    @State private var ordered: [AltStoreSourcesViewModel.SourceItem] = []
    var body: some View {
        NavigationStack {
            List {
                ForEach(ordered) { item in
                    HStack(spacing: 12) { IPAStoreArtwork(source: item.source, reference: IPAStoreReference(item), size: 40); Text(IPAStoreDirectory.title(for: item)).lineLimit(1) }
                }.onMove { from, to in
                    ordered.move(fromOffsets: from, toOffset: to)
                    if let data = try? JSONEncoder().encode(ordered.map { IPAStoreDirectory.canonical($0.url) }), let text = String(data: data, encoding: .utf8) { storedOrder = text }
                }
            }.environment(\.editMode, .constant(.active))
                .navigationTitle("Arrange Libraries").navigationBarTitleDisplayMode(.inline).ipaNativePage()
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .onAppear { ordered = items }
        }.modifier(IPATheme())
    }
}
