import Foundation

enum AutoMount {
    static func candidates(
        devices: [NTFSDevice],
        settings: AppSettings,
        attempted: Set<String>,
        cooldown: [String: Date],
        inProgress: Set<String>,
        now: Date = Date(),
        explicit: Bool
    ) -> [NTFSDevice] {
        // 自动读写是固定产品行为：扫描后把已挂载只读 NTFS 改挂为读写。
        // 仅排除本次连接的手动只读、冷却中、进行中，以及非 explicit 的已尝试项。
        return devices.filter { device in
            let leftover = isNameCollisionLeftover(device, among: devices)
            guard leftover || (device.isMounted && device.isReadOnly && !device.isUnmounted) else { return false }
            // 用户明确还原只读后，绝不能再被自动改挂为读写
            if isManuallyReadOnly(device, settings: settings) { return false }
            let id = device.identity
            if (cooldown[id] ?? .distantPast) > now { return false }
            if (cooldown[device.disk] ?? .distantPast) > now { return false }
            if isRecorded(device, in: inProgress) { return false }
            if !explicit && isRecorded(device, in: attempted) { return false }
            return true
        }
    }

    /// 同名卷第二块常被系统跳过，停在未挂载。同一父盘上已有已挂载的同名兄弟时补挂。
    static func isNameCollisionLeftover(_ device: NTFSDevice, among devices: [NTFSDevice]) -> Bool {
        guard device.needsMount, !device.volumeName.isEmpty else { return false }
        return devices.contains { other in
            other.devicePath != device.devicePath
                && other.parentDisk == device.parentDisk
                && other.volumeName == device.volumeName
                && other.isMounted
                && !other.isUnmounted
        }
    }

    /// 同一轮扫描里同一卷只留一条，避免连续插第二块盘时挂载成功提示响两次。
    static func targets(
        devices: [NTFSDevice],
        settings: AppSettings,
        attempted: Set<String>,
        cooldown: [String: Date],
        inProgress: Set<String>,
        now: Date = Date(),
        explicit: Bool
    ) -> [NTFSDevice] {
        var picked: [NTFSDevice] = []
        for device in candidates(
            devices: devices,
            settings: settings,
            attempted: attempted,
            cooldown: cooldown,
            inProgress: inProgress,
            now: now,
            explicit: explicit
        ) {
            if picked.contains(where: { $0.sameMount(as: device) }) { continue }
            picked.append(device)
        }
        return picked
    }

    /// 身份、盘号、节点、UUID 记入尝试集。挂载点不能当身份：两块「新加卷」会暂时撞同一路径。
    static func recordKeys(_ device: NTFSDevice) -> [String] {
        var keys = [device.identity, device.disk, device.devicePath]
        if let uuid = device.volumeUuid, !uuid.isEmpty { keys.append("vu:" + uuid) }
        if let uuid = device.partitionUuid, !uuid.isEmpty { keys.append("pu:" + uuid) }
        return keys.filter { !$0.isEmpty }
    }

    static func isRecorded(_ device: NTFSDevice, in records: Set<String>) -> Bool {
        recordKeys(device).contains { records.contains($0) }
    }

    /// 还插着的卷保留已尝试记录，避免 DiskMonitor 连打失败重试。拔掉的卷必须清掉，否则盘号复用后不会再自动转读写。
    static func pruningStale(_ attempted: Set<String>, devices: [NTFSDevice]) -> Set<String> {
        attempted.intersection(Set(devices.flatMap(recordKeys)))
    }

    /// 一次「只刷新」的扫描正在进行时，插盘带来的自动转读写请求不能被丢掉。
    static func shouldApply(scanRequestedAuto: Bool, coalescedAuto: Bool) -> Bool {
        scanRequestedAuto || coalescedAuto
    }

    /// 外层正在串行挂多分区时，内层 `run` 成功后再调 applyAutoMount 只能排队，
    /// 否则同盘第二分区会被挂两次（只读→读写跳两次）。
    enum GateAdmission: Equatable {
        case enter
        case queue
    }

    static func admit(running: Bool) -> GateAdmission {
        running ? .queue : .enter
    }

    /// 一轮结束后若排队过，再扫一遍漏网只读分区（手动挂完第一块后的兄弟分区）。
    static func shouldContinue(queued: Bool) -> Bool {
        queued
    }

    /// 是否被用户标记为保持只读（identity / uuid / disk 任一命中）。
    static func isManuallyReadOnly(_ device: NTFSDevice, settings: AppSettings) -> Bool {
        let manual = Set(settings.manuallyReadOnlyDevices)
        if manual.contains(device.identity) || manual.contains(device.disk) { return true }
        if let uuid = device.volumeUuid, manual.contains(uuid) { return true }
        if let uuid = device.partitionUuid, manual.contains(uuid) { return true }
        return false
    }

    static func markManualReadOnly(_ device: NTFSDevice, settings: inout AppSettings) {
        // 同时记下 identity 与 disk，避免 uuid 短暂缺失时匹配失败
        for key in [device.identity, device.disk, device.volumeUuid, device.partitionUuid].compactMap({ $0 }) where !key.isEmpty {
            if !settings.manuallyReadOnlyDevices.contains(key) {
                settings.manuallyReadOnlyDevices.append(key)
            }
        }
    }

    static func clearManualReadOnly(_ device: NTFSDevice, settings: inout AppSettings) {
        let keys = Set([device.identity, device.disk, device.volumeUuid, device.partitionUuid].compactMap { $0 }.filter { !$0.isEmpty })
        settings.manuallyReadOnlyDevices.removeAll { keys.contains($0) }
    }
}
