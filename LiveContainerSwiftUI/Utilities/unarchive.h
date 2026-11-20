#import <Foundation/Foundation.h>

typedef NS_ENUM(int, IPAExtractResult) {
    IPAExtractOK = 0,
    IPAExtractInvalid = 1,
    IPAExtractUnsafe = 2,
    IPAExtractTooLarge = 3,
    IPAExtractStorage = 4,
    IPAExtractCancelled = 5
};
extern int extract(NSString* fileToExtract, NSString* extractionPath, NSProgress* progress);

extern int extractWithError(NSString* fileToExtract, NSString* extractionPath, NSProgress* progress, NSError **error);
// Streams a validated Payload directory to disk without holding the IPA in RAM.
#ifdef __cplusplus
extern "C"
#endif
BOOL IPAWriteArchive(NSString *payloadParent, NSString *destination, NSProgress *progress, NSError **error);

#ifdef __cplusplus
extern "C"
#endif
BOOL IPAWriteArchiveWithCompression(NSString *payloadParent, NSString *destination, NSProgress *progress, BOOL compress, NSError **error);
