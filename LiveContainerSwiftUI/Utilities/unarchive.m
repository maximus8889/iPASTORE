#import "unarchive.h"
#include "archive.h"
#include "archive_entry.h"
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <errno.h>

// Extraction is only permitted into a new private staging directory. Never follow
// links supplied by the archive or allow an entry to escape that directory.
static const int64_t IPAMaxExpandedBytes = 8LL * 1024 * 1024 * 1024;
static const NSUInteger IPAMaxEntries = 100000;

static BOOL IPAIsRelativePath(NSString *path) {
    if (!path.length || path.isAbsolutePath || [path containsString:@"\\"]) return NO;
    for (NSString *part in path.pathComponents) {
        if ([part isEqualToString:@".."] || [part isEqualToString:@"~"]) return NO;
    }
    return YES;
}

static BOOL IPAEntryIsSafe(struct archive_entry *entry, NSString *root) {
    const char *raw = archive_entry_pathname(entry);
    NSString *name = raw ? [NSString stringWithUTF8String:raw] : nil;
    if (!IPAIsRelativePath(name)) return NO;
    mode_t type = archive_entry_filetype(entry);
    if (type != AE_IFREG && type != AE_IFDIR && type != AE_IFLNK) return NO;
    // IPA ZIPs do not need hard links. Reject them rather than rewriting their
    // different libarchive target semantics.
    if (archive_entry_hardlink(entry)) return NO;
    const char *link = archive_entry_symlink(entry);
    if (link) {
        NSString *target = [NSString stringWithUTF8String:link];
        if (!target.length || target.isAbsolutePath || [target containsString:@"\\"]) return NO;
        NSString *resolved = [[[root stringByAppendingPathComponent:name] stringByDeletingLastPathComponent] stringByAppendingPathComponent:target].stringByStandardizingPath;
        if (![resolved hasPrefix:[root stringByAppendingString:@"/"]]) return NO;
    }
    return YES;
}

static struct archive *IPAOpenArchive(NSString *file) {
    struct archive *reader = archive_read_new();
    archive_read_support_format_zip(reader);
    archive_read_support_filter_none(reader);
    if (archive_read_open_filename(reader, file.fileSystemRepresentation, 65536) != ARCHIVE_OK) {
        archive_read_free(reader);
        return NULL;
    }
    return reader;
}

int extract(NSString *file, NSString *destination, NSProgress *progress) {
    return extractWithError(file, destination, progress, nil);
}

int extractWithError(NSString *file, NSString *destination, NSProgress *progress, NSError **error) {
    NSString *stage = @"Opening ZIP";
    NSString *detail = nil;
    NSString *root = destination.stringByStandardizingPath;
    // A pre-existing symlink in the root path would defeat lexical checks.
    if (!root.isAbsolutePath || ![root isEqualToString:root.stringByResolvingSymlinksInPath]) return IPAExtractUnsafe;
    struct archive *reader = IPAOpenArchive(file);
    if (!reader) return IPAExtractInvalid;
    struct archive_entry *entry;
    int status, result = IPAExtractOK;
    int64_t total = 0;
    NSUInteger count = 0;
    NSMutableSet<NSString *> *paths = [NSMutableSet set];
    stage = @"Reading ZIP entries";
    while ((status = archive_read_next_header(reader, &entry)) != ARCHIVE_EOF) {
        if (progress.cancelled) { result = IPAExtractCancelled; break; }
        if (status != ARCHIVE_OK) { result = IPAExtractInvalid; break; }
        if (!IPAEntryIsSafe(entry, root)) { result = IPAExtractUnsafe; break; }
        NSString *canonical = [NSString stringWithUTF8String:archive_entry_pathname(entry)].stringByStandardizingPath;
        if ([paths containsObject:canonical]) { result = IPAExtractUnsafe; break; }
        [paths addObject:canonical];
        int64_t size = archive_entry_size(entry);
        if (size < 0 || size > IPAMaxExpandedBytes - total || ++count > IPAMaxEntries) { result = IPAExtractTooLarge; break; }
        total += size;
        if (archive_read_data_skip(reader) != ARCHIVE_OK) { result = IPAExtractInvalid; break; }
    }
    if (result) {
        if (error) *error = [NSError errorWithDomain:@"iPAStore.Archive" code:result userInfo:@{NSLocalizedDescriptionKey: stage}];
        archive_read_free(reader); return result;
    }
    archive_read_free(reader);
    if (!count) return IPAExtractInvalid;
    NSDictionary *space = [NSFileManager.defaultManager attributesOfFileSystemForPath:root error:nil];
    if (space && [space[NSFileSystemFreeSize] longLongValue] < total + 64 * 1024 * 1024) return IPAExtractStorage;
    progress.totalUnitCount = MAX(total, 1);
    progress.completedUnitCount = 0;
    reader = IPAOpenArchive(file);
    if (!reader) return IPAExtractInvalid;
    // Anchor every write to the private staging directory. The disk writer's
    // absolute-path symlink walk rejects iOS container aliases on real devices.
    // openat/O_NOFOLLOW checks only archive-controlled components, atomically.
    int rootFD = open(root.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (rootFD < 0) { archive_read_free(reader); return IPAExtractInvalid; }
    while ((status = archive_read_next_header(reader, &entry)) != ARCHIVE_EOF) {
        if (progress.cancelled) { result = IPAExtractCancelled; break; }
        if (status != ARCHIVE_OK || !IPAEntryIsSafe(entry, root)) { result = IPAExtractInvalid; break; }
        NSString *name = [NSString stringWithUTF8String:archive_entry_pathname(entry)].stringByStandardizingPath;
        NSArray<NSString *> *parts = name.pathComponents;
        if (!parts.count || [name isEqualToString:@"."]) { result = IPAExtractUnsafe; break; }
        int parent = dup(rootFD);
        stage = @"Creating app folders";
        for (NSUInteger i = 0; i + 1 < parts.count && parent >= 0; i++) {
            const char *part = parts[i].fileSystemRepresentation;
            if (mkdirat(parent, part, 0700) != 0 && errno != EEXIST) { close(parent); parent = -1; break; }
            int next = openat(parent, part, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
            close(parent); parent = next;
        }
        if (parent < 0) { result = IPAExtractInvalid; break; }
        const char *leaf = parts.lastObject.fileSystemRepresentation;
        mode_t type = archive_entry_filetype(entry);
        stage = @"Creating app files";
        if (type == AE_IFDIR) {
            if (mkdirat(parent, leaf, 0700) != 0 && errno != EEXIST) result = IPAExtractInvalid;
            else {
                int directory = openat(parent, leaf, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
                if (directory < 0) result = IPAExtractUnsafe;
                else { close(directory); }
            }
        } else if (type == AE_IFLNK) {
            if (symlinkat(archive_entry_symlink(entry), parent, leaf) != 0) result = IPAExtractInvalid;
        } else {
            // Exclusive creation never replaces or follows an archive link.
            mode_t mode = (archive_entry_perm(entry) & 0755) | 0600;
            int output = openat(parent, leaf, O_CREAT | O_EXCL | O_WRONLY | O_NOFOLLOW | O_CLOEXEC, mode);
            if (output < 0) result = IPAExtractInvalid;
            else {
                const void *buffer;
                size_t size;
                la_int64_t offset;
                int64_t written = 0;
                stage = @"Decompressing app data";
                while ((status = archive_read_data_block(reader, &buffer, &size, &offset)) != ARCHIVE_EOF) {
                    if (progress.cancelled) { result = IPAExtractCancelled; break; }
                    int64_t expected = archive_entry_size(entry);
                    if (status != ARCHIVE_OK || offset < 0 || size > (uint64_t)(IPAMaxExpandedBytes - written) || offset > expected || size > (uint64_t)(expected - offset)) { result = IPAExtractInvalid; break; }
                    written += size;
                    if (written > expected) { result = IPAExtractInvalid; break; }
                    size_t done = 0;
                    while (done < size) {
                        ssize_t count = pwrite(output, (const char *)buffer + done, size - done, offset + done);
                        if (count < 0 && errno == EINTR) continue;
                        if (count <= 0) { result = errno == ENOSPC ? IPAExtractStorage : IPAExtractInvalid; break; }
                        done += count;
                    }
                    if (result) break;
                    progress.completedUnitCount += size;
                }
                if (!result && ftruncate(output, archive_entry_size(entry)) != 0) result = errno == ENOSPC ? IPAExtractStorage : IPAExtractInvalid;
                close(output);
            }
        }
        close(parent);
        if (result) break;
    }
    if (status != ARCHIVE_EOF && !result) result = IPAExtractInvalid;
    if (result && error) {
        const char *message = archive_error_string(reader);
        detail = message ? [NSString stringWithUTF8String:message] : nil;
        detail = [[detail stringByReplacingOccurrencesOfString:root withString:@"app staging"] stringByReplacingOccurrencesOfString:file withString:@"download"];
        *error = [NSError errorWithDomain:@"iPAStore.Archive" code:result userInfo:@{NSLocalizedDescriptionKey: detail.length ? [NSString stringWithFormat:@"%@: %@", stage, detail] : stage}];
    }
    close(rootFD);
    archive_read_free(reader);
    if (!result) progress.completedUnitCount = progress.totalUnitCount;
    return result;
}

BOOL IPAWriteArchiveWithCompression(NSString *parent, NSString *destination, NSProgress *progress, BOOL compress, NSError **error) {
    struct archive *writer = archive_write_new();
    archive_write_set_format_zip(writer);
    archive_write_set_options(writer, compress ? "zip:compression=deflate,zip:compression-level=6" : "zip:compression=store");
    BOOL success = archive_write_open_filename(writer, destination.fileSystemRepresentation) == ARCHIVE_OK;
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *root = [[NSURL fileURLWithPath:parent isDirectory:YES] URLByAppendingPathComponent:@"Payload" isDirectory:YES];
    NSDirectoryEnumerator *files = [fm enumeratorAtURL:root includingPropertiesForKeys:nil options:0 errorHandler:^BOOL(NSURL *url, NSError *e) { return NO; }];
    uint8_t buffer[65536];
    for (NSURL *file in files) {
        if (!success || progress.cancelled) { success = NO; break; }
        @autoreleasepool {
            struct stat st;
            if (lstat(file.fileSystemRepresentation, &st) != 0) { success = NO; break; }
            NSString *name = [file.path substringFromIndex:parent.length + 1];
            if (!IPAIsRelativePath(name)) { success = NO; break; }
            struct archive_entry *entry = archive_entry_new();
            archive_entry_copy_stat(entry, &st);
            archive_entry_set_pathname(entry, name.UTF8String);
            if (S_ISLNK(st.st_mode)) {
                NSString *target = [fm destinationOfSymbolicLinkAtPath:file.path error:nil];
                if (!target || target.isAbsolutePath) { archive_entry_free(entry); success = NO; break; }
                archive_entry_set_symlink(entry, target.UTF8String);
                archive_entry_set_size(entry, 0);
            } else if (!S_ISREG(st.st_mode) && !S_ISDIR(st.st_mode)) { archive_entry_free(entry); success = NO; break; }
            success = archive_write_header(writer, entry) == ARCHIVE_OK;
            archive_entry_free(entry);
            if (success && S_ISREG(st.st_mode)) {
                int fd = open(file.fileSystemRepresentation, O_RDONLY | O_NOFOLLOW);
                if (fd < 0) { success = NO; break; }
                ssize_t count;
                while ((count = read(fd, buffer, sizeof(buffer))) > 0) {
                    if (progress.cancelled || archive_write_data(writer, buffer, count) != count) { success = NO; break; }
                }
                if (count < 0) success = NO;
                close(fd);
            }
        }
    }
    if (archive_write_close(writer) != ARCHIVE_OK) success = NO;
    archive_write_free(writer);
    if (!success) {
        [fm removeItemAtPath:destination error:nil];
        if (error) *error = [NSError errorWithDomain:@"iPAStore.Archive" code:1 userInfo:@{NSLocalizedDescriptionKey:progress.cancelled ? @"Installation cancelled." : @"The signed installation package could not be saved. Check available storage."}];
    }
    return success;
}

BOOL IPAWriteArchive(NSString *parent, NSString *destination, NSProgress *progress, NSError **error) {
    return IPAWriteArchiveWithCompression(parent, destination, progress, NO, error);
}
