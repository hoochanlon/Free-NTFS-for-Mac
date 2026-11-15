import Foundation

enum DeviceScanner {
    static func scan(knownDevices: [NTFSDevice] = []) async -> [NTFSDevice] {
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

        // 2) diskutil list 只提供候选分区；TYPE 可能把 ExFAT 也标成 Windows_NTFS，
        //    必须再用 diskutil info 的实际文件系统字段确认，不能直接相信列表行。
        var currentDisk = ""
        for rawLine in listOut.split(whereSeparator: \.isNewline).map(String.init) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if let match = line.range(of: #"^/dev/(disk\d+)"#, options: .regularExpression) {
                currentDisk = String(line[match]).replacingOccurrences(of: "/dev/", with: "")
                continue
            }
            guard !currentDisk.isEmpty,
                  let part = line.range(of: #"\bdisk\d+s\d+$"#, options: .regularExpression) else { continue }
            let partition = String(line[part])
            let path = "/dev/\(partition)"
            guard DiskSafety.isPartition(path), !seen.contains(path) else { continue }
            guard let extra = await infoDevice(
                path: path,
                disk: partition,
                tags: tags,
                knownDevice: knownDevices.first { $0.devicePath == path }
            ) else { continue }
            seen.insert(path)
            devices.append(extra)
        }

        // diskutil list can briefly omit a connected partition during unmount propagation.
        // Revalidate known devices directly; only the same confirmed volume is retained.
        for known in knownDevices where !seen.contains(known.devicePath) {
            guard DiskSafety.isPartition(known.devicePath),
                  let extra = await infoDevice(
                    path: known.devicePath,
                    disk: known.disk,
                    tags: tags,
                    knownDevice: known
                  ) else { continue }
            seen.insert(extra.devicePath)
            devices.append(extra)
        }

        var filled: [NTFSDevice] = []
        for var device in devices {
            let known = knownDevices.first { $0.devicePath == device.devicePath }
            if device.volumeUuid?.isEmpty != false || device.partitionUuid?.isEmpty != false {
                let scannedUUIDs = await volumeUUIDs(device.devicePath)
                device.volumeUuid = resolvedVolumeUUID(
                    scanned: device.volumeUuid?.isEmpty == false ? device.volumeUuid : scannedUUIDs.volume,
                    known: known?.volumeUuid
                )
                device.partitionUuid = resolvedVolumeUUID(
                    scanned: device.partitionUuid?.isEmpty == false ? device.partitionUuid : scannedUUIDs.partition,
                    known: known?.partitionUuid
                )
            }
            if device.volumeName == device.disk, let known {
                device.volumeName = known.volumeName
            }
            device.capacity = await capacity(
                volume: device.volume,
                devicePath: device.devicePath,
                previous: known?.capacity
            )
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
            partitionUuid: nil,
            // 只读状态只认内核挂载选项，禁止用探测结果覆盖
            isReadOnly: mounted.isReadOnly,
            options: mounted.options.joined(separator: ", "),
            isMounted: true,
            isUnmounted: false,
            canFormat: DiskSafety.canFormat(fromListTags: tags[DiskSafety.parentDiskId(mounted.disk)]),
            capacity: nil
        )
    }

    private static func infoDevice(
        path: String,
        disk: String,
        tags: [String: String],
        knownDevice: NTFSDevice?
    ) async -> NTFSDevice? {
        let info = await Shell.runQuiet("/usr/sbin/diskutil", ["info", path], timeout: 1.5).stdout
        let confirmedNTFS = DiskSafety.isNTFSFilesystem(info)
            || DiskSafety.isNTFSVolumeInfo(info)
            || knownDevice.map { DiskSafety.isSameKnownVolume($0, devicePath: path, info: info) } == true
            || knownDevice.map { DiskSafety.canRetainUnmountedNTFSCandidate($0, devicePath: path, info: info) } == true
        guard confirmedNTFS else { return nil }
        let name = DiskSafety.field(info, "Volume Name") ?? disk
        let mount = DiskSafety.field(info, "Mount Point") ?? ""
        let mounted = !mount.isEmpty && mount != "Not applicable" && mount != "none"
        let volumeUUID = DiskSafety.field(info, "Volume UUID")
        let partitionUUID = DiskSafety.partitionUUID(in: info)
        // 未走挂载表的路径：系统原生挂载按只读处理；未挂载也标只读待用户选择
        return NTFSDevice(
            disk: disk,
            devicePath: path,
            volume: mounted ? mount : "",
            volumeName: name,
            volumeUuid: volumeUUID,
            partitionUuid: partitionUUID,
            isReadOnly: true,
            options: "",
            isMounted: mounted,
            isUnmounted: !mounted,
            canFormat: DiskSafety.canFormat(fromListTags: tags[DiskSafety.parentDiskId(disk)]),
            capacity: nil
        )
    }

    static func resolvedVolumeUUID(scanned: String?, known: String?) -> String? {
        guard let scanned, !scanned.isEmpty else { return known }
        return scanned
    }

    private static func volumeUUIDs(_ path: String) async -> (volume: String?, partition: String?) {
        let info = await Shell.runQuiet("/usr/sbin/diskutil", ["info", path], timeout: 1.2).stdout
        return (
            volume: DiskSafety.field(info, "Volume UUID"),
            partition: DiskSafety.partitionUUID(in: info)
        )
    }

    private static func capacity(volume: String, devicePath: String, previous: Capacity?) async -> Capacity? {
        async let partitionTask = diskutilCapacity(devicePath)
        async let dfRowTask = dfRow(volume: volume)
        let partition = await partitionTask
        let df = VolumeCapacity.trustedDf(
            await dfRowTask,
            devicePath: devicePath,
            volume: volume,
            partitionTotal: partition?.total
        )
        return VolumeCapacity.resolve(df: df, partition: partition, previous: previous)
    }

    private static func dfRow(volume: String) async -> VolumeCapacity.DfRow? {
        guard !volume.isEmpty else { return nil }
        let result = await Shell.runQuiet("/bin/df", ["-Pk", volume], timeout: 1.5)
        return VolumeCapacity.parseDf(result.stdout)
    }

    private static func diskutilCapacity(_ path: String) async -> Capacity? {
        let info = await Shell.runQuiet("/usr/sbin/diskutil", ["info", path], timeout: 1.5).stdout
        return VolumeCapacity.parseDiskutil(info)
    }
}
