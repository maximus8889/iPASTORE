#import <Foundation/Foundation.h>

// Container copies should suspend rather than deliberately exit. Keep the
// publisher flag in our metadata and persist signing intent before mutation,
// so a failed/interrupted signing attempt cannot reuse an old signature.
static inline BOOL IPAWritePropertyList(NSDictionary *value, NSString *path, NSError **error) {
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:value format:NSPropertyListBinaryFormat_v1_0 options:0 error:error];
    return data && [data writeToFile:path options:NSDataWritingAtomic error:error];
}
static inline BOOL IPAPrepareGuestSuspension(NSMutableDictionary *plist, NSMutableDictionary *metadata, NSString *infoPath, NSString *metadataPath, NSError **error) {
    if (![plist[@"UIApplicationExitsOnSuspend"] boolValue]) return YES;
    metadata[@"IPAOriginalExitsOnSuspend"] = plist[@"UIApplicationExitsOnSuspend"];
    metadata[@"IPASuspensionInfoNeedsSigning"] = @YES;
    if (!IPAWritePropertyList(metadata, metadataPath, error)) return NO;
    NSMutableDictionary *updated = plist.mutableCopy;
    updated[@"UIApplicationExitsOnSuspend"] = @NO;
    if (!IPAWritePropertyList(updated, infoPath, error)) return NO;
    [plist setDictionary:updated];
    return YES;
}
