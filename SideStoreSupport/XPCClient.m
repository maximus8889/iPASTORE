//
//  XPCClient.m
//  AltStore
//
//  Created by s s on 2025/7/20.
//  Copyright © 2025 SideStore. All rights reserved.
//
#include "XPCServer.h"
#include "../LiveContainer/utils.h"
#include "../LiveContainer/LCSharedUtils.h"
@import UIKit;
#import <objc/message.h>

@interface SideStoreClient(Swift)
- (void)performNativeRefreshWithServer:(id<RefreshServer>)server;
- (void)performRefreshForRealWithIdentifier:(NSString*)identifier
                            mangledTypeName:(NSString*)mangledTypeName
                                     server:(id <RefreshServer> _Nonnull)server;

@end

static LiveProcessSideStoreHandler* handler = nil;
void installSideStoreHooks(void);

@implementation SideStoreClient

+ (SideStoreClient*)shared {
    static SideStoreClient* sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedClient = [SideStoreClient new];
    });

    return sharedClient;
}

+ (void)load {
    if(!NSUserDefaults.isSideStore) return;
    
    installSideStoreHooks();
    
    if(!NSUserDefaults.isLiveProcess || getenv("IPA_SIGNING_INTERACTIVE")) return;
    
    handler = [PrivClass(LiveProcessSideStoreHandler) shared];
    installSideStoreNotificationHooks();
    handler.connection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(RefreshClient)];
    handler.connection.exportedObject = SideStoreClient.shared;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidFinishLaunching:)
                                                 name:UIApplicationDidFinishLaunchingNotification
                                               object:nil];
}

// Implement the callback method
+ (void)appDidFinishLaunching:(NSNotification *)notification {
    NSDictionary *launchOptions = notification.userInfo;
    [handler.server finishedLaunching];
}

- (void) relaunchLC {
    [LCSharedUtils launchToGuestAppWithClassicMode:0];
}

- (void)refreshAllAppsWithIdentifier:(NSString*)identifier mangledTypeName:(NSString *)mangledTypeName {
    if(!handler) {
        return;
    }
    self.nativeRefreshCancelled = NO;
    [self performNativeRefreshWithServer:handler.server];
}

- (void)cancelRefresh {
    self.nativeRefreshCancelled = YES;
    NSObject *task = self.nativeRefreshTask;
    SEL cancel = NSSelectorFromString(@"cancel");
    if ([task respondsToSelector:cancel]) ((void (*)(id, SEL))objc_msgSend)(task, cancel);
}

@end

NSObject *IPAStartNativeSigning(NSProgress *progress, void (^completion)(NSError *error)) {
    Class bridge = NSClassFromString(@"IPAStoreSigningController");
    SEL selector = NSSelectorFromString(@"startRefreshWithProgress:completion:");
    Method method = class_getClassMethod(bridge, selector);
    if (!method) return nil;
    NSObject *(*start)(id, SEL, NSProgress *, void (^)(NSError *)) = (void *)method_getImplementation(method);
    return start(bridge, selector, progress, completion);
}

NSObject *IPAStartNativeTask(NSDictionary *request, NSProgress *progress, void (^completion)(NSDictionary *result, NSError *error)) {
    Class bridge = NSClassFromString(@"IPAStoreSigningController");
    SEL selector = NSSelectorFromString(@"startTaskWithRequest:progress:completion:");
    Method method = class_getClassMethod(bridge, selector);
    if (!method) return nil;
    NSObject *(*start)(id, SEL, NSDictionary *, NSProgress *, void (^)(NSDictionary *, NSError *)) = (void *)method_getImplementation(method);
    return start(bridge, selector, request, progress, completion);
}

NSObject<RefreshServer>* IPAWorkerServer(void) { return handler.server; }
