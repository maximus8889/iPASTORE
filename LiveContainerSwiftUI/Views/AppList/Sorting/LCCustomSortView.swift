//
//  LCCustomSortView.swift
//  LiveContainerSwiftUI
//
//  Created by boa-z on 2025/6/21.
//
import SwiftUI

struct LCCustomSortView: View {
    @EnvironmentObject private var sharedModel: SharedModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("darkModeIcon", store: LCUtils.appGroupUserDefault) private var darkModeIcon = false

    @State private var localApps: [LCAppModel] = []
    @State private var localHiddenApps: [LCAppModel] = []

    var body: some View {
        NavigationStack {
            List {
                appRows($localApps)
                if sharedModel.isHiddenAppUnlocked && !localHiddenApps.isEmpty {
                    Section("lc.appList.hiddenApps".loc) { appRows($localHiddenApps) }
                }
            }
            .listStyle(.plain).scrollContentBackground(.hidden).background(IPAStyle.canvas)
            .navigationTitle("Arrange Apps").navigationBarTitleDisplayMode(.inline).ipaNativePage()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: saveChanges)
                }
            }
            .environment(\.editMode, .constant(.active))
        }
        .ipaTallSheet()
        .onAppear(perform: initializeLocalState)
    }

    private func appRows(_ apps: Binding<[LCAppModel]>) -> some View {
        ForEach(apps.wrappedValue, id: \.self) { app in
            HStack {
                IconImageView(icon: app.appInfo.iconIsDarkIcon(darkModeIcon))
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.appInfo.displayName())
                        .ipaFont(.headline, weight: .semibold).lineLimit(1)
                    Text("Version \(app.appInfo.version() ?? "?")")
                        .ipaFont(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Text(app.uiSelectedContainer?.name ?? "lc.appBanner.noDataFolder".loc)
                        .ipaFont(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .onMove { source, destination in
            apps.wrappedValue.move(fromOffsets: source, toOffset: destination)
        }
    }

    private func initializeLocalState() {
        let manager = LCAppSortManager.shared
        localApps = manager.getSortedApps(sharedModel.apps, sortType: .custom, customSortOrder: manager.customSortOrder)
        localHiddenApps = manager.getSortedApps(sharedModel.hiddenApps, sortType: .custom, customSortOrder: manager.customSortOrder)
    }

    private func saveChanges() {
        let manager = LCAppSortManager.shared
        manager.customSortOrder = (localApps + localHiddenApps).compactMap { manager.getUniqueIdentifier(for: $0) }
        manager.appSortType = .custom
        dismiss()
    }
}
