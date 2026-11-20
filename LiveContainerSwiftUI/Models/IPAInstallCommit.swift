import Foundation
import Darwin

enum IPAInstallCommit {
    // Both directories are on the same volume. RENAME_SWAP changes their names
    // atomically: an interruption cannot leave an existing app's path empty.
    // Keeping its path also preserves existing shortcuts and external links.
    static func replace(prepared: URL, current: URL) throws {
        guard prepared != current,
              prepared.deletingLastPathComponent().standardizedFileURL == current.deletingLastPathComponent().standardizedFileURL else { throw POSIXError(.EXDEV) }
        for url in [prepared, current] {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else { throw POSIXError(.EINVAL) }
        }
        let result = prepared.withUnsafeFileSystemRepresentation { first in
            current.withUnsafeFileSystemRepresentation { second in renamex_np(first!, second!, UInt32(RENAME_SWAP)) }
        }
        if result != 0 { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    }
}
