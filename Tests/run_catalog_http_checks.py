"""Use the production catalog loader against a changing local HTTP publisher."""
from pathlib import Path
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
import json, subprocess, threading, time
root=Path(__file__).resolve().parents[1]
scratch=root/'.build/CatalogHTTPChecks';scratch.mkdir(parents=True,exist_ok=True)
state={'generation':1,'counts':{},'headers':[]};lock=threading.Lock()
class Handler(BaseHTTPRequestHandler):
    def log_message(self,*args):pass
    def do_GET(self):
        path=self.path
        with lock:
            count=state['counts'][path]=state['counts'].get(path,0)+1
            generation=state['generation']
            if path!='/advance':state['headers'].append((self.headers.get('Cache-Control'),self.headers.get('Accept')))
        if path=='/advance':
            with lock:state['generation']=2
            self.send_response(200);self.end_headers();self.wfile.write(b'ok');return
        if path=='/missing':self.send_error(404);return
        if path=='/html':
            self.send_response(200);self.end_headers();self.wfile.write(b'<!DOCTYPE html><html>Publisher homepage</html>');return
        if path=='/flaky' and count==1:self.send_error(503);return
        if path=='/redirect':
            self.send_response(302);self.send_header('Location','/nested/feed.json');self.end_headers();return
        if path=='/single':time.sleep(.3)
        extra='org.example.removed' if generation==1 else 'org.example.new'
        payload=json.dumps({'name':'Local Publisher','apps':[
            {'name':'Updated','bundleIdentifier':'org.example.updated','version':str(generation),'downloadURL':'downloads/current.ipa'},
            {'name':'Extra','bundleIdentifier':extra,'version':'1','downloadURL':'downloads/extra.ipa'}
        ]},sort_keys=True).encode()
        self.send_response(200);self.send_header('Content-Type','application/json')
        self.send_header('Cache-Control','public, max-age=86400');self.send_header('Content-Length',str(len(payload)));self.end_headers()
        self.wfile.write(payload)
server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
source=(root/'LiveContainerSwiftUI/Views/LCAltStoreSourcesView.swift').read_text().split('struct LCSourcesView: View')[0].replace('import UIKit\n','')+'\nextension String { var loc: String { self } }\n'
(scratch/'Catalog.swift').write_text(source)
(scratch/'Discovery.swift').write_text((root/'LiveContainerSwiftUI/Views/IPAStoreDirectory.swift').read_text().split('extension AltStoreSourcesViewModel')[0])
(scratch/'Runner.swift').write_text('''import Foundation
@main struct Runner {
 static func main() async throws {
    let base=URL(string:CommandLine.arguments[1])!
    let feed=base.appendingPathComponent("feed.json")
    let first=try await AltStoreSourceLoader.load(from:feed)
    precondition(first.0.apps.first?.latestVersion?.version == "1")
    _=try await URLSession.shared.data(from:base.appendingPathComponent("advance"))
    let second=try await AltStoreSourceLoader.load(from:feed)
    precondition(second.0.apps.first?.latestVersion?.version == "2" && second.0.apps.contains { $0.bundleIdentifier == "org.example.new" })
    precondition(!second.0.apps.contains { $0.bundleIdentifier == "org.example.removed" } && first.0.id != second.0.id)
    let recovered=try await AltStoreSourceLoader.load(from:base.appendingPathComponent("flaky"))
    precondition(recovered.0.apps.count == 2)
    do { _=try await AltStoreSourceLoader.load(from:base.appendingPathComponent("missing")); fatalError("A removed source was reported as current") }
    catch { precondition((error as NSError).code == 404 && AltStoreSourceLoader.refreshMessage(error).contains("no longer serves")) }
    do { _=try await AltStoreSourceLoader.load(from:base.appendingPathComponent("html")); fatalError("A publisher homepage was accepted as an app catalog") }
    catch { precondition((error as NSError).domain == "iPAStore.LibraryFormat" && AltStoreSourceLoader.refreshMessage(error).contains("webpage")) }
    let redirected=try await AltStoreSourceLoader.load(from:base.appendingPathComponent("redirect"))
    precondition(redirected.0.apps.first?.latestVersion?.downloadURL.path == "/nested/downloads/current.ipa", "Relative IPA URLs must resolve against the final redirected source location")
    async let one=IPACatalogDownloads.shared.load(from:base.appendingPathComponent("single"))
    async let two=IPACatalogDownloads.shared.load(from:base.appendingPathComponent("single"))
    let pair=try await(one,two)
    precondition(pair.0.0.id == pair.1.0.id)
    print("PASS: live changed catalog, cache bypass, new/removed apps, 503 retry, permanent404, redirected download URLs and shared in-flight requests")
 }
}
''')
# Reuse the actual model compiler inputs, without running the general suite twice.
namespace={'__file__':str(root/'Tests/run_release_checks.py')}
prefix=(root/'Tests/run_release_checks.py').read_text().split('subprocess.run(command, check=True)')[0]
prefix=prefix.replace("scratch = root / '.build' / 'ReleaseChecks'","scratch = root / '.build' / 'CatalogHTTPCompile'")
exec(prefix,namespace)
command=namespace['command']
# Keep this test's runner and generated model snapshot isolated.
command=[str(scratch/Path(x).name) if Path(x).name in ['Catalog.swift','Discovery.swift','Runner.swift'] else x for x in command]
command[-1]=str(scratch/'checks')
try:
    subprocess.run(command,check=True)
    result=subprocess.run([str(scratch/'checks'),f'http://127.0.0.1:{server.server_port}'],check=True,capture_output=True,text=True)
    assert state['counts'].get('/feed.json')==2,state
    assert state['counts'].get('/missing')==1,state
    assert state['counts'].get('/flaky')==2,state
    assert state['counts'].get('/single')==1,state
    assert all(cache=='no-cache' and accept=='application/json' for cache,accept in state['headers']),state
    report=result.stdout+'Publisher requests: '+json.dumps(state['counts'],sort_keys=True)+'\n'
    (root/'Validation/catalog-http-checks.txt').write_text(report);print(report)
finally:server.shutdown();server.server_close()
