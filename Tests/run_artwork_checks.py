"""Run the production artwork download actor against a bounded local publisher."""
from pathlib import Path
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
import subprocess, threading, time, json
root=Path(__file__).resolve().parents[1]
scratch=root/'.build/ArtworkChecks';scratch.mkdir(parents=True,exist_ok=True)
state={'counts':{},'active':0,'peak':0,'ports':set()};lock=threading.Lock()
payload=b'bounded artwork bytes'*4096
class Handler(BaseHTTPRequestHandler):
    protocol_version='HTTP/1.1'
    def log_message(self,*args):pass
    def do_GET(self):
        with lock:
            state['counts'][self.path]=state['counts'].get(self.path,0)+1
            state['active']+=1;state['peak']=max(state['peak'],state['active']);state['ports'].add(self.client_address[1])
        try:
            time.sleep(.05)
            if self.path=='/missing':code,body=404,b'missing'
            elif self.path=='/large':code,body=200,b'x'*(12*1024*1024+1)
            else:code,body=200,payload
            self.send_response(code);self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
        except (BrokenPipeError,ConnectionResetError):pass
        finally:
            with lock:state['active']-=1
server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
source=(root/'LiveContainerSwiftUI/Views/IPAImagePipeline.swift').read_text().split('private enum IPAImageMemory')[0]
for module in ['SwiftUI','UIKit','ImageIO','CryptoKit']:source=source.replace('import '+module+'\n','')
(scratch/'Artwork.swift').write_text('import Foundation\n'+source)
(scratch/'Runner.swift').write_text('''import Foundation
@main struct Runner {
 static func main() async {
  let base=URL(string:CommandLine.arguments[1])!, downloads=IPAArtworkDownloads()
  let icon=base.appendingPathComponent("icon")
  async let small=downloads.data(from:icon)
  async let large=downloads.data(from:icon)
  let pair=await(small,large)
  precondition(pair.0 != nil && pair.0 == pair.1)
  let cached=await downloads.data(from:icon)
  precondition(cached == pair.0)
  await downloads.clearMemory()
  let reloaded=await downloads.data(from:icon)
  precondition(reloaded == pair.0)
  let missing=await downloads.data(from:base.appendingPathComponent("missing"))
  precondition(missing == nil)
  let oversized=await downloads.data(from:base.appendingPathComponent("large"))
  precondition(oversized == nil)
  let unsupported=await downloads.data(from:URL(string:"file:///private/not-artwork")!)
  precondition(unsupported == nil)
  await withTaskGroup(of:Data?.self) { group in
   for number in 0..<18 { group.addTask { await downloads.data(from:base.appendingPathComponent("batch/\\(number)")) } }
   for await result in group { precondition(result == pair.0) }
  }
  print("PASS: original-byte sharing across sizes, memory reuse/clear, byte integrity, HTTP failure,12MB limit and bounded concurrent requests")
 }
}
''')
try:
    subprocess.run(['swiftc',str(scratch/'Artwork.swift'),str(scratch/'Runner.swift'),'-parse-as-library','-swift-version','5','-module-cache-path',str(root/'.build/ReleaseChecks/ModuleCache'),'-o',str(scratch/'checks')],check=True)
    result=subprocess.run([str(scratch/'checks'),f'http://127.0.0.1:{server.server_port}'],check=True,capture_output=True,text=True)
    assert state['counts'].get('/icon')==2,state
    assert state['counts'].get('/missing')==1 and state['counts'].get('/large')==1,state
    assert state['peak']<=6,state
    report=result.stdout+json.dumps({'requests':sum(state['counts'].values()),'peak':state['peak'],'connections':len(state['ports'])})+'\n'
    (root/'Validation/artwork-download-checks.txt').write_text(report);print(report)
finally:server.shutdown();server.server_close()
