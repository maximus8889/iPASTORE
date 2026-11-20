//
//  XPCServer.h
//  LiveContainer
//
//  Created by s s on 2025/7/20.
//

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

__attribute__((swift_attr("@Sendable")))
@protocol RefreshServer
- (void)updateProgress:(double)value;
- (void)finish:(NSString*)error;
- (void)onConnection:(NSXPCConnection*)connection;
- (void)finishedLaunching;
- (void)addNotificationRequest:(UNNotificationRequest*)request;
- (void)removePendingNotificationRequestsWithIdentifiers:(NSArray<NSString*>*)identifiers;
@end

@protocol RefreshClient
- (void)refreshAllAppsWithIdentifier:(NSString*)identifier mangledTypeName:(NSString *)mangledTypeName;
- (void)cancelRefresh;
- (void)performIPAStoreTaskWithRequest:(NSDictionary<NSString*, NSString*>*)request completion:(void (^)(NSDictionary<NSString*, NSString*> *result, NSError *error))completion;
@end

@interface LiveProcessSideStoreHandler : NSObject
@property (class, readonly, strong) LiveProcessSideStoreHandler* shared;
@property NSXPCConnection* connection;
@property NSObject<RefreshServer>* server;

@end

NSXPCListener* startAnonymousListener(NSObject<RefreshServer>* reporter);
NSData* bookmarkForURL(NSURL* url);
NSObject<RefreshServer>* IPAWorkerServer(void);
NSObject *IPAStartNativeSigning(NSProgress *progress, void (^completion)(NSError *error));

NSObject *IPAStartNativeTask(NSDictionary *request, NSProgress *progress, void (^completion)(NSDictionary *result, NSError *error));

void installSideStoreHooks(void);
void installSideStoreNotificationHooks(void);

@interface SideStoreClient : NSObject<RefreshClient>
@property (atomic, strong) NSObject *nativeRefreshTask;
@property (atomic) BOOL nativeRefreshCancelled;
@property (class, readonly) SideStoreClient* shared;
- (void) relaunchLC;
@end
