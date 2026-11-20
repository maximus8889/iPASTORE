"""Compile the production sorting methods with instrumented app-info boundaries."""
from pathlib import Path
import subprocess
root=Path(__file__).resolve().parents[1];scratch=root/'.build/CustomOrderChecks';scratch.mkdir(parents=True,exist_ok=True)
source=(root/'LiveContainerSwiftUI/Views/AppList/Sorting/LCAppSortManager.swift').read_text();source=source[source.index('    func getUniqueIdentifier'):]
stubs='''import Foundation
enum AppSortType { case defaultOrder, alphabetical, reverseAlphabetical, lastLaunched, installationDate, custom }
final class AppInfo {
 static var identifierReads=0
 let number:Int
 init(_ number:Int){self.number=number}
 func bundleIdentifier()->String? { Self.identifierReads+=1;return number<0 ? nil : "app.\\(number)" }
 var relativeBundlePath:String? { number<0 ? nil : "App\\(number).app" }
 func displayName()->String { "App \\(number)" }
 var lastLaunched:Date? { nil };var installationDate:Date? { nil }
}
final class LCAppModel { let appInfo:AppInfo;init(_ n:Int){appInfo=AppInfo(n)} }
class LCAppSortManager {
'''
(scratch/'Ordering.swift').write_text(stubs+source)
(scratch/'Runner.swift').write_text(r'''import Foundation
@main struct Runner {
 static func main() {
  let manager=LCAppSortManager(),apps=(0..<240).map(LCAppModel.init)+[LCAppModel(-1),LCAppModel(6)]
  for round in 0..<60 {
   let order=(0..<180).map { "app.\(($0*73+round)%270):App\(($0*73+round)%270).app" }+["missing","app.6:App6.app","app.6:App6.app"]
   let expected=baselineCustomOrder(apps,customSortOrder:order,manager:manager)
   let actual=manager.getSortedApps(apps,sortType:.custom,customSortOrder:order)
   precondition(actual.map(ObjectIdentifier.init)==expected.map(ObjectIdentifier.init),"Custom order or duplicate/missing-ID behavior changed")
  }
  let large=(0..<3000).map(LCAppModel.init),order=(0..<3000).reversed().map { "app.\($0):App\($0).app" }
  AppInfo.identifierReads=0;let before=ContinuousClock.now
  _=baselineCustomOrder(large,customSortOrder:order,manager:manager)
  let baselineMs=before.duration(to:.now),baselineReads=AppInfo.identifierReads
  AppInfo.identifierReads=0;let after=ContinuousClock.now
  _=manager.getSortedApps(large,sortType:.custom,customSortOrder:order)
  let currentMs=after.duration(to:.now),currentReads=AppInfo.identifierReads
  precondition(currentReads==3000 && baselineReads>4000000)
  print("PASS: production custom ordering, duplicate order entries, duplicate identities, missing IDs and 60 mixed-order fixtures")
  print("custom_order_apps=3000 baseline148_identifier_reads=\(baselineReads) current_identifier_reads=\(currentReads) baseline148_duration=\(baselineMs) current_duration=\(currentMs)")
 }
}
''')
subprocess.run(['swiftc',str(scratch/'Ordering.swift'),str(root/'Tests/CustomOrderBenchmarkBaseline148.swift'),str(scratch/'Runner.swift'),'-O','-parse-as-library','-module-cache-path',str(root/'.build/ReleaseChecks/ModuleCache'),'-o',str(scratch/'checks')],check=True)
r=subprocess.run([str(scratch/'checks')],capture_output=True,text=True,timeout=60);print(r.stdout);print(r.stderr if r.returncode else '',end='');r.check_returncode();(root/'Validation/custom-order-checks.txt').write_text(r.stdout)
