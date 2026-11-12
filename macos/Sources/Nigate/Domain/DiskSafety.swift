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
            #"(?im)^\s*(?:File System Personality|File System Type|Type \(Bundle\)|Format|格式):\s*(?:(?:xntfs|ntfs(?:-[\w-]+)?)(?:\s+\(macfuse\))?|(?:Unknown|未知)\s+\((?:xntfs|ntfs(?:-[\w-]+)?)\))\s*$"#,
            #"(?im)^\s*\d+:\s*(?:xntfs|ntfs(?:-[\w-]+)?)\b"#,
            #"(?im)^/dev/disk\d+s\d+\s+on\s+/Volumes/.*\s+\((?:xntfs|ntfs(?:-[\w-]+)?)\b[^)]*\)\s*$"#
        ]
        return patterns.contains { pattern in
            description.range(of: pattern, options: .regularExpression) != nil
        }
    }

    /// diskutil 卷身份：只读取实际文件系统字段，不能用分区类型推断。
    /// `Microsoft Basic Data` / `Windows_NTFS` 只描述分区表类型，不能证明卷内是 NTFS。
    static func isNTFSVolumeInfo(_ info: String) -> Bool {
        let identityFields = [
            "File System Personality",
            "File System Type",
            "Type (Bundle)",
            "FilesystemType",
            "FilesystemName",
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

    /// 已挂载的 macfuse/ntfs-3g 是否明确识别为 NTFS 卷。
    ///
    /// 分区表类型和通用 FUSE 挂载选项都不具备文件系统身份，不能作为放行依据。
    /// 应用成功挂载后留下的标记属于可信来源，用于兼容 diskutil 无法识别 FUSE 文件系统的情况。
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

        // 设备当前身份明确为 NTFS 时直接放行。
        if isNTFSVolumeInfo(deviceInfo) { return true }

        // FSKit / ntfs-3g 成功挂载后写入；macOS 可能把 FUSE 卷误报为 ExFAT。
        let disk = devicePath.replacingOccurrences(of: "/dev/", with: "")
        if FileManager.default.fileExists(atPath: "/tmp/ntfs_mounted_\(disk)") {
            return true
        }

        // 无成功挂载标记时，diskutil 明确报告的其他文件系统仍应排除。
        if isKnownNonNTFSVolumeInfo(deviceInfo) { return false }

        // ntfs-3g 是明确的文件系统驱动身份，不是通用 FUSE 选项。
        return mounted.driver == "ntfs-3g" || mounted.driver.contains("ntfs")
    }

    static func isSameKnownDevice(_ known: NTFSDevice, devicePath: String, info: String) -> Bool {
        guard known.devicePath == devicePath,
              field(info, "Device Identifier") == known.disk,
              knownUUIDsMatch(known, info: info) else { return false }
        return true
    }

    static func isSameKnownVolume(_ known: NTFSDevice, devicePath: String, info: String) -> Bool {
        isSameKnownDevice(known, devicePath: devicePath, info: info)
            && !isKnownNonNTFSVolumeInfo(info)
    }

    static func canRetainUnmountedNTFSCandidate(_ known: NTFSDevice, devicePath: String, info: String) -> Bool {
        guard known.isUnmounted,
              isSameKnownDevice(known, devicePath: devicePath, info: info),
              [known.volumeUuid, known.partitionUuid].contains(where: { $0?.isEmpty == false }) else { return false }
        return hasMatchingUUID(known, info: info)
    }

    static func requiresUnmountedNTFSProbe(_ known: NTFSDevice, devicePath: String, info: String) -> Bool {
        known.isUnmounted
            && isSameKnownDevice(known, devicePath: devicePath, info: info)
            && !isNTFSVolumeInfo(info)
            && !isNTFSFilesystem(info)
    }

    static func knownUUIDsMatch(_ known: NTFSDevice, info: String) -> Bool {
        let actualVolumeUUID = field(info, "Volume UUID")
        let actualPartitionUUID = partitionUUID(in: info)
        if hasConflictingUUID(known.volumeUuid, actualVolumeUUID) { return false }
        if hasConflictingUUID(known.partitionUuid, actualPartitionUUID) { return false }
        return true
    }

    static func hasMatchingUUID(_ known: NTFSDevice, info: String) -> Bool {
        let actualVolumeUUID = field(info, "Volume UUID")
        let actualPartitionUUID = partitionUUID(in: info)
        return (known.volumeUuid == actualVolumeUUID && known.volumeUuid?.isEmpty == false)
            || (known.partitionUuid == actualPartitionUUID && known.partitionUuid?.isEmpty == false)
    }

    static func partitionUUID(in info: String) -> String? {
        field(info, "Disk / Partition UUID") ?? field(info, "Partition UUID")
    }

    private static func hasConflictingUUID(_ known: String?, _ actual: String?) -> Bool {
        guard let known, !known.isEmpty, let actual, !actual.isEmpty else { return false }
        return known != actual
    }

    /// 判断 diskutil 是否已经给出明确的非 NTFS 文件系统身份。
    ///
    /// 只读取实际文件系统身份字段，刻意忽略 `Partition Type`。
    static func isKnownNonNTFSVolumeInfo(_ info: String) -> Bool {
        let identities = [
            "exfat", "msdos", "ms-dos", "fat12", "fat16", "fat32",
            "hfs", "hfs+", "apfs", "ufs", "udf", "iso9660", "cd9660",
            "ext2", "ext3", "ext4", "btrfs", "zfs"
        ]
        let fields = [
            "File System Personality",
            "File System Type",
            "Type (Bundle)",
            "FilesystemType",
            "FilesystemName",
            "Format",
            "格式"
        ]
        return fields.compactMap { field(info, $0)?.lowercased() }
            .contains { value in identities.contains { value.contains($0) } }
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
        var id = diskOrPath.replacingOccurrences(of: "^/dev/", with: "", options: .regularExpression)
        // APFS 快照形如 disk3s3s1，需反复剥掉 sN，得到真正 whole disk id。
        while id.range(of: #"s\d+$"#, options: .regularExpression) != nil {
            id = id.replacingOccurrences(of: #"s\d+$"#, with: "", options: .regularExpression)
        }
        return id
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

    /// 是否允许整盘格式化：外接实体盘、非启动盘、非虚拟/映像。
    ///
    /// 实机注意（macOS 15+/27）：
    /// - 外接 USB 的 `diskutil info` 常**不输出** `Internal:` 字段，不能再硬性要求 Internal=No。
    /// - 启动卷可能是 APFS Snapshot（disk3s3s1），boot id 需剥多层 sN 或看 Physical Store。
    static func isExternalFormattable(parentInfo: String, bootWholeDiskId: String, parentDiskId: String) -> Bool {
        guard !parentDiskId.isEmpty,
              !bootWholeDiskId.isEmpty,
              parentDiskId != bootWholeDiskId,
              isWholeDisk("/dev/\(parentDiskId)") else { return false }
        guard let identifier = field(parentInfo, "Device Identifier"),
              DiskSafety.parentDiskId(identifier) == parentDiskId,
              field(parentInfo, "Whole")?.caseInsensitiveCompare("Yes") == .orderedSame else { return false }

        // 明确 Virtual=Yes 才拒；字段缺失不视为虚拟盘。
        if let virtual = field(parentInfo, "Virtual"),
           virtual.caseInsensitiveCompare("Yes") == .orderedSame {
            return false
        }
        // 明确 Internal=Yes 才拒；外接 USB 常无此字段。
        if let internalFlag = field(parentInfo, "Internal"),
           internalFlag.caseInsensitiveCompare("Yes") == .orderedSame {
            return false
        }

        let location = field(parentInfo, "Device Location")
        let removable = field(parentInfo, "Removable Media")
        let isExternal = location?.caseInsensitiveCompare("External") == .orderedSame
            || removable?.caseInsensitiveCompare("Removable") == .orderedSame
        guard isExternal else { return false }

        guard let protocolName = field(parentInfo, "Protocol"), !protocolName.isEmpty else { return false }
        return !protocolName.localizedCaseInsensitiveContains("disk image")
            && !protocolName.localizedCaseInsensitiveContains("synthesized")
            && !protocolName.localizedCaseInsensitiveContains("unknown")
    }

    /// 从 `diskutil info /` 解析启动盘对应的 whole-disk id（优先物理盘）。
    static func bootWholeDiskId(fromBootInfo info: String) -> String {
        let candidates = [
            field(info, "APFS Physical Store"),
            field(info, "Part of Whole"),
            field(info, "Device Identifier")
        ]
        for raw in candidates {
            let id = parentDiskId(raw ?? "")
            if !id.isEmpty { return id }
        }
        return ""
    }

    private static func containsSymlink(at path: String) -> Bool {
        var info = stat()
        guard lstat(path, &info) == 0 else { return errno != ENOENT }
        return (info.st_mode & S_IFMT) == S_IFLNK
    }
}
