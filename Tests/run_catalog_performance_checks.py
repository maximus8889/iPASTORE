"""Paired optimized-code benchmark and bounded revision-cache stress checks."""
from pathlib import Path
import subprocess, shutil
root=Path(__file__).resolve().parents[1];scratch=root/'.build/CatalogPerformanceChecks';scratch.mkdir(parents=True,exist_ok=True)
shutil.copy2(root/'Resources/AppCategories.json',scratch/'AppCategories.json')
source=(root/'LiveContainerSwiftUI/Views/LCAltStoreSourcesView.swift').read_text().split('struct LCSourcesView: View')[0].replace('import UIKit\n','')+'\nextension String { var loc: String { self } }\n'
(scratch/'Catalog.swift').write_text(source)
(scratch/'Discovery.swift').write_text((root/'LiveContainerSwiftUI/Views/IPAStoreDirectory.swift').read_text().split('extension AltStoreSourcesViewModel')[0])
(scratch/'Runner.swift').write_text(r'''import Foundation
@main struct Runner {
 @MainActor static func main() async throws {
  func fixture(_ count: Int, revision: Int = 0) -> AltStoreSource {
   let apps=(0..<count).map { number in
    AltStoreSourceApp(name: "App \((number * 7919) % count)", bundleIdentifier: "app.benchmark.\(number)", developerName: "Publisher \(number % 20)", subtitle: "A useful app \(revision)", description: nil, iconURL: nil, tintColor: nil, screenshots: [], versions: [], latestVersion: nil, isBeta: number % 11 == 0, category: number % 2 == 0 ? "Games" : "Utilities")
   }
   return AltStoreSource(name: "Benchmark", identifier: nil, subtitle: nil, description: nil, iconURL: nil, headerURL: nil, tintColor: nil, website: nil, apps: apps)
  }
  func elapsed(_ body: () -> [IPAAppEntry]) -> Double {
   let start=ContinuousClock.now; let result=body(); precondition(!result.isEmpty)
   let d=start.duration(to:.now); return Double(d.components.seconds)*1000+Double(d.components.attoseconds)/1e15
  }
  let reference=IPAStoreReference(url:URL(string:"https://benchmark.invalid/source.json")!,name:"Benchmark",summary:"",publisher:nil)
  for count in [1000,10000,30000] {
   let source=fixture(count), libraries=[(reference,source.apps)]
   let expected=CatalogBenchmarkBaseline148.entries(libraries), actual=IPACatalogPresentation.entries(libraries)
   precondition(actual.map(\.id)==expected.map(\.id),"Natural ordering changed")
   for (a,b) in zip(actual,expected) { precondition(a.variants.map(\.id)==b.variants.map(\.id)) }
   var before:[Double]=[],after:[Double]=[]
   for run in 0..<5 {
    if run % 2 == 0 { before.append(elapsed { CatalogBenchmarkBaseline148.entries(libraries) });after.append(elapsed { IPACatalogPresentation.entries(libraries) }) }
    else { after.append(elapsed { IPACatalogPresentation.entries(libraries) });before.append(elapsed { CatalogBenchmarkBaseline148.entries(libraries) }) }
   }
   print("catalog_rows=\(count) baseline148_median_ms=\(before.sorted()[2]) current_median_ms=\(after.sorted()[2])")
  }
  let originals=fixture(80).apps
  let previews=originals.map { app in
   AltStoreSourceApp(name: app.name+" Preview",bundleIdentifier:app.bundleIdentifier+".beta",developerName:nil,subtitle:nil,description:nil,iconURL:nil,tintColor:nil,screenshots:[],versions:[],latestVersion:nil,isBeta:true)
  }
  let second=IPAStoreReference(url:URL(string:"https://benchmark.invalid/second.json")!,name:"Second",summary:"",publisher:nil)
  let mixed=[(reference,previews),(second,originals),(second,originals)]
  let oldMixed=CatalogBenchmarkBaseline148.entries(mixed),newMixed=IPACatalogPresentation.entries(mixed)
  precondition(oldMixed.map(\.id)==newMixed.map(\.id))
  for (a,b) in zip(oldMixed,newMixed) { precondition(a.variants.map(\.id)==b.variants.map(\.id),"Standard/preview source priority changed") }
  let index=IPALibraryIndex()
  for revision in 0..<60 {
   let source=fixture(700,revision:revision);await index.prepare(reference:reference,source:source)
   precondition(index.entries(reference:reference,source:source).first?.app.subtitle=="A useful app \(revision)")
   precondition(index.cachedLibraryCount==1 && index.cachedEntryCount==700,"Obsolete full revisions were retained")
  }
  for n in 0..<25 {
   let ref=IPAStoreReference(url:URL(string:"https://benchmark.invalid/\(n).json")!,name:"Benchmark",summary:"",publisher:nil)
   await index.prepare(reference:ref,source:fixture(100))
   precondition(index.cachedLibraryCount<=16 && index.cachedEntryCount<=30000)
  }
  index.trimMemory();precondition(index.cachedLibraryCount==0 && index.cachedEntryCount==0)
  let latest=fixture(50,revision:99);await index.prepare(reference:reference,source:latest)
  precondition(index.entries(reference:reference,source:latest).count==50)
  print("PASS: natural ordering, stable variant priority, 60 revisions retain one snapshot, 16-library budget, memory-pressure trim and recovery")
 }
}
''')
files=[scratch/'Catalog.swift',scratch/'Discovery.swift',root/'LiveContainerSwiftUI/Models/IPADownloadTransfer.swift',root/'LiveContainerSwiftUI/Models/IPAAppCategoryIndex.swift',root/'LiveContainerSwiftUI/Views/IPAStoreRegistry.swift',root/'LiveContainerSwiftUI/Views/IPACatalogPresentation.swift',root/'Tests/CatalogBenchmarkBaseline148.swift',scratch/'Runner.swift']
subprocess.run(['swiftc',*map(str,files),'-O','-parse-as-library','-swift-version','5','-module-cache-path',str(root/'.build/ReleaseChecks/ModuleCache'),'-o',str(scratch/'checks')],check=True)
r=subprocess.run([str(scratch/'checks')],capture_output=True,text=True);print(r.stdout);print(r.stderr if r.returncode else '',end='');r.check_returncode();(root/'Validation/catalog-performance-checks.txt').write_text(r.stdout)
