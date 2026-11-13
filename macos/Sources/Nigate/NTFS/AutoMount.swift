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
            guard device.isMounted, device.isReadOnly, !device.isUnmounted else { return false }
            // 用户明确还原只读后，绝不能再被自动改挂为读写
            if isManuallyReadOnly(device, settings: settings) { return false }
            let id = device.identity
            if (cooldown[id] ?? .distantPast) > now { return false }
            if (cooldown[device.disk] ?? .distantPast) > now { return false }
            if inProgress.contains(id) || inProgress.contains(device.disk) { return false }
            if !explicit && (attempted.contains(id) || attempted.contains(device.disk)) { return false }
            return true
        }
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
