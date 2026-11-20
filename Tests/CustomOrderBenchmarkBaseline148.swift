// Frozen build 148 custom ordering path for paired regression/performance checks.
import Foundation
func baselineCustomOrder(_ appList: [LCAppModel], customSortOrder: [String], manager: LCAppSortManager) -> [LCAppModel] {
        var sortedApps: [LCAppModel] = []
        var remainingApps = appList
        
        for uniqueId in customSortOrder {
            if let index = remainingApps.firstIndex(where: { manager.matches(uniqueId: uniqueId, app: $0) }) {
                sortedApps.append(remainingApps.remove(at: index))
            }
        }
        
        remainingApps.sort { $0.appInfo.displayName().localizedStandardCompare($1.appInfo.displayName()) == .orderedAscending }
        sortedApps.append(contentsOf: remainingApps)
        
    return sortedApps
}
