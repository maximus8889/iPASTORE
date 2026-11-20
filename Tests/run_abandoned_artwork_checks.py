"""Compare actual old/new artwork code when queued row requests are abandoned."""
from pathlib import Path
import subprocess,re
root=Path(__file__).resolve().parents[1];scratch=root/'.build/AbandonedArtworkChecks';scratch.mkdir(parents=True,exist_ok=True)
current=(root/'LiveContainerSwiftUI/Views/IPAImagePipeline.swift').read_text().split('struct IPARemoteImage: View')[0]
legacy=(root/'Tests/ArtworkBenchmarkBaseline148.swift').read_text()
for name,source in [('Current',current),('Legacy',legacy)]:
 source=source.replace('import SwiftUI\n','').replace('import UIKit\n','import Foundation\nimport AppKit\n')
 if name=='Legacy':
  for symbol in ['IPAImageDownloadLimit','IPAArtworkDownloads','IPAImageMemory','IPAArtworkDecoder','IPAArtworkDiskWriter','IPAImagePipeline']:
   source=re.sub(r'\b'+symbol+r'\b','Legacy'+symbol,source)
 source=source.replace('CGImageSourceCreateThumbnailAtIndex(',name.lower()+'Thumbnail(')
 decoder=('Legacy' if name=='Legacy' else '')+'IPAArtworkDecoder'
 source+='\nenum '+name+'QueueCheck {\n static func suspend(_ value:Bool) { '+decoder+'.queue.isSuspended=value }\n static var count:Int { '+decoder+'.queue.operationCount }\n static var allCancelled:Bool { '+decoder+'.queue.operations.allSatisfy { $0.isCancelled } }\n}\n'
 (scratch/(name+'.swift')).write_text(source)
(scratch/'Support.swift').write_text('''import Foundation
import AppKit
import ImageIO
import CoreGraphics
typealias UIImage=NSImage
extension NSImage {
 var cgImage:CGImage? { cgImage(forProposedRect:nil,context:nil,hints:nil) }
 convenience init(cgImage:CGImage){self.init(cgImage:cgImage,size:CGSize(width:cgImage.width,height:cgImage.height))}
}
final class DecodeCounter: @unchecked Sendable {
 private let lock=NSLock();private var value=0
 func increment(){lock.lock();value+=1;lock.unlock()}
 var count:Int { lock.lock();defer {lock.unlock()};return value }
}
let currentDecodes=DecodeCounter(),legacyDecodes=DecodeCounter()
func currentThumbnail(_ source:CGImageSource,_ index:Int,_ options:CFDictionary)->CGImage? { currentDecodes.increment();return CGImageSourceCreateThumbnailAtIndex(source,index,options) }
func legacyThumbnail(_ source:CGImageSource,_ index:Int,_ options:CFDictionary)->CGImage? { legacyDecodes.increment();return CGImageSourceCreateThumbnailAtIndex(source,index,options) }
''')
(scratch/'Runner.swift').write_text(r'''import Foundation
import CryptoKit
@main struct Runner {
 static func main() async throws {
  let image=try Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1]))
  let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
  defer { try? FileManager.default.removeItem(at:directory) }
  func urls(_ group:String) throws -> [URL] {
   let urls=(0..<16).map { URL(string:"https://backlog.invalid/\(UUID().uuidString)/\(group)/\($0).png")! }
   for url in urls { let name=SHA256.hash(data:Data(url.absoluteString.utf8)).map {String(format:"%02x",$0)}.joined()+".artwork";try image.write(to:directory.appendingPathComponent(name)) }
   return urls
  }
  let oldURLs=try urls("old"),newURLs=try urls("new")
  LegacyQueueCheck.suspend(true)
  let old=LegacyIPAImagePipeline(cacheDirectory:directory)
  let oldTasks=(0..<128).map { number in Task { await old.image(oldURLs[number%16],pixels:[96,192,384,768][number/16%4]) } }
  for _ in 0..<3000 where LegacyQueueCheck.count<64 { try await Task.sleep(for:.milliseconds(1)) }
  precondition(LegacyQueueCheck.count==64,"Baseline did not form the intended queued workload")
  for task in oldTasks { task.cancel() }
  LegacyQueueCheck.suspend(false)
  for task in oldTasks { _=await task.value }
  precondition(legacyDecodes.count==64)
  CurrentQueueCheck.suspend(true)
  let current=IPAImagePipeline(cacheDirectory:directory)
  let newTasks=(0..<128).map { number in Task { await current.image(newURLs[number%16],pixels:[96,192,384,768][number/16%4]) } }
  for _ in 0..<3000 where CurrentQueueCheck.count<64 { try await Task.sleep(for:.milliseconds(1)) }
  precondition(CurrentQueueCheck.count==64,"Current code did not form the intended queued workload")
  let began=ContinuousClock.now
  for task in newTasks { task.cancel() }
  for task in newTasks { let result=await task.value;precondition(result==nil) }
  let release=began.duration(to:.now)
  for _ in 0..<500 where !CurrentQueueCheck.allCancelled { try await Task.sleep(for:.milliseconds(1)) }
  precondition(CurrentQueueCheck.allCancelled,"A queued decode retained its abandoned subscribers")
  CurrentQueueCheck.suspend(false)
  for _ in 0..<500 where CurrentQueueCheck.count>0 { try await Task.sleep(for:.milliseconds(1)) }
  precondition(CurrentQueueCheck.count==0 && currentDecodes.count==0)
  print("PASS: cancelled consumers avoid queued ImageIO work; no survivors or stale publications")
  print("abandoned_requests=128 baseline148_decodes=\(legacyDecodes.count) current_decodes=\(currentDecodes.count) current_consumer_release=\(release)")
 }
}
''')
files=[scratch/(n+'.swift') for n in ['Support','Legacy','Current','Runner']]
subprocess.run(['swiftc',*map(str,files),'-O','-parse-as-library','-swift-version','5','-module-cache-path',str(root/'.build/ReleaseChecks/ModuleCache'),'-o',str(scratch/'checks')],check=True)
r=subprocess.run([str(scratch/'checks'),str(root/'Resources/Assets.xcassets/AppIcon.appiconset/IPAStore-Black.png')],capture_output=True,text=True,timeout=45);print(r.stdout);print(r.stderr if r.returncode else '',end='');r.check_returncode();(root/'Validation/abandoned-artwork-checks.txt').write_text(r.stdout)
