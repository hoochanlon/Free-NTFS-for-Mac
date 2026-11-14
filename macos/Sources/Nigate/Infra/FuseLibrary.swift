import Foundation

/// ntfs-3g（gromgit/ntfs-3g-mac）把 libfuse 的 install_name 写死为
/// `/usr/local/lib/libfuse.2.dylib`。macFUSE 官方 pkg 在 Apple Silicon 上也装到这里，
/// 不在 `/opt/homebrew/lib`。
///
/// Homebrew `list --cask macfuse` 只表示 Caskroom 里有安装包，不表示 dylib / macfuse.fs
/// 还在磁盘上（卸载脚本删文件后会出现这种假阳性）。
enum FuseLibrary {
    static let installName = "/usr/local/lib/libfuse.2.dylib"

    static let dylibCandidates = [
        "/usr/local/lib/libfuse.2.dylib",
        "/opt/homebrew/lib/libfuse.2.dylib"
    ]

    static let filesystemMarkers = [
        "/Library/Filesystems/macfuse.fs/Contents/Resources/mount_macfuse",
        "/Library/Filesystems/macfuse.fs/Contents/Resources/load_macfuse"
    ]

    struct Snapshot: Equatable, Sendable {
        var dylibPath: String?
        var filesystemPresent: Bool

        var isUsable: Bool { dylibPath != nil && filesystemPresent }

        /// dylib 不在 ntfs-3g 写死的 install_name 上时，启动需要 DYLD_* 覆盖。
        var dyldLibraryPath: String? {
            guard let dylibPath, dylibPath != FuseLibrary.installName else { return nil }
            return URL(fileURLWithPath: dylibPath).deletingLastPathComponent().path
        }
    }

    static func inspect(exists: (String) -> Bool = Shell.exists) -> Snapshot {
        Snapshot(
            dylibPath: dylibCandidates.first(where: exists),
            filesystemPresent: filesystemMarkers.contains(where: exists)
        )
    }

    static func launchEnv(exists: (String) -> Bool = Shell.exists) throws -> [String: String] {
        let snapshot = inspect(exists: exists)
        guard snapshot.isUsable else { throw AppError.macfuseMissing }
        guard let path = snapshot.dyldLibraryPath else { return [:] }
        return [
            "DYLD_LIBRARY_PATH": path,
            "DYLD_FALLBACK_LIBRARY_PATH": path
        ]
    }

    static func isMissingLibraryError(_ text: String) -> Bool {
        let n = text.lowercased()
        guard n.contains("libfuse") else { return false }
        return n.contains("library not loaded")
            || n.contains("image not found")
            || n.contains("dyld")
    }
}
