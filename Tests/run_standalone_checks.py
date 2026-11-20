"""Exercise the production profile validator, resource signer and streaming ZIP writer.
Synthetic identities here are fixtures, never usable Apple signing credentials.
"""
from pathlib import Path
import subprocess, plistlib, datetime, os, json, zipfile, hashlib, re, struct
root=Path(__file__).resolve().parents[1]
work=root/'.build/StandaloneChecks';work.mkdir(parents=True,exist_ok=True)
def run(args, **kw):return subprocess.run([str(a) for a in args],check=True,capture_output=True,text=True,**kw)
# A synthetic leaf uses the expected issuer NAME to exercise CMS generation;
# its fake CA key is deliberately unrelated to Apple. It cannot authorize iOS apps.
cpp=(root/'ZSign/openssl.cpp').read_text()
section=cpp.split('const char* ZSignAsset::s_szAppleDevCACertG3 =')[1].split(';',1)[0]
pem=''.join(re.findall(r'"(.*?)"',section)).replace('\\n','\n')
(work/'apple-issuer.pem').write_text(pem)
subject=run(['openssl','x509','-in',work/'apple-issuer.pem','-noout','-subject','-nameopt','compat']).stdout.strip().split('=',1)[1].strip()
run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-keyout',work/'fake-ca-key.pem','-out',work/'fake-ca.pem','-days','2','-subj',subject])
run(['openssl','req','-newkey','rsa:2048','-nodes','-keyout',work/'key.pem','-out',work/'leaf.csr','-subj','/CN=iPAStore Test/OU=TESTTEAM01'])
run(['openssl','x509','-req','-in',work/'leaf.csr','-CA',work/'fake-ca.pem','-CAkey',work/'fake-ca-key.pem','-CAcreateserial','-out',work/'cert.pem','-days','2'])
run(['openssl','pkcs12','-export','-out',work/'test.p12','-inkey',work/'key.pem','-in',work/'cert.pem','-passout','pass:fixture'])
run(['openssl','x509','-in',work/'cert.pem','-outform','der','-out',work/'cert.der'])
profile={'Name':'Fixture','UUID':'00000000-0000-0000-0000-000000000001','TeamIdentifier':['TESTTEAM01'],'ApplicationIdentifierPrefix':['TESTTEAM01'],'CreationDate':datetime.datetime.utcnow()-datetime.timedelta(minutes=1),'ExpirationDate':datetime.datetime.utcnow()+datetime.timedelta(days=1),'ProvisionsAllDevices':True,'DeveloperCertificates':[(work/'cert.der').read_bytes()],'Entitlements':{'application-identifier':'TESTTEAM01.*','com.apple.developer.team-identifier':'TESTTEAM01','keychain-access-groups':['TESTTEAM01.*'],'get-task-allow':False}}
for name, overrides in [('valid',{}),('expired',{'ExpirationDate':datetime.datetime.utcnow()-datetime.timedelta(days=1)}),('wrong-team',{'TeamIdentifier':['OTHERTEAM1']}),('wrong-cert',{'DeveloperCertificates':[]}),('store-only',{'ProvisionsAllDevices':None})]:
    value=profile|overrides;value={k:v for k,v in value.items() if v is not None}
    (work/(name+'.plist')).write_bytes(plistlib.dumps(value))
    run(['openssl','smime','-sign','-binary','-nodetach','-in',work/(name+'.plist'),'-signer',work/'cert.pem','-inkey',work/'key.pem','-outform','DER','-out',work/(name+'.mobileprovision')])
(work/'Runner.mm').write_text('''#import <Foundation/Foundation.h>
#import "zsigner.h"
#import "unarchive.h"
#import <dispatch/dispatch.h>
int main(int argc, char**argv) { @autoreleasepool {
 NSString *root=[NSString stringWithUTF8String:argv[1]];
 NSData *cert=[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"test.p12"]];
 for (NSString *name in @[@"valid",@"expired",@"wrong-team",@"wrong-cert",@"store-only"]) {
  NSData *profile=[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:[name stringByAppendingString:@".mobileprovision"]]];
  NSError *error=nil; NSDictionary *info=[ZSigner provisionInfo:profile certificate:cert password:@"fixture" error:&error];
  if ((info!=nil) != [name isEqualToString:@"valid"]) return 10;
 }
 NSData *profile=[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"valid.mobileprovision"]];
 if ([ZSigner provisionInfo:profile certificate:cert password:@"wrong" error:nil]) return 11;
 dispatch_semaphore_t semaphore=dispatch_semaphore_create(0);
 __block BOOL signedOK=NO;
 [ZSigner signStandalone:[root stringByAppendingPathComponent:@"fixture/Payload/Test.app"] certificate:cert password:@"fixture" profile:profile completion:^(BOOL success,NSError *error) { signedOK=success; if(error) NSLog(@"%@",error); dispatch_semaphore_signal(semaphore); }];
 if(dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW,60*NSEC_PER_SEC))!=0 || !signedOK) return 12;
 NSError *error=nil;
 NSProgress *progress=[NSProgress progressWithTotalUnitCount:1];
 if(!IPAWriteArchive([root stringByAppendingPathComponent:@"fixture"],[root stringByAppendingPathComponent:@"result.ipa"],progress,&error)) return 13;
 if(!IPAWriteArchiveWithCompression([root stringByAppendingPathComponent:@"fixture"],[root stringByAppendingPathComponent:@"compressed.ipa"],progress,YES,&error)) return 15;
 [progress cancel];
 if(IPAWriteArchive([root stringByAppendingPathComponent:@"fixture"],[root stringByAppendingPathComponent:@"cancelled.ipa"],progress,&error)) return 14;
 puts("Profile and resource signing checks passed");return 0;
} }
''')
app=work/'fixture/Payload/Test.app';app.mkdir(parents=True,exist_ok=True)
(app/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'org.ipastore.fixture','CFBundleExecutable':'Test','CFBundleVersion':'1','CFBundleName':'Test','CFBundlePackageType':'APPL'}))
(work/'empty.c').write_text('int main(){return 0;}')
run(['clang',work/'empty.c','-o',app/'Test'])
(app/'resource.txt').write_text('sealed resource')
run(['clang','-fobjc-arc','-fblocks','-I',root/'LiveContainerSwiftUI/Utilities','-c',root/'LiveContainerSwiftUI/Utilities/unarchive.m','-o',work/'archive.o'])
source=list((root/'ZSign').glob('*.cpp'))+list((root/'ZSign/common').glob('*.cpp'))+[root/'ZSign/zsign.mm',root/'ZSign/Utils.mm',work/'archive.o',work/'Runner.mm']
framework=root/'OpenSSL/Frameworks/macosx'
args=['clang++','-std=c++17','-fobjc-arc','-fblocks','-framework','Foundation','-F',framework,'-framework','OpenSSL','-larchive','-I',root/'ZSign','-I',root/'ZSign/common','-I',root/'LiveContainerSwiftUI/Utilities','-I',framework/'OpenSSL.framework/Headers',*source,'-o',work/'checks']
result=subprocess.run([str(a) for a in args],capture_output=True,text=True)
if result.returncode: print(result.stderr[-7000:]);result.check_returncode()
env=os.environ.copy();env['DYLD_FRAMEWORK_PATH']=str(framework)
execution=subprocess.run([str(work/'checks'),str(work)],capture_output=True,text=True,env=env)
print(execution.stdout[-2000:]);print(execution.stderr);execution.check_returncode()
with zipfile.ZipFile(work/'result.ipa') as archive:
    assert archive.testzip() is None
    assert archive.read('Payload/Test.app/resource.txt')==b'sealed resource'
    assert 'Payload/Test.app/_CodeSignature/CodeResources' in archive.namelist()
    assert archive.read('Payload/Test.app/embedded.mobileprovision')==(work/'valid.mobileprovision').read_bytes()
with zipfile.ZipFile(work/'compressed.ipa') as compressed, zipfile.ZipFile(work/'result.ipa') as stored:
    assert compressed.testzip() is None
    assert set(compressed.namelist()) == set(stored.namelist())
    for entry in compressed.infolist():
        if not entry.is_dir():
            assert entry.compress_type == zipfile.ZIP_DEFLATED
            assert compressed.read(entry.filename) == stored.read(entry.filename)
    assert all(e.compress_type == zipfile.ZIP_STORED for e in stored.infolist() if not e.is_dir())
assert not (work/'cancelled.ipa').exists()
# Check the real CodeDirectory pages and CMS signature independently of trust.
binary=(app/'Test').read_bytes();ncmds=struct.unpack_from('<I',binary,16)[0];offset=32
for _ in range(ncmds):
    command,size=struct.unpack_from('<II',binary,offset)
    if command==0x1d: signature_offset,signature_size=struct.unpack_from('<II',binary,offset+8)
    offset+=size
magic,length,count=struct.unpack_from('>III',binary,signature_offset)
assert magic==0xfade0cc0
slots={}
for i in range(count):
    kind,position=struct.unpack_from('>II',binary,signature_offset+12+i*8)
    _,size=struct.unpack_from('>II',binary,signature_offset+position)
    slots[kind]=binary[signature_offset+position:signature_offset+position+size]
assert 0x10000 in slots, 'CMS signature is mandatory'
(work/'signature.cms').write_bytes(slots[0x10000][8:]);(work/'directory.bin').write_bytes(slots[0])
run(['openssl','smime','-verify','-inform','DER','-in',work/'signature.cms','-content',work/'directory.bin','-noverify','-binary','-out',work/'verified.bin'])
cd=slots[0x1000] # SHA256 alternate directory
hashoffset,identoffset,special,pages,limit=struct.unpack_from('>IIIII',cd,16)
hashsize,hashtype,platform,pageshift=struct.unpack_from('>BBBB',cd,36)
assert hashtype==2 and hashsize==32
for page in range(pages):
    data=binary[page*(1<<pageshift):min(limit,(page+1)*(1<<pageshift))]
    assert hashlib.sha256(data).digest()==cd[hashoffset+page*hashsize:hashoffset+(page+1)*hashsize]
seal=plistlib.loads((app/'_CodeSignature/CodeResources').read_bytes())
resource=(app/'resource.txt').read_bytes()
assert seal['files2']['resource.txt']['hash2']==hashlib.sha256(resource).digest()
assert hashlib.sha256((app/'Info.plist').read_bytes()).digest()==cd[hashoffset-hashsize:hashoffset]
assert hashlib.sha256((app/'_CodeSignature/CodeResources').read_bytes()).digest()==cd[hashoffset-3*hashsize:hashoffset-2*hashsize]
(app/'resource.txt').write_text('tampered')
assert seal['files2']['resource.txt']['hash2']!=hashlib.sha256((app/'resource.txt').read_bytes()).digest()
report='Standalone checks PASS: valid/wrong-password/expired/wrong-team/wrong-cert/store-only profiles, complete resource seal, CMS cryptographic signature, SHA256 code pages and Info/resource slots, resource-tamper detection, streamed IPA CRC, profile retention, cancellation cleanup. Synthetic identity cannot establish Apple/device authorization.'
(root/'Validation/standalone-checks.txt').write_text(report+'\n');print(report)
