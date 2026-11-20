from pathlib import Path
import subprocess
root=Path(__file__).resolve().parents[1]
work=root/'.build/InstallServerChecks';work.mkdir(parents=True,exist_ok=True)
(work/'Runner.swift').write_text('''import Foundation
@main struct Runner {
 static func main() async throws {
  let identifier="org.example.romantic"
  let launch=IPACertificatePolicy.launchURL(identifier:identifier)
  precondition(IPACertificatePolicy.acceptsLaunchURL(launch, identifier:identifier, resignedIdentifier:identifier))
  precondition(!IPACertificatePolicy.acceptsLaunchURL(URL(string:"ipastore://launch")!, identifier:identifier, resignedIdentifier:identifier))
  let payload=URL(string:"http://127.0.0.1:4321/token.ipa")!
  let name="App & Music + é / ?"
  let install=IPACertificatePolicy.installURL(payload:payload,identifier:identifier,name:name,version:"42")!
  let manifest=URLComponents(url:install,resolvingAgainstBaseURL:false)!.queryItems!.first{$0.name=="url"}!.value!
  let items=URLComponents(string:manifest)!.queryItems!
  precondition(items.first{$0.name=="name"}?.value==name)
  precondition(items.first{$0.name=="fetchurl"}?.value==payload.absoluteString)
  let file=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let bytes=Data(repeating:42,count:12*1024*1024)
  try bytes.write(to:file); defer {try? FileManager.default.removeItem(at:file)}
  let server=IPALocalInstallServer(package:file);defer{server.stop()}
  let url=try await server.start()
  precondition(url.host=="127.0.0.1" && url.pathExtension=="ipa")
  let (result,response)=try await URLSession.shared.data(from:url)
  precondition((response as! HTTPURLResponse).statusCode==200 && result==bytes)
  var head=URLRequest(url:url);head.httpMethod="HEAD"
  let (empty,hr)=try await URLSession.shared.data(for:head)
  precondition(empty.isEmpty && (hr as! HTTPURLResponse).value(forHTTPHeaderField:"Content-Length")==String(bytes.count))
  let secret=url.deletingLastPathComponent().appendingPathComponent("private.p12")
  do { _ = try await URLSession.shared.data(from:secret); preconditionFailure("Unexpected private route") } catch {}
  print("Install server checks PASS: Unicode/URL encoding, stable independent launch scheme, 12 MiB streamed payload, HEAD length, loopback binding, inaccessible private routes.")
 }
}
''')
subprocess.run(['swiftc',str(root/'LiveContainerSwiftUI/Models/IPACertificateInstaller.swift'),str(work/'Runner.swift'),'-parse-as-library','-swift-version','5','-o',str(work/'checks')],check=True)
result=subprocess.run([str(work/'checks')],check=True,capture_output=True,text=True)
(root/'Validation/install-server-checks.txt').write_text(result.stdout);print(result.stdout)
