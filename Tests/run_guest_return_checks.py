"""Exercise the actual return callback over Darwin notifications with owned-scene fixtures."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
scratch = root / '.build' / 'GuestReturnChecks'
scratch.mkdir(parents=True, exist_ok=True)
source = (root/'MultitaskSupport/AppSceneViewController.m').read_text()
callback = source[source.index('static NSHashTable<AppSceneViewController *> *ipaGuestScenes;'):source.index('@implementation AppSceneViewController')]
window_lifecycle = source[source.index('- (void)viewDidMoveToWindow:'):source.index('- (void)openURLScheme:')]
prefix = r'''#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
@interface UIWindowScene : NSObject
@property int registered, unregistered;
- (void)_registerSettingsDiffActionArray:(NSArray *)array forKey:(NSString *)key;
- (void)_unregisterSettingsDiffActionArrayForKey:(NSString *)key;
@end
@interface UIWindow : NSObject
@property(nonatomic,strong) UIWindowScene *windowScene;
@end
@interface SceneParent : NSObject
- (void)viewDidMoveToWindow:(UIWindow *)window shouldAppearOrDisappear:(BOOL)appear;
@end
@interface AppSceneViewController : SceneParent
@property(nonatomic,weak) UIWindowScene *hostScene;
@property(nonatomic,copy) NSString *sceneID;
- (void)viewDidMoveToWindow:(UIWindow *)window shouldAppearOrDisappear:(BOOL)appear;
@property(nonatomic,copy) NSString *ipaReturnNotificationName;
@property(nonatomic) BOOL isAppRunning;
@property(nonatomic,strong) id delegate;
@end
@protocol GuestReturn <NSObject>
- (void)appSceneVCRequestedReturn:(AppSceneViewController *)scene;
@end
'''
runner = r'''
@implementation UIWindowScene
- (void)_registerSettingsDiffActionArray:(NSArray *)array forKey:(NSString *)key { self.registered++; }
- (void)_unregisterSettingsDiffActionArrayForKey:(NSString *)key { self.unregistered++; }
@end
@implementation UIWindow
@end
@implementation SceneParent
- (void)viewDidMoveToWindow:(UIWindow *)window shouldAppearOrDisappear:(BOOL)appear {}
@end
@implementation AppSceneViewController
WINDOW_LIFECYCLE_IMPLEMENTATION
@end
@interface ReturnCounter : NSObject<GuestReturn>
@property int count;
@end
@implementation ReturnCounter
- (void)appSceneVCRequestedReturn:(AppSceneViewController *)scene { self.count++; scene.ipaReturnNotificationName = nil; }
@end
static void drain(void) { [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.15]]; }
int main(int argc, const char *argv[]) { @autoreleasepool {
    if (argc == 3 && !strcmp(argv[1], "--post")) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)@(argv[2]), NULL, NULL, YES);
        return 0;
    }
    ipaGuestScenes = [NSHashTable weakObjectsHashTable];
    AppSceneViewController *owned = [AppSceneViewController new]; ReturnCounter *counter = [ReturnCounter new];
    NSString *name = [@"app.ipastore.test.return." stringByAppendingString:NSUUID.UUID.UUIDString];
    owned.ipaReturnNotificationName = name; owned.isAppRunning = YES; owned.delegate = counter; [ipaGuestScenes addObject:owned];
    UIWindowScene *firstScene = [UIWindowScene new], *secondScene = [UIWindowScene new];
    UIWindow *window = [UIWindow new]; window.windowScene = firstScene; owned.sceneID = @"owned-scene";
    [owned viewDidMoveToWindow:window shouldAppearOrDisappear:YES];
    [owned viewDidMoveToWindow:nil shouldAppearOrDisappear:YES];
    NSCAssert(owned.delegate == counter && firstScene.registered == 1 && firstScene.unregistered == 1, @"Temporary window detach must retain the guest delegate and unregister the old scene");
    [owned viewDidMoveToWindow:window shouldAppearOrDisappear:YES];
    window.windowScene = secondScene;
    [owned viewDidMoveToWindow:window shouldAppearOrDisappear:YES];
    NSCAssert(owned.delegate == counter && firstScene.registered == 2 && firstScene.unregistered == 2 && secondScene.registered == 1, @"Reattached windows must preserve return callbacks and restore scene actions");
    // Even a stale raw observer pointer cannot be dereferenced by the callback.
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (void *)0x1234, IPAGuestRequestedReturn, (__bridge CFStringRef)name, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    IPAGuestRequestedReturn(NULL, (void *)0xDEAD, CFSTR("foreign-launch"), NULL, NULL); drain();
    NSCAssert(counter.count == 0, @"Unowned signal must not close a guest");
    owned.isAppRunning = NO;
    IPAGuestRequestedReturn(NULL, NULL, (__bridge CFStringRef)name, NULL, NULL); drain();
    NSCAssert(counter.count == 0, @"Exited guest cannot authorize a return");
    owned.isAppRunning = YES;
    NSTask *sender = [NSTask new]; sender.executableURL = [NSURL fileURLWithPath:@(argv[0])]; sender.arguments = @[@"--post", name];
    NSError *error = nil; NSCAssert([sender launchAndReturnError:&error], @"Sender failed: %@", error); [sender waitUntilExit];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2];
    while (counter.count == 0 && deadline.timeIntervalSinceNow > 0) drain();
    NSCAssert(counter.count == 1, @"Cross-process owned notification did not arrive");
    IPAGuestRequestedReturn(NULL, NULL, (__bridge CFStringRef)name, NULL, NULL); drain();
    NSCAssert(counter.count == 1, @"Stopped/removed launch must ignore delayed duplicate signals");
    CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), (void *)0x1234, (__bridge CFStringRef)name, NULL);
    puts("PASS: actual return callback, real cross-process Darwin delivery, unowned/dead scene rejection, stale observer safety and duplicate-after-close rejection, window detach/reattach delegate retention");
} return 0; }
'''
(scratch/'ReturnChecks.m').write_text(prefix+callback+runner.replace('WINDOW_LIFECYCLE_IMPLEMENTATION', window_lifecycle))
subprocess.run(['xcrun','clang','-fobjc-arc','-fblocks','-framework','Foundation','-framework','CoreFoundation',str(scratch/'ReturnChecks.m'),'-o',str(scratch/'return-checks')],check=True)
result=subprocess.run([str(scratch/'return-checks')],capture_output=True,text=True)
if result.returncode:
    print(result.stdout); print(result.stderr); result.check_returncode()
(root/'Validation/guest-return-checks.txt').write_text(result.stdout)
print(result.stdout)
