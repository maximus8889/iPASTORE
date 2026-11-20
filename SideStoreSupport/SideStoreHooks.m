//
//  SideStoreHooks.m
//  LiveContainer
//
//  Created by s s on 2026/8/6.
//
#include "../LiveContainer/utils.h"
#include "../LiveContainer/LCSharedUtils.h"
#include "XPCServer.h"
#import <sys/sysctl.h>
@import UserNotifications;
@import UIKit;

@interface LCAuthorizedNotificationSettings : UNNotificationSettings
@end

@implementation LCAuthorizedNotificationSettings

- (UNAuthorizationStatus)authorizationStatus {
    return UNAuthorizationStatusAuthorized;
}

@end



@implementation UNUserNotificationCenter(SideStoreHooks)

- (void)lc_addNotificationRequest:(UNNotificationRequest*)request
            withCompletionHandler:(void (^)(NSError* error))completionHandler {
    LiveProcessSideStoreHandler* handler = [PrivClass(LiveProcessSideStoreHandler) shared];
    [handler.server addNotificationRequest:request];
    if (completionHandler) {
        completionHandler(nil);
    }
}

- (void)lc_removePendingNotificationRequestsWithIdentifiers:(NSArray<NSString*>*)identifiers {
    LiveProcessSideStoreHandler* handler = [PrivClass(LiveProcessSideStoreHandler) shared];
    [handler.server removePendingNotificationRequestsWithIdentifiers:identifiers];
}

- (void)lc_getNotificationSettingsWithCompletionHandler:(void (^)(UNNotificationSettings* settings))completionHandler {
    if (!completionHandler) {
        return;
    }

    UNNotificationSettings* settings = class_createInstance(LCAuthorizedNotificationSettings.class, 0);
    completionHandler(settings);
}

@end

static NSBundle *IPAHostBundle(void) {
    if (!NSUserDefaults.isLiveProcess) return NSUserDefaults.lcMainBundle;
    return [NSBundle bundleWithURL:NSUserDefaults.lcMainBundle.bundleURL.URLByDeletingLastPathComponent.URLByDeletingLastPathComponent];
}

@implementation NSBundle(SideStoreHooks)

+ (NSString*)hook_appbundleIdentifier {
    return IPAHostBundle().bundleIdentifier;
}

+ (NSString*)hook_storeAppBundleIdentifier {
    return IPAHostBundle().bundleIdentifier;
}

- (NSString*)hook_altstoreAppGroup {
    return LCSharedUtils.appGroupID;
}

+ (NSString*)hook_baseAltStoreAppGroupID {
    return @"group.com.SideStore.SideStore";
}

+ (NSBundle*)hook_activeBundle {
    if (!NSUserDefaults.isLiveProcess) return NSUserDefaults.lcMainBundle;
    
    static NSBundle* lcAppBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lcAppBundle = [NSBundle bundleWithURL: NSUserDefaults.lcMainBundle.bundleURL.URLByDeletingLastPathComponent.URLByDeletingLastPathComponent];
    });
    return lcAppBundle;
}

@end

static void IPAReturnFromSigning(void) {
    Class bridge = NSClassFromString(@"IPAStoreSigningController");
    SEL selector = NSSelectorFromString(@"setupStatus");
    Method method = class_getClassMethod(bridge, selector);
    if (method) {
        NSDictionary *(*statusMethod)(id, SEL) = (void *)method_getImplementation(method);
        NSDictionary *status = statusMethod(bridge, selector);
        NSMutableDictionary *safeStatus = [NSMutableDictionary dictionary];
        for (NSString *key in @[@"pairingImported", @"accountStored", @"certificateAvailable", @"connectionCheckedAt"]) {
            id value = status[key];
            if ([value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSDate.class]) safeStatus[key] = value;
        }
        safeStatus[@"updatedAt"] = NSDate.date;
        if ([safeStatus[@"accountStored"] boolValue] && [safeStatus[@"certificateAvailable"] boolValue]) {
            [NSUserDefaults.lcUserDefaults setBool:YES forKey:@"IPACompleteSigningSetup"];
        }
        [NSUserDefaults.lcUserDefaults setObject:safeStatus forKey:@"IPASigningReadiness"];
    }
    if (getenv("IPA_SIGNING_INTERACTIVE")) {
        // Only readiness flags leave the signing process; account secrets stay
        // in the existing shared keychain. The host remains alive throughout.
        NSDictionary *status = [NSUserDefaults.lcUserDefaults dictionaryForKey:@"IPASigningReadiness"];
        NSURL *file = [[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].lastObject URLByAppendingPathComponent:@"IPAStoreSetupStatus.plist"];
        if (status) [status writeToURL:file atomically:YES];
        Class handler = NSClassFromString(@"LiveProcessHandler");
        SEL selector = NSSelectorFromString(@"extensionContext");
        Method method = class_getClassMethod(handler, selector);
        if (method) {
            NSExtensionContext *(*contextMethod)(id, SEL) = (void *)method_getImplementation(method);
            [contextMethod(handler, selector) completeRequestReturningItems:@[] completionHandler:nil];
        }
        return;
    }
    [LCSharedUtils launchToGuestAppWithClassicMode:0];
}

static UIViewController *IPANativeSigningController(void) {
    Class bridge = NSClassFromString(@"IPAStoreSigningController");
    SEL selector = NSSelectorFromString(@"controllerWithAppearance:returnHandler:");
    Method method = class_getClassMethod(bridge, selector);
    if (method) {
        UIViewController *(*factory)(id, SEL, NSString *, void (^)(void)) = (void *)method_getImplementation(method);
        NSString *appearance = [NSUserDefaults.lcUserDefaults stringForKey:@"IPAAppearance"] ?: @"system";
        return factory(bridge, selector, appearance, ^{ IPAReturnFromSigning(); });
    }
    // A mismatched development package must never expose an upstream storefront.
    UIViewController *error = [UIViewController new];
    error.view.backgroundColor = UIColor.systemBackgroundColor;
    UILabel *label = [UILabel new];
    label.text = @"Signing setup is unavailable in this build. Please install a matching iPAStore package.";
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = UIColor.secondaryLabelColor;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [error.view addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:error.view.leadingAnchor constant:24],
        [label.trailingAnchor constraintEqualToAnchor:error.view.trailingAnchor constant:-24],
        [label.centerYAnchor constraintEqualToAnchor:error.view.centerYAnchor]
    ]];
    return error;
}

static void IPANativeLaunchLoad(UIViewController *self, SEL cmd) {
    // Original launch flow constructs the backend's tabs and onboarding; neither is our UI.
    void (*baseLoad)(id, SEL) = (void *)class_getMethodImplementation(UIViewController.class, cmd);
    baseLoad(self, cmd);
    UIViewController *controller = IPANativeSigningController();
    [self addChildViewController:controller];
    controller.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:controller.view];
    [controller didMoveToParentViewController:self];
    [NSLayoutConstraint activateConstraints:@[
        [controller.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [controller.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [controller.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [controller.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}
static void IPANativeLaunchAppear(UIViewController *self, SEL cmd, BOOL animated) {
    void (*baseAppear)(id, SEL, BOOL) = (void *)class_getMethodImplementation(UIViewController.class, cmd);
    baseAppear(self, cmd, animated);
}

@implementation NSBundle (IPASigningPresentation)
- (NSString *)ipa_localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)table {
    NSString *text = [self ipa_localizedStringForKey:key value:value table:table];
    NSString *lower = key.lowercaseString;
    if ([text containsString:@"://"] || [lower containsString:@"license"] ||
        [lower containsString:@"copyright"] || [lower containsString:@"credit"]) return text;
    for (NSString *name in @[@"LiveContainer+SideStore", @"SideStore+LiveContainer", @"LiveContainer", @"SideStore"]) {
        text = [text stringByReplacingOccurrencesOfString:name withString:@"iPAStore"];
    }
    return text;
}
@end

void installSideStoreHooks(void) {
    swizzleClassMethod(NSBundle.class, @selector(appbundleIdentifier), @selector(hook_appbundleIdentifier));
    swizzleClassMethod(NSBundle.class, @selector(storeAppBundleIdentifier), @selector(hook_storeAppBundleIdentifier));
    swizzle(NSBundle.class, @selector(altstoreAppGroup), @selector(hook_altstoreAppGroup));
    swizzleClassMethod(NSBundle.class, @selector(activeBundle), @selector(hook_activeBundle));
    swizzleClassMethod(NSBundle.class, @selector(baseAltStoreAppGroupID), @selector(hook_baseAltStoreAppGroupID));
    if (!NSUserDefaults.isLiveProcess || getenv("IPA_SIGNING_INTERACTIVE")) {
        Class launch = NSClassFromString(@"SideStore.LaunchViewController");
        Method load = class_getInstanceMethod(launch, @selector(viewDidLoad));
        Method appear = class_getInstanceMethod(launch, @selector(viewDidAppear:));
        if (load && appear) {
            method_setImplementation(load, (IMP)IPANativeLaunchLoad);
            method_setImplementation(appear, (IMP)IPANativeLaunchAppear);
        }
        swizzle(NSBundle.class, @selector(localizedStringForKey:value:table:), @selector(ipa_localizedStringForKey:value:table:));
    }
}

void installSideStoreNotificationHooks(void) {
    swizzle(UNUserNotificationCenter.class,
            @selector(addNotificationRequest:withCompletionHandler:),
            @selector(lc_addNotificationRequest:withCompletionHandler:));
    swizzle(UNUserNotificationCenter.class,
            @selector(removePendingNotificationRequestsWithIdentifiers:),
            @selector(lc_removePendingNotificationRequestsWithIdentifiers:));
    swizzle(UNUserNotificationCenter.class,
            @selector(getNotificationSettingsWithCompletionHandler:),
            @selector(lc_getNotificationSettingsWithCompletionHandler:));
}
