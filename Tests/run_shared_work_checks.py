"""Exercise the production work subscription actor under cancellation/replacement races."""
from pathlib import Path
import subprocess
root=Path(__file__).resolve().parents[1];scratch=root/'.build/SharedWorkChecks';scratch.mkdir(parents=True,exist_ok=True)
source=(root/'LiveContainerSwiftUI/Views/IPAImagePipeline.swift').read_text().split('// A cancelled row waiting')[0]
for module in ['SwiftUI','UIKit','ImageIO','CryptoKit']:source=source.replace('import '+module+'\n','')
(scratch/'Work.swift').write_text(source)
(scratch/'Runner.swift').write_text(r'''import Foundation
actor Probe { var starts=0; func start(){starts+=1} }
@main struct Runner {
 static func main() async throws {
  let pool=IPASharedWork<String,Int>(),probe=Probe()
  let first=Task { await pool.value(for:"shared") { await probe.start();try? await Task.sleep(for:.milliseconds(180));return 7 } }
  for _ in 0..<200 where await pool.consumerCount(for:"shared") != 1 { try await Task.sleep(for:.milliseconds(1)) }
  let second=Task { await pool.value(for:"shared") { await probe.start();return 999 } }
  for _ in 0..<200 where await pool.consumerCount(for:"shared") != 2 { try await Task.sleep(for:.milliseconds(1)) }
  let consumers=await pool.consumerCount(for:"shared");precondition(consumers==2)
  let began=ContinuousClock.now;first.cancel();let cancelled=await first.value
  precondition(cancelled==nil && began.duration(to:.now) < .milliseconds(120),"A cancelled caller waited for shared work")
  let surviving=await second.value;let starts=await probe.starts
  precondition(surviving==7 && starts==1,"One cancellation damaged the remaining subscriber")
  let old=Task { await pool.value(for:"replace") { try? await Task.sleep(for:.seconds(5));return 1 } }
  for _ in 0..<200 where await pool.consumerCount(for:"replace") != 1 { try await Task.sleep(for:.milliseconds(1)) }
  old.cancel();let oldValue=await old.value;precondition(oldValue==nil)
  let replacement=await pool.value(for:"replace") { try? await Task.sleep(for:.milliseconds(20));return 2 }
  precondition(replacement==2,"A late cancelled completion replaced new work")
  for round in 0..<50 {
   let callers=(0..<8).map { _ in Task { await pool.value(for:"race\(round)") { try? await Task.sleep(for:.seconds(30));return round } } }
   for _ in 0..<200 where await pool.consumerCount(for:"race\(round)") != 8 { try await Task.sleep(for:.milliseconds(1)) }
   for caller in callers { caller.cancel() }
   for caller in callers { let result=await caller.value;precondition(result==nil) }
  }
  let clear=Task { await pool.value(for:"clear") { try? await Task.sleep(for:.seconds(5));return 5 } }
  for _ in 0..<200 where await pool.consumerCount(for:"clear") != 1 { try await Task.sleep(for:.milliseconds(1)) }
  await pool.cancelAll();let cleared=await clear.value;precondition(cleared==nil)
  let pending=await pool.pendingCount;precondition(pending==0)
  print("PASS: one shared operation, immediate individual cancellation, surviving subscribers, last-consumer cancellation, stale completion isolation, 400 raced cancellations and global clear")
 }
}
''')
subprocess.run(['swiftc',str(scratch/'Work.swift'),str(scratch/'Runner.swift'),'-O','-parse-as-library','-swift-version','5','-module-cache-path',str(root/'.build/ReleaseChecks/ModuleCache'),'-o',str(scratch/'checks')],check=True)
r=subprocess.run([str(scratch/'checks')],capture_output=True,text=True,timeout=30);print(r.stdout);print(r.stderr if r.returncode else '',end='');r.check_returncode();(root/'Validation/shared-work-checks.txt').write_text(r.stdout)
