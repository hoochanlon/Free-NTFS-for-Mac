import Foundation

enum DeviceScanner {
    static func scan() async -> [NTFSDevice] {
        async let mountTask = Shell.runQuiet("/sbin/mount", timeout: 2)
        async let listTask = Shell.runQuiet("/usr/sbin/diskutil", ["list"], timeout: 3)
        let mountOut = await mountTask.stdout
        let listOut = await listTask.stdout
        let tags = DiskSafety.parentDiskTags(from: listOut)
        let mounts = MountTable.parse(mountOut)

        var devices: [NTFSDevice] = []
        var seen = Set<String>()

        // 1) 挂载表优先：已挂载事实决定列表与读写状态
        for mounted in mounts {
            guard let device = await deviceFromMount(mounted, mountOut: mountOut, tags: tags) else { continue }
            seen.insert(device.devicePath)
            devices.append(device)
        }

        // 2) diskutil list 补未挂载的 NTFS 分区
        var currentDisk = ""
        for line in listOut.split(whereSeparator: \.isNewline).map(String.init) {
            if let match = line.range(of: #"^/dev/(disk\d+)"#, options: .regularExpression) {
                currentDisk = String(line[match]).replacingOccurrences(of: "/dev/", with: "")
                continue
            }
            guard DiskSafety.isNTFSFilesystem(line), !currentDisk.isEmpty else { continue }
            guard let part = line.range(of: #"disk\d+s\d+"#, options: .regularExpression) else { continue }
            let partition = String(line[part])
            let path = "/dev/\(partition)"
            if seen.contains(path) { continue }
            seen.insert(path)
            if let extra = await infoDevice(path: path, disk: partition, tags: tags) {
                devices.append(extra)
            }
        }

        var filled: [NTFSDevice] = []
        for var device in devices {
            if device.volumeUuid == nil {
                device.volumeUuid = await volumeUuid(device.devicePath)
            }
            if device.capacity == nil {
                device.capacity = await capacity(volume: device.volume, devicePath: device.devicePath)
            }
            filled.append(device)
        }
        return filled.sorted { $0.disk < $1.disk }
    }

    /// 将一条挂载记录转成 NTFS 设备；非 NTFS / 未确认的 fuse 返回 nil。
    private static func deviceFromMount(
        _ mounted: MountedVolume,
        mountOut: String,
        tags: [String: String]
    ) async -> NTFSDevice? {
        if DiskSafety.isFuseDriver(mounted.driver) {
            let info = await Shell.runQuiet("/usr/sbin/diskutil", ["info", mounted.devicePath], timeout: 1.5).stdout
            guard DiskSafety.isConfirmedNTFSFuseMount(
                mountOut,
                deviceInfo: info,
                devicePath: mounted.devicePath,
                mountPoint: mounted.mountPoint
            ) else { return nil }
        } else {
            // 原生挂载：仅放行 xntfs / ntfs 明确类型
            let mountLine = "\(mounted.devicePath) on \(mounted.mountPoint) (\(mounted.options.joined(separator: ", ")))"
            let nativeNTFS = DiskSafety.isNTFSFilesystem(mountLine)
                || mounted.driver.lowercased().contains("ntfs")
                || DiskSafety.isMountedXNTFSFilesystem(
                    mountOut,
                    devicePath: mounted.devicePath,
                    mountPoint: mounted.mountPoint
                )
            guard nativeNTFS else { return nil }
        }

        return NTFSDevice(
            disk: mounted.disk,
            devicePath: mounted.devicePath,
            volume: mounted.mountPoint,
            volumeName: mounted.volumeName,
            volumeUuid: nil,
            // 只读状态只认内核挂载选项，禁止用探测结果覆盖
            isReadOnly: mounted.isReadOnly,
            options: mounted.options.joined(separator: ", "),
            isMounted: true,
            isUnmounted: false,
            canFormat: DiskSafety.canFormat(fromListTags: tags[DiskSafety.parentDiskId(mounted.disk)]),
            capacity: nil
        )
    }

    private static func infoDevice(path: String, disk: String, tags: [String: String]) async -> NTFSDevice? {
        let info = await Shell.runQuiet("/usr/sbin/diskutil", ["info", path], timeout: 1.5).stdout
        guard DiskSafety.isNTFSFilesystem(info) || DiskSafety.isNTFSVolumeInfo(info) else { return nil }
        let name = DiskSafety.field(info, "Volume Name") ?? disk
        let mount = DiskSafety.field(info, "Mount Point") ?? ""
        let mounted = !mount.isEmpty && mount != "Not applicable" && mount != "none"
        let uuid = DiskSafety.field(info, "Volume UUID")
            ?? DiskSafety.field(info, "Disk / Partition UUID")
            ?? DiskSafety.field(info, "Partition UUID")
        // 未走挂载表的路径：系统原生挂载按只读处理；未挂载也标只读待用户选择
        return NTFSDevice(
            disk: disk,
            devicePath: path,
            volume: mounted ? mount : "",
            volumeName: name,
            volumeUuid: uuid,
            isReadOnly: true,
            options: "",
            isMounted: mounted,
            isUnmounted: !mounted,
            canFormat: DiskSafety.canFormat(fromListTags: tags[DiskSafety.parentDiskId(disk)]),
            capacity: nil
        )
    }

    private static func volumeUuid(_ path: String) async -> String? {
        let info = await Shell.runQuiet("/usr/sbin/diskutil", ["info", path], timeout: 1.2).stdout
        return DiskSafety.field(info, "Volume UUID")
            ?? DiskSafety.field(info, "Disk / Partition UUID")
            ?? DiskSafety.field(info, "Partition UUID")
    }

    private static func capacity(volume: String, devicePath: String) async -> Capacity? {
        if !volume.isEmpty, let fromDf = await dfCapacity(volume) { return fromDf }
        return await diskutilCapacity(devicePath)
    }

    private static func dfCapacity(_ volume: String) async -> Capacity? {
        let result = await Shell.runQuiet("/bin/df", ["-k", volume], timeout: 1.5)
        let lines = result.stdout.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count >= 2 else { return nil }
        let data = lines.reversed().first { $0.contains("/dev/") || $0.contains(volume) } ?? lines.last ?? ""
        let parts = data.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count >= 4, let total = Int64(parts[1]), let used = Int64(parts[2]), let avail = Int64(parts[3]), total > 0 else {
            return nil
        }
        return Capacity(total: total * 1024, used: used * 1024, available: avail * 1024)
    }

    private static func diskutilCapacity(_ path: String) async -> Capacity? {
        let info = await Shell.runQuiet("/usr/sbin/diskutil", ["info", path], timeout: 1.5).stdout
        func bytes(_ label: String) -> Int64? {
            let pattern = label + #"\s*[\d.]+ [KMGT]?B\s*\((\d+)\s+Bytes\)"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
            let range = NSRange(info.startIndex..., in: info)
            guard let match = regex.firstMatch(in: info, range: range),
                  let capture = Range(match.range(at: 1), in: info) else { return nil }
            return Int64(info[capture])
        }
        guard let total = bytes("Total Size:") ?? bytes("Disk Size:") else { return nil }
        var used = bytes("Volume Used Space:") ?? 0
        var available = bytes("Volume Free Space:") ?? 0
        if available > 0 && used == 0 { used = total - available }
        if used > 0 && available == 0 { available = total - used }
        if used == 0 && available == 0 { available = total }
        return Capacity(total: total, used: max(0, used), available: max(0, available))
    }
}
