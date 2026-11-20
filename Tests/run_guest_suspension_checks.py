"""Exercise the actual guest Info.plist transformation and durable signing marker."""
from pathlib import Path
import subprocess
root=Path(__file__).resolve().parents[1];scratch=root/'.build/GuestSuspensionChecks';scratch.mkdir(parents=True,exist_ok=True)
runner=r'''#import <Foundation/Foundation.h>
#import "IPAGuestInfoCompatibility.h"
int main(void) { @autoreleasepool {
    NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *infoPath = [dir stringByAppendingPathComponent:@"Info.plist"], *metadataPath = [dir stringByAppendingPathComponent:@"LCAppInfo.plist"];
    NSMutableDictionary *plist = [@{@"CFBundleIdentifier":@"org.test.game", @"UIApplicationExitsOnSuspend":@YES} mutableCopy];
    NSMutableDictionary *metadata = [NSMutableDictionary new]; NSError *error = nil;
    NSCAssert(IPAPrepareGuestSuspension(plist, metadata, infoPath, metadataPath, &error), @"Transformation failed: %@", error);
    NSDictionary *stored = [NSDictionary dictionaryWithContentsOfFile:infoPath];
    NSCAssert(![stored[@"UIApplicationExitsOnSuspend"] boolValue] && [stored[@"CFBundleIdentifier"] isEqual:@"org.test.game"], @"Only suspension behavior may change");
    NSCAssert([metadata[@"IPAOriginalExitsOnSuspend"] boolValue] && [metadata[@"IPASuspensionInfoNeedsSigning"] boolValue], @"Original flag and required re-sign must be retained");
    NSCAssert(IPAPrepareGuestSuspension(plist, metadata, infoPath, metadataPath, &error) && [metadata[@"IPASuspensionInfoNeedsSigning"] boolValue], @"Retry must not clear signing intent before success");
    plist[@"UIApplicationExitsOnSuspend"] = @YES; [metadata removeAllObjects];
    NSCAssert(!IPAPrepareGuestSuspension(plist, metadata, [dir stringByAppendingPathComponent:@"missing/Info.plist"], metadataPath, &error), @"Write failure must be reported");
    NSDictionary *pending = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
    NSCAssert([pending[@"IPASuspensionInfoNeedsSigning"] boolValue] && [plist[@"UIApplicationExitsOnSuspend"] boolValue], @"Failed mutation retains durable re-sign marker and original in-memory flag");
    NSMutableDictionary *unaffected = [@{@"CFBundleIdentifier":@"org.test.other"} mutableCopy];
    NSCAssert(IPAPrepareGuestSuspension(unaffected, [NSMutableDictionary new], infoPath, metadataPath, &error) && !unaffected[@"UIApplicationExitsOnSuspend"], @"Apps already supporting suspension need no rewrite");
    [[NSFileManager defaultManager] removeItemAtPath:dir error:nil];
    puts("PASS: actual exit-on-suspend transformation, preserved identity/original flag, durable re-sign intent, idempotent retry and failed-write handling");
} return 0; }
'''
(scratch/'Checks.m').write_text(runner)
subprocess.run(['xcrun','clang','-fobjc-arc','-framework','Foundation','-I',str(root/'LiveContainerSwiftUI/Models'),str(scratch/'Checks.m'),'-o',str(scratch/'checks')],check=True)
result=subprocess.check_output([str(scratch/'checks')],text=True);(root/'Validation/guest-suspension-checks.txt').write_text(result);print(result)
