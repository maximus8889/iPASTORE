"""Exercise the production Objective-C extractor against hostile and valid IPAs."""
from pathlib import Path
import subprocess, zipfile, stat, shutil, os
root = Path(__file__).resolve().parents[1]
scratch = root/'.build/ArchiveChecks'
scratch.mkdir(parents=True, exist_ok=True)
runner = scratch/'Runner.m'
runner.write_text('''#import <Foundation/Foundation.h>
#import "unarchive.h"
int main(int argc, const char **argv) { @autoreleasepool {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:0];
    if (argc > 3) [progress cancel];
    int result = extract([NSString stringWithUTF8String:argv[1]], [NSString stringWithUTF8String:argv[2]], progress);
    printf("%d\\n", result); return 0;
} }
''')
subprocess.run(['clang','-fobjc-arc','-fblocks','-framework','Foundation','-larchive','-I',str(root/'LiveContainerSwiftUI/Utilities'),str(runner),str(root/'LiveContainerSwiftUI/Utilities/unarchive.m'),'-o',str(scratch/'extract-check')], check=True)
def check(name, entries, expected, cancel=False):
    archive=scratch/(name+'.ipa')
    with zipfile.ZipFile(archive,'w') as z:
        for path,value,kind in entries:
            info=zipfile.ZipInfo(path)
            info.create_system=3
            info.external_attr=((stat.S_IFLNK|0o777) if kind=='link' else (stat.S_IFREG|0o755))<<16
            z.writestr(info,value)
    output=scratch/name
    if output.exists(): shutil.rmtree(output)
    output.mkdir()
    result=int(subprocess.check_output([str(scratch/'extract-check'),str(archive.resolve()),str(output.resolve())]+(['cancel'] if cancel else [])))
    assert result==expected, (name,result,expected)
    if result==0:
        assert (output/'Payload/Test.app/Test').read_bytes()==b'binary'
    return name
valid=[('Payload/Test.app/Test',b'binary','file'),('Payload/Test.app/Frameworks/F.framework/Versions/A/F',b'framework','file'),('Payload/Test.app/Frameworks/F.framework/F',b'Versions/A/F','link')]
passed=[check('valid-app-and-framework-link',valid,0),check('parent-traversal',[('../escaped',b'x','file')],2),check('absolute-path',[('/tmp/IPAStore-escaped',b'x','file')],2),check('symlink-escape',[('Payload/Test.app/escape',b'../../../../escaped','link')],2),check('symlink-follow',[('Payload/Test.app/dir',b'../real','link'),('Payload/Test.app/dir/file',b'x','file')],1),check('cancelled',valid,5,True)]
# Real IPA tools include directories, deflated files, data descriptors, ZIP64
# and directory records after child files. Exercise all of these formats.
import io
class StreamingBuffer(io.BytesIO):
    def seekable(self): return False
    def seek(self,*args): raise io.UnsupportedOperation('stream')
for name,streaming,late_directories,zip64 in [('deflate-directories',False,False,False),('deflate-late-directories',False,True,False),('streaming-descriptors-zip64',True,False,True)]:
    buffer=StreamingBuffer() if streaming else io.BytesIO()
    with zipfile.ZipFile(buffer,'w',compression=zipfile.ZIP_DEFLATED) as z:
        if not late_directories:
            z.writestr('Payload/',b'');z.writestr('Payload/Test.app/',b'')
        with z.open('Payload/Test.app/Test','w',force_zip64=zip64) as out:out.write(b'binary')
        z.writestr('Payload/Test.app/large.dat',b'compressed data'*10000)
        if late_directories:
            z.writestr('Payload/',b'');z.writestr('Payload/Test.app/',b'')
    archive=scratch/(name+'.ipa');archive.write_bytes(buffer.getvalue())
    output=scratch/name;shutil.rmtree(output,ignore_errors=True);output.mkdir()
    result=int(subprocess.check_output([str(scratch/'extract-check'),str(archive.resolve()),str(output.resolve())]))
    assert result==0,(name,result)
    assert (output/'Payload/Test.app/large.dat').read_bytes()==b'compressed data'*10000
    passed.append(name)
archive=scratch/'broken.ipa';archive.write_bytes(b'PK\x03\x04truncated')
output=scratch/'broken';output.mkdir(exist_ok=True)
assert int(subprocess.check_output([str(scratch/'extract-check'),str(archive.resolve()),str(output.resolve())]))!=0
passed.append('truncated-archive')
assert not (scratch/'escaped').exists()
report='Archive safety checks PASS: '+', '.join(passed)+'\n'
(root/'Validation/archive-checks.txt').write_text(report)
print(report)
