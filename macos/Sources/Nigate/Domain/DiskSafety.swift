import Foundation
import Darwin

enum DiskSafety {
    static func isPartition(_ path: String) -> Bool {
        path.range(of: #"^/dev/disk\d+s\d+$"#, options: .regularExpression) != nil
    }

    static func isWholeDisk(_ path: String) -> Bool {
        path.range(of: #"^/dev/disk\d+$"#, options: .regularExpression) != nil
    }

    static func isNTFSFilesystem(_ description: String) -> Bool {
        let patterns = [
            #"(?im)^\s*(?:File System Personality|File System Type|Type \(Bundle\)|Partition Type|Format|格式):\s*(?:(?:xntfs|ntfs(?:-[\w-]+)?|windows_ntfs)\b|(?:Unknown|未知)\s+\((?:xntfs|ntfs(?:-[\w-]+)?|windows_ntfs)\))\s*$"#,
            #"(?im)^\s*\d+:\s*(?:xntfs|ntfs(?:-[\w-]+)?|windows_ntfs)\b"#,
            #"(?im)^/dev/disk\d+s\d+\s+on\s+/Volumes/.*\s+\((?:xntfs|ntfs(?:-[\w-]+)?|windows_ntfs)\b[^)]*\)\s*$"#
        ]
        return patterns.contains { pattern in
            description.range(of: pattern, options: .regularExpression) != nil
        }
    }

    /// diskutil 卷身份：任一身份字段命中 NTFS 即真。
    /// personality 可能误报 ExFAT/MS-DOS，不能用“第一个字段非 NTFS”直接否决。
    static func isNTFSVolumeInfo(_ info: String) -> Bool {
        let identityFields = [
            "File System Personality",
            "File System Type",
            "Type (Bundle)",
            "FilesystemType",
            "FilesystemName",
            "Partition Type",
            "Format",
            "格式"
        ]
        for name in identityFields {
            if let value = field(info, name),
               isNTFSFilesystem("\(name): \(value)") {
                return true
            }
        }
        return isNTFSFilesystem(info)
    }

    /// 已挂载的 macfuse/ntfs-3g 是否应视为本应用管理的 NTFS 卷。
    ///
    /// 证据优先级：挂载表 fuse 事实 > diskutil 身份字段。
    /// personality 误报不得否决已确认的 fuse 挂载。
    ///
    /// 实机常见矛盾：
    /// - Partition Type = Windows_NTFS，Personality = ExFAT
    /// - Partition Type = Microsoft Basic Data，Personality = MS-DOS
    /// - mount 选项仅有 macfuse,local,...（allow_other 不一定出现在 mount 表）
    static func isConfirmedNTFSFuseMount(
        _ mountOutput: String,
        deviceInfo: String,
        devicePath: String,
        mountPoint: String
    ) -> Bool {
        guard isPartition(devicePath),
              mountPoint.hasPrefix("/Volumes/"),
              mountPoint != "/Volumes/",
              let mounted = fuseMount(
                in: mountOutput,
                devicePath: devicePath,
                mountPoint: mountPoint
              ) else { return false }

        // 正向身份：personality / partition type 任一报 NTFS
        if isNTFSVolumeInfo(deviceInfo) { return true }

        // GPT 上 NTFS 常标为 Microsoft Basic Data，而 personality 误报 MS-DOS/ExFAT
        if let partitionType = field(deviceInfo, "Partition Type")?.lowercased(),
           partitionType.contains("microsoft basic data") || partitionType.contains("ntfs") {
            return true
        }

        // 本应用留下的挂载标记（mount 表不一定回显 allow_other）
        let disk = devicePath.replacingOccurrences(of: "/dev/", with: "")
        if FileManager.default.fileExists(atPath: "/tmp/ntfs_mounted_\(disk)") {
            return true
        }

        // 兼容：显式带上 ntfs-3g 特征选项时仍确认
        let options = Set(mounted.options)
        return options.contains("local")
            && (options.contains("allow_other") || options.contains("auto_xattr"))
    }

    /// 从挂载表取出指定设备+挂载点的 fuse 记录；不是 fuse 则 nil。
    static func fuseMount(
        in mountOutput: String,
        devicePath: String,
        mountPoint: String
    ) -> MountedVolume? {
        MountTable.parse(mountOutput).first { volume in
            volume.devicePath == devicePath
                && volume.mountPoint == mountPoint
                && isFuseDriver(volume.driver)
        }
    }

    static func isFuseDriver(_ driver: String) -> Bool {
        let value = driver.lowercased()
        return value == "macfuse" || value == "fuse" || value == "ntfs-3g" || value.contains("fuse")
    }

    static func isMountedXNTFSFilesystem(_ mountOutput: String, devicePath: String, mountPoint: String) -> Bool {
        guard isPartition(devicePath),
              mountPoint.hasPrefix("/Volumes/"),
              mountPoint != "/Volumes/" else { return false }
        let device = NSRegularExpression.escapedPattern(for: devicePath)
        let volume = NSRegularExpression.escapedPattern(for: mountPoint)
        let pattern = #"(?im)^"# + device + #"[ \t]+on[ \t]+"# + volume
            + #"[ \t]+\([ \t]*xntfs(?:,[ \t]*[^)]*)?\)[ \t]*$"#
        return mountOutput.range(of: pattern, options: .regularExpression) != nil
    }

    static func parentDiskPath(_ devicePath: String) -> String {
        String(devicePath.replacingOccurrences(of: #"s\d+$"#, with: "", options: .regularExpression))
    }

    static func parentDiskId(_ diskOrPath: String) -> String {
        diskOrPath
            .replacingOccurrences(of: "^/dev/", with: "", options: .regularExpression)
            .replacingOccurrences(of: #"s\d+$"#, with: "", options: .regularExpression)
    }

    static func partitionIndex(_ disk: String) -> String? {
        guard let match = disk.range(of: #"s(\d+)$"#, options: .regularExpression) else { return nil }
        return String(disk[match].dropFirst())
    }

    static func canFormat(fromListTags tags: String?) -> Bool {
        guard let tags else { return false }
        let normalized = tags.lowercased()
        let tokens = Set(normalized.split { !$0.isLetter && !$0.isNumber }.map(String.init))
        let blocked = ["internal", "virtual", "synthesized", "image", "unknown"]
        let negative = ["not", "non", "no", "false"]
        guard tokens.contains("external"), tokens.contains("physical") else { return false }
        guard negative.allSatisfy({ !tokens.contains($0) }) else { return false }
        return blocked.allSatisfy { !tokens.contains($0) }
    }

    static func parentDiskTags(from listOutput: String) -> [String: String] {
        var tags: [String: String] = [:]
        for line in listOutput.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            guard let match = line.range(of: #"^/dev/(disk\d+)\s*\(([^)]*)\)"#, options: .regularExpression) else { continue }
            let body = String(line[match])
            if let disk = body.split(separator: " ").first?.replacingOccurrences(of: "/dev/", with: ""),
               let open = body.firstIndex(of: "("),
               let close = body.firstIndex(of: ")") {
                tags[disk] = String(body[body.index(after: open)..<close])
            }
        }
        return tags
    }

    static func dataPartition(fromListOutput listOutput: String, parent: String) -> String? {
        guard isWholeDisk(parent),
              canFormat(fromListTags: parentDiskTags(from: listOutput)[parentDiskId(parent)]) else { return nil }
        return listOutput.split(whereSeparator: \.isNewline).map(String.init).reversed().first { line in
            guard line.range(
                of: #"\b(Microsoft Basic Data|ExFAT|Windows_NTFS|x?NTFS)\b"#,
                options: [.regularExpression, .caseInsensitive]
            ) != nil,
                  let match = line.range(of: #"disk\d+s\d+"#, options: .regularExpression) else { return false }
            return parentDiskPath("/dev/\(line[match])") == parent
        }.flatMap { line in
            guard let match = line.range(of: #"disk\d+s\d+"#, options: .regularExpression) else { return nil }
            return "/dev/\(line[match])"
        }
    }

    static func isSafeMountPoint(_ path: String) -> Bool {
        guard path.hasPrefix("/Volumes/"),
              path != "/Volumes/",
              !path.contains("\0"),
              !path.contains("//") else { return false }
        let name = String(path.dropFirst("/Volumes/".count))
        guard !name.isEmpty, !name.contains("/") else { return false }
        guard URL(fileURLWithPath: path).standardizedFileURL.path == path else { return false }
        return !containsSymlink(at: "/Volumes") && !containsSymlink(at: path)
    }

    static func sanitizeVolumeName(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: #"[\\/:*?"<>|]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty || cleaned == "." || cleaned == ".." || cleaned.rangeOfCharacter(from: .controlCharacters) != nil {
            return "NTFS"
        }
        return String(cleaned.prefix(32))
    }

    static func field(_ info: String, _ name: String) -> String? {
        let pattern = #"^\s*"# + NSRegularExpression.escapedPattern(for: name) + #":\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines, .caseInsensitive]) else {
            return nil
        }
        let range = NSRange(info.startIndex..., in: info)
        guard let match = regex.firstMatch(in: info, range: range),
              let value = Range(match.range(at: 1), in: info) else { return nil }
        return String(info[value]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isExternalFormattable(parentInfo: String, bootWholeDiskId: String, parentDiskId: String) -> Bool {
        guard !parentDiskId.isEmpty,
              !bootWholeDiskId.isEmpty,
              parentDiskId != bootWholeDiskId,
              isWholeDisk("/dev/\(parentDiskId)") else { return false }
        guard let identifier = field(parentInfo, "Device Identifier"),
              DiskSafety.parentDiskId(identifier) == parentDiskId,
              field(parentInfo, "Whole")?.caseInsensitiveCompare("Yes") == .orderedSame,
              field(parentInfo, "Internal")?.caseInsensitiveCompare("No") == .orderedSame,
              field(parentInfo, "Device Location")?.caseInsensitiveCompare("External") == .orderedSame,
              field(parentInfo, "Virtual")?.caseInsensitiveCompare("No") == .orderedSame,
              let protocolName = field(parentInfo, "Protocol"),
              !protocolName.isEmpty else { return false }
        return !protocolName.localizedCaseInsensitiveContains("disk image")
            && !protocolName.localizedCaseInsensitiveContains("synthesized")
            && !protocolName.localizedCaseInsensitiveContains("unknown")
    }

    private static func containsSymlink(at path: String) -> Bool {
        var info = stat()
        guard lstat(path, &info) == 0 else { return errno != ENOENT }
        return (info.st_mode & S_IFMT) == S_IFLNK
    }
}
