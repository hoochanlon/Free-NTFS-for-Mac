import Foundation
import NigateFSKitCore

@MainActor
struct MountService {
    let backend: NigateMountBackend
    var askPassword: (String, [String: String]) async throws -> String

    func mount(_ device: NTFSDevice, passwordOverride: String? = nil) async throws -> String {
        try validateBackend()
        try await assertNTFSPartition(device)
        switch backend {
        case .fsKit:
            // 控制面接通后只走 FSKit 数据面；失败即失败，绝不静默切 ntfs-3g。
            return try await mountWithFSKit(device, passwordOverride: passwordOverride, readOnly: false)
        case .ntfs3gCompatibility:
            return try await mountWithNTFS3G(device, passwordOverride: passwordOverride)
        }
    }

    private func mountWithFSKit(
        _ device: NTFSDevice,
        passwordOverride: String?,
        readOnly: Bool
    ) async throws -> String {
        var password: String
        if let passwordOverride {
            password = passwordOverride
        } else {
            password = try await askPassword("messages.passwordDialog.mountDevice", ["name": device.volumeName])
        }
        let message = try await FSKitMountService.mount(
            device: device,
            readOnly: readOnly,
            run: { args, password, refreshKey, name, timeout in
                try await self.run(args, password: &password, refreshKey: refreshKey, name: name, timeout: timeout)
            },
            password: &password
        )
        writeMarker(device.disk)
        return message
    }

    private func mountWithNTFS3G(_ device: NTFSDevice, passwordOverride: String?) async throws -> String {
        guard let raw = await PathLookup.ntfs3g() else { throw AppError.ntfs3gMissing }
        let ntfs3g = try PathLookup.resolvedNTFS3G(raw)
        let mountPoint = device.volume.isEmpty
            ? "/Volumes/\(DiskSafety.sanitizeVolumeName(device.volumeName))"
            : device.volume
        guard DiskSafety.isSafeMountPoint(mountPoint) else {
            throw AppError.invalidPath
        }
        var password: String
        if let passwordOverride {
            password = passwordOverride
        } else {
            password = try await askPassword("messages.passwordDialog.mountDevice", ["name": device.volumeName])
        }
        if device.isMounted && !device.isUnmounted {
            _ = try await run(["umount", "-f", device.devicePath], password: &password, refreshKey: "messages.passwordDialog.mountDevice", name: device.volumeName)
        }
        clearMarker(device.disk)
        _ = try await run(["mkdir", "-p", mountPoint], password: &password, refreshKey: "messages.passwordDialog.mountDevice", name: device.volumeName)

        let uid = getuid()
        let gid = getgid()
        let args = [
            ntfs3g, "-olocal", "-oallow_other", "-oauto_xattr",
            "-ouid=\(uid)", "-ogid=\(gid)", "-ovolname=\(device.volumeName)",
            "-onoatime", device.devicePath, mountPoint
        ]
        do {
            _ = try await run(args, password: &password, refreshKey: "messages.passwordDialog.mountDeviceRetry", name: device.volumeName, timeout: 10)
        } catch AppError.timeout(_) {
            throw AppError.timeout("挂载操作超时（10秒），操作已取消以防止卡死。可能的原因：1) 文件系统处于脏状态（如果该 NTFS 设备之前在 Windows 电脑上使用过，且 Windows 启用了快速启动功能，请将设备插回 Windows 电脑并完全关闭后再试）；2) 设备被其他程序占用；3) 系统权限问题。")
        }
        writeMarker(device.disk)
        return "设备 \(device.volumeName) 已成功挂载为读写模式"
    }

    func unmount(_ device: NTFSDevice) async throws -> String {
        try validateBackend()
        try await assertNTFSPartition(device)
        var password = try await askPassword("messages.passwordDialog.unmountDevice", ["name": device.volumeName])
        switch backend {
        case .fsKit:
            try await FSKitMountService.unmount(
                device: device,
                run: { args, password, refreshKey, name, timeout in
                    try await self.run(args, password: &password, refreshKey: refreshKey, name: name, timeout: timeout)
                },
                password: &password
            )
        case .ntfs3gCompatibility:
            do {
                _ = try await run(["umount", "-f", device.devicePath], password: &password, refreshKey: "messages.passwordDialog.unmountDevice", name: device.volumeName)
            } catch {
                let fallback = await Shell.runQuiet("/usr/sbin/diskutil", ["unmount", "force", device.devicePath], timeout: 8)
                if !fallback.ok { throw AppError.failed("卸载失败: \(error.localizedDescription)") }
            }
        }
        clearMarker(device.disk)
        return "设备 \(device.volumeName) 已卸载"
    }

    func restore(_ device: NTFSDevice) async throws -> String {
        try validateBackend()
        try await assertNTFSPartition(device)
        var password = try await askPassword("messages.passwordDialog.restoreToReadOnly", ["name": device.volumeName])
        do {
            _ = try await run(["umount", "-f", device.devicePath], password: &password, refreshKey: "messages.passwordDialog.restoreToReadOnly", name: device.volumeName)
        } catch {
            let fallback = await Shell.runQuiet("/usr/sbin/diskutil", ["unmount", "force", device.devicePath], timeout: 8)
            guard fallback.ok else { throw AppError.failed("卸载失败，无法还原只读模式: \(error.localizedDescription)") }
        }
        clearMarker(device.disk)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        switch backend {
        case .fsKit:
            // FSKit 默认可写；还原只读必须显式 rdonly，不能走无选项 mount。
            _ = try await FSKitMountService.mount(
                device: unmounted(device),
                readOnly: true,
                run: { args, password, refreshKey, name, timeout in
                    try await self.run(args, password: &password, refreshKey: refreshKey, name: name, timeout: timeout)
                },
                password: &password
            )
        case .ntfs3gCompatibility:
            try await mountReadOnly(device.devicePath, password: &password, refreshKey: "messages.passwordDialog.restoreToReadOnly", name: device.volumeName)
        }
        return "设备 \(device.volumeName) 已还原为只读模式"
    }

    func eject(_ device: NTFSDevice) async throws -> String {
        try validateBackend()
        try await assertNTFSPartition(device)
        let result = await Shell.runQuiet("/usr/sbin/diskutil", ["eject", device.devicePath], timeout: 12)
        if !result.ok { throw AppError.failed("推出设备失败: \(result.text)") }
        clearMarker(device.disk)
        return "设备 \(device.volumeName) 已推出，可以安全拔出"
    }

    func reset(_ device: NTFSDevice) async throws -> String {
        try requireCompatibilityBackend()
        try await assertNTFSPartition(device)
        guard DiskSafety.isPartition(device.devicePath) else { throw AppError.coded("REPAIR_INVALID_PATH") }
        let ntfsfix = try await ntfsfixPath()
        var password = try await askPassword("messages.passwordDialog.resetDevice", ["name": device.volumeName])
        _ = try await run(["diskutil", "unmount", device.devicePath], password: &password, refreshKey: "messages.passwordDialog.resetDevice", name: device.volumeName)
        clearMarker(device.disk)
        try await Task.sleep(nanoseconds: 500_000_000)
        _ = try await run([ntfsfix, device.devicePath], password: &password, refreshKey: "messages.passwordDialog.resetDevice", name: device.volumeName)
        try await Task.sleep(nanoseconds: 500_000_000)
        try await mountReadOnly(device.devicePath, password: &password, refreshKey: "messages.passwordDialog.resetDevice", name: device.volumeName)
        return "设备 \(device.volumeName) 已重置并重新挂载为只读模式"
    }

    func repair(_ device: NTFSDevice) async throws -> String {
        try requireCompatibilityBackend()
        try await assertNTFSPartition(device)
        guard DiskSafety.isPartition(device.devicePath) else { throw AppError.coded("REPAIR_INVALID_PATH") }
        let ntfsfix = try await ntfsfixPath()
        let wasReadOnly = device.isReadOnly
        var password = try await askPassword("messages.passwordDialog.repairDevice", ["name": device.volumeName])
        do {
            _ = try await run(["diskutil", "unmount", device.devicePath], password: &password, refreshKey: "messages.passwordDialog.repairDevice", name: device.volumeName)
        } catch {
            throw AppError.coded("REPAIR_UNMOUNT_FAILED:\(error.localizedDescription)")
        }
        clearMarker(device.disk)
        try await Task.sleep(nanoseconds: 500_000_000)
        do {
            _ = try await run([ntfsfix, device.devicePath], password: &password, refreshKey: "messages.passwordDialog.repairDevice", name: device.volumeName)
        } catch {
            throw AppError.coded("REPAIR_FILESYSTEM_FAILED:\(error.localizedDescription)")
        }
        try await Task.sleep(nanoseconds: 500_000_000)
        do {
            if wasReadOnly {
                try await mountReadOnly(device.devicePath, password: &password, refreshKey: "messages.passwordDialog.repairDevice", name: device.volumeName)
            } else {
                _ = try await mount(unmounted(device), passwordOverride: password)
            }
        } catch {
            throw AppError.coded("REPAIR_REMOUNT_FAILED:\(error.localizedDescription)")
        }
        return "设备 \(device.volumeName) 的 NTFS 文件系统已修复并恢复原挂载模式"
    }

    func rename(_ device: NTFSDevice, to newName: String) async throws -> String {
        try requireCompatibilityBackend()
        try await assertNTFSPartition(device)
        guard DiskSafety.isPartition(device.devicePath) else { throw AppError.coded("RENAME_INVALID_PATH") }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.count > 32 || trimmed.range(of: #"[\\/:*?"<>|]"#, options: .regularExpression) != nil || trimmed.rangeOfCharacter(from: .controlCharacters) != nil {
            throw AppError.coded("RENAME_INVALID_NAME")
        }
        let newVolume = "/Volumes/\(trimmed)"
        guard DiskSafety.isSafeMountPoint(newVolume) else {
            throw AppError.coded("RENAME_INVALID_NAME")
        }
        guard let ntfslabel = PathLookup.sibling(of: await PathLookup.ntfs3g(), named: "ntfslabel") else {
            throw AppError.coded("RENAME_TOOL_MISSING")
        }
        let wasReadOnly = device.isReadOnly
        var password = try await askPassword("messages.passwordDialog.renameDevice", ["name": device.volumeName])
        do {
            _ = try await run(["diskutil", "unmount", device.devicePath], password: &password, refreshKey: "messages.passwordDialog.renameDevice", name: device.volumeName)
        } catch {
            throw AppError.coded("RENAME_UNMOUNT_FAILED:\(error.localizedDescription)")
        }
        clearMarker(device.disk)
        try await Task.sleep(nanoseconds: 500_000_000)
        do {
            _ = try await run([ntfslabel, device.devicePath, trimmed], password: &password, refreshKey: "messages.passwordDialog.renameDevice", name: device.volumeName)
        } catch {
            throw AppError.coded("RENAME_LABEL_FAILED:\(error.localizedDescription)")
        }
        try await refreshGPTName(device, newName: trimmed, password: &password)
        try await Task.sleep(nanoseconds: 500_000_000)
        do {
            if wasReadOnly {
                try await mountReadOnly(device.devicePath, password: &password, refreshKey: "messages.passwordDialog.renameDevice", name: device.volumeName)
            } else {
                var next = unmounted(device)
                next.volumeName = trimmed
                next.volume = newVolume
                _ = try await mount(next, passwordOverride: password)
            }
        } catch {
            throw AppError.coded("RENAME_REMOUNT_FAILED:\(error.localizedDescription)")
        }
        if device.volume.hasPrefix("/Volumes/"), device.volume != newVolume,
           DiskSafety.isSafeMountPoint(device.volume),
           FileManager.default.fileExists(atPath: device.volume) {
            _ = try? await run(["rmdir", device.volume], password: &password, refreshKey: "messages.passwordDialog.renameDevice", name: device.volumeName)
        }
        return "设备卷标已从 \(device.volumeName) 更新为 \(trimmed)"
    }

    func format(_ device: NTFSDevice) async throws -> String {
        try requireCompatibilityBackend()
        try await assertNTFSPartition(device)
        guard DiskSafety.isPartition(device.devicePath),
              device.volumeUuid?.isEmpty == false,
              device.canFormat else { throw AppError.formatNotAllowed }
        let parent = DiskSafety.parentDiskPath(device.devicePath)
        guard DiskSafety.isWholeDisk(parent) else { throw AppError.formatNotAllowed }
        try await assertFormattable(parent, partition: device)
        guard let mkntfs = PathLookup.sibling(of: await PathLookup.ntfs3g(), named: "mkntfs") else {
            throw AppError.coded("FORMAT_TOOL_MISSING")
        }
        let volumeName = DiskSafety.sanitizeVolumeName(device.volumeName)
        var password = try await askPassword("messages.passwordDialog.formatDevice", ["name": volumeName])

        // The password sheet can remain open while a disk is removed or reassigned. Recheck the destructive target immediately before eraseDisk.
        try await assertNTFSPartition(device)
        try await assertFormattable(parent, partition: device)
        do {
            _ = try await run(["diskutil", "eraseDisk", "ExFAT", volumeName, "GPT", parent], password: &password, refreshKey: "messages.passwordDialog.formatDevice", name: volumeName, timeout: 120)
        } catch {
            throw AppError.coded("FORMAT_ERASE_FAILED:\(error.localizedDescription)")
        }
        clearMarker(device.disk)
        try await Task.sleep(nanoseconds: 500_000_000)
        do {
            _ = try await run(["diskutil", "unmountDisk", "force", parent], password: &password, refreshKey: "messages.passwordDialog.formatDevice", name: volumeName)
        } catch {
            await bestEffortUnmountDisk(parent)
            throw AppError.coded("FORMAT_UNMOUNT_FAILED:\(error.localizedDescription)")
        }
        try await Task.sleep(nanoseconds: 500_000_000)
        guard let dataPath = await gptDataPartition(parent) else {
            await bestEffortUnmountDisk(parent)
            throw AppError.failed("无法确认新建的 NTFS 数据分区，已停止格式化以避免写入错误设备")
        }
        do {
            try await assertPostEraseTarget(parent: parent, dataPath: dataPath)
            _ = try await run([mkntfs, "-Q", "-L", volumeName, dataPath], password: &password, refreshKey: "messages.passwordDialog.formatDevice", name: volumeName, timeout: 120)
        } catch {
            await bestEffortUnmountDisk(parent)
            throw AppError.coded("FORMAT_MKNTFS_FAILED:\(error.localizedDescription)")
        }
        try await Task.sleep(nanoseconds: 500_000_000)
        let remount = await Shell.runQuiet("/usr/sbin/diskutil", ["mountDisk", parent], timeout: 12)
        if !remount.ok {
            await bestEffortUnmountDisk(parent)
            throw AppError.coded("FORMAT_REMOUNT_FAILED:\(remount.text)")
        }
        return "设备 \(volumeName) 已格式化为 GPT NTFS"
    }

    private func validateBackend() throws {
        do {
            try MountBackendPolicy.validate(
                backend,
                systemVersion: NigateSystemVersion(ProcessInfo.processInfo.operatingSystemVersion),
                isFSKitControlPlaneAvailable: MountBackendPolicy.isControlPlaneAvailable
            )
        } catch let error as MountBackendPolicyError {
            switch error {
            case .fsKitRequiresMacOS15_4:
                throw AppError.fsKitRequiresMacOS15_4
            case .fsKitControlPlaneUnavailable:
                throw AppError.fsKitUnavailable
            case .compatibilityBackendNotSelected:
                throw AppError.ntfs3gCompatibilityNotSelected
            }
        }
    }

    private func requireCompatibilityBackend() throws {
        try validateBackend()
        guard backend == .ntfs3gCompatibility else {
            throw AppError.ntfs3gCompatibilityNotSelected
        }
    }

    private func unmounted(_ device: NTFSDevice) -> NTFSDevice {
        var next = device
        next.isMounted = false
        next.isUnmounted = true
        return next
    }

    /// 系统原生只读挂载。FSKit/xntfs 默认 RW，必须带 readOnly。
    private func mountReadOnly(
        _ devicePath: String,
        password: inout String,
        refreshKey: String,
        name: String
    ) async throws {
        do {
            _ = try await run(
                ["diskutil", "mount", "readOnly", devicePath],
                password: &password,
                refreshKey: refreshKey,
                name: name
            )
        } catch {
            // 无密码路径的兜底（restore 原先用 runQuiet）
            let fallback = await Shell.runQuiet(
                "/usr/sbin/diskutil",
                ["mount", "readOnly", devicePath],
                timeout: 8
            )
            guard fallback.ok else {
                throw AppError.failed("还原只读挂载失败: \(fallback.text.isEmpty ? error.localizedDescription : fallback.text)")
            }
        }
        try await assertMountedReadOnly(devicePath)
    }

    /// 确认内核挂载表已带 read-only，避免“看似成功、实际仍可写”。
    private func assertMountedReadOnly(_ devicePath: String) async throws {
        let mounts = await Shell.runQuiet("/sbin/mount", timeout: 3)
        guard mounts.ok,
              let volume = MountTable.parse(mounts.stdout).first(where: { $0.devicePath == devicePath }),
              volume.isReadOnly else {
            throw AppError.failed("系统已挂载但未进入只读模式（可能被 FSKit 以读写挂上），操作已停止")
        }
    }

    private func run(
        _ args: [String],
        password: inout String,
        refreshKey: String,
        name: String,
        timeout: TimeInterval = 30
    ) async throws -> ShellResult {
        do {
            return try await Privilege.sudo(args, password: password, timeout: timeout)
        } catch AppError.incorrectPassword {
            KeychainStore.delete()
            password = try await askPassword(refreshKey, ["name": name])
            return try await Privilege.sudo(args, password: password, timeout: timeout)
        }
    }

    private func ntfsfixPath() async throws -> String {
        if let path = PathLookup.sibling(of: await PathLookup.ntfs3g(), named: "ntfsfix") { return path }
        throw AppError.missingTool("ntfsfix not found. Install ntfs-3g-mac before repairing an NTFS volume.")
    }

    private func refreshGPTName(_ device: NTFSDevice, newName: String, password: inout String) async throws {
        let parent = DiskSafety.parentDiskPath(device.devicePath)
        guard parent != device.devicePath else { return }
        _ = try await run(["diskutil", "unmountDisk", "force", parent], password: &password, refreshKey: "messages.passwordDialog.renameDevice", name: device.volumeName)
        guard let index = DiskSafety.partitionIndex(device.disk) else {
            throw AppError.coded("RENAME_PARTITION_INDEX_FAILED")
        }
        let raw = parent.replacingOccurrences(of: "/dev/disk", with: "/dev/rdisk")
        _ = try await run(["gpt", "label", "-f", "-i", index, "-l", newName, raw], password: &password, refreshKey: "messages.passwordDialog.renameDevice", name: device.volumeName)
    }

    private func assertNTFSPartition(_ device: NTFSDevice) async throws {
        guard DiskSafety.isPartition(device.devicePath),
              device.devicePath == "/dev/\(device.disk)" else {
            throw AppError.invalidPath
        }
        let result = await Shell.runQuiet("/usr/sbin/diskutil", ["info", device.devicePath], timeout: 5)
        guard result.ok,
              let identifier = DiskSafety.field(result.stdout, "Device Identifier"),
              identifier == device.disk else {
            throw AppError.failed("设备信息已变化或不是 NTFS 分区，操作已停止")
        }
        // diskutil 字段命中 NTFS（含 Partition Type，即使 personality 误报）
        if DiskSafety.isNTFSFilesystem(result.stdout) || DiskSafety.isNTFSVolumeInfo(result.stdout) {
            return
        }

        guard DiskSafety.field(result.stdout, "Mounted")?.caseInsensitiveCompare("Yes") == .orderedSame,
              let mountPoint = DiskSafety.field(result.stdout, "Mount Point"),
              !mountPoint.isEmpty,
              mountPoint != "Not applicable",
              mountPoint != "none" else {
            throw AppError.failed("设备信息已变化或不是 NTFS 分区，操作已停止")
        }
        let mounts = await Shell.runQuiet("/sbin/mount", timeout: 3)
        guard mounts.ok else {
            throw AppError.failed("设备信息已变化或不是 NTFS 分区，操作已停止")
        }
        // 原生 xntfs，或已确认的 macfuse/ntfs-3g 挂载事实
        if DiskSafety.isMountedXNTFSFilesystem(
            mounts.stdout,
            devicePath: device.devicePath,
            mountPoint: mountPoint
        ) || DiskSafety.isConfirmedNTFSFuseMount(
            mounts.stdout,
            deviceInfo: result.stdout,
            devicePath: device.devicePath,
            mountPoint: mountPoint
        ) {
            return
        }
        throw AppError.failed("设备信息已变化或不是 NTFS 分区，操作已停止")
    }

    private func assertFormattable(_ parent: String, partition: NTFSDevice) async throws {
        let parentResult = await Shell.runQuiet("/usr/sbin/diskutil", ["info", parent], timeout: 5)
        let partitionResult = await Shell.runQuiet("/usr/sbin/diskutil", ["info", partition.devicePath], timeout: 5)
        let bootResult = await Shell.runQuiet("/usr/sbin/diskutil", ["info", "/"], timeout: 5)
        let listResult = await Shell.runQuiet("/usr/sbin/diskutil", ["list", parent], timeout: 5)
        guard parentResult.ok, partitionResult.ok, bootResult.ok, listResult.ok,
              !parentResult.stdout.isEmpty, !partitionResult.stdout.isEmpty, !bootResult.stdout.isEmpty,
              let partitionUUID = partition.volumeUuid, !partitionUUID.isEmpty,
              DiskSafety.field(partitionResult.stdout, "Device Identifier") == partition.disk,
              (DiskSafety.field(partitionResult.stdout, "Volume UUID")
               ?? DiskSafety.field(partitionResult.stdout, "Disk / Partition UUID")
               ?? DiskSafety.field(partitionResult.stdout, "Partition UUID")) == partitionUUID,
              DiskSafety.canFormat(fromListTags: DiskSafety.parentDiskTags(from: listResult.stdout)[DiskSafety.parentDiskId(parent)]) else {
            throw AppError.formatNotAllowed
        }
        let bootId = DiskSafety.parentDiskId(DiskSafety.field(bootResult.stdout, "Device Identifier") ?? "")
        guard DiskSafety.isExternalFormattable(
            parentInfo: parentResult.stdout,
            bootWholeDiskId: bootId,
            parentDiskId: DiskSafety.parentDiskId(parent)
        ) else {
            throw AppError.formatNotAllowed
        }
    }

    private func assertPostEraseTarget(parent: String, dataPath: String) async throws {
        guard DiskSafety.isWholeDisk(parent),
              DiskSafety.isPartition(dataPath),
              DiskSafety.parentDiskPath(dataPath) == parent else {
            throw AppError.formatNotAllowed
        }
        let parentInfo = await Shell.runQuiet("/usr/sbin/diskutil", ["info", parent], timeout: 5)
        let dataInfo = await Shell.runQuiet("/usr/sbin/diskutil", ["info", dataPath], timeout: 5)
        let bootInfo = await Shell.runQuiet("/usr/sbin/diskutil", ["info", "/"], timeout: 5)
        let list = await Shell.runQuiet("/usr/sbin/diskutil", ["list", parent], timeout: 5)
        let parentID = DiskSafety.parentDiskId(parent)
        let dataID = dataPath.replacingOccurrences(of: "/dev/", with: "")
        let bootID = DiskSafety.parentDiskId(DiskSafety.field(bootInfo.stdout, "Device Identifier") ?? "")
        guard parentInfo.ok, dataInfo.ok, bootInfo.ok, list.ok,
              DiskSafety.canFormat(fromListTags: DiskSafety.parentDiskTags(from: list.stdout)[parentID]),
              DiskSafety.isExternalFormattable(parentInfo: parentInfo.stdout, bootWholeDiskId: bootID, parentDiskId: parentID),
              DiskSafety.field(dataInfo.stdout, "Device Identifier") == dataID,
              DiskSafety.field(dataInfo.stdout, "Whole")?.caseInsensitiveCompare("No") == .orderedSame,
              dataInfo.stdout.localizedCaseInsensitiveContains("exfat") else {
            throw AppError.formatNotAllowed
        }
    }

    private func bestEffortUnmountDisk(_ parent: String) async {
        guard DiskSafety.isWholeDisk(parent) else { return }
        _ = await Shell.runQuiet("/usr/sbin/diskutil", ["unmountDisk", "force", parent], timeout: 8)
    }

    private func gptDataPartition(_ parent: String) async -> String? {
        let result = await Shell.runQuiet("/usr/sbin/diskutil", ["list", parent], timeout: 5)
        guard result.ok else { return nil }
        return DiskSafety.dataPartition(fromListOutput: result.stdout, parent: parent)
    }

    private func writeMarker(_ disk: String) {
        FileManager.default.createFile(atPath: "/tmp/ntfs_mounted_\(disk)", contents: Data())
    }

    private func clearMarker(_ disk: String) {
        try? FileManager.default.removeItem(atPath: "/tmp/ntfs_mounted_\(disk)")
    }
}
