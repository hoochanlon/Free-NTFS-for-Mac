import Foundation

/// 只读↔读写会先卸载再挂上。中间那一次扫描常常是空的，
/// 不能拿它覆盖当前列表，否则卡片会先消失再插回来。
enum DeviceListPin {
    struct Pin: Equatable, Sendable {
        var devicePath: String
        var parentDisk: String
        var action: DeviceAction
        /// 重命名成功后的目标卷标。扫描还停在旧名字时，不能拿它覆盖乐观态。
        var expectedVolumeName: String? = nil
    }

    /// 扫描结果已经和这次操作的目标态一致，才允许替换钉住的卡片。
    static func isSettled(_ device: NTFSDevice, pin: Pin) -> Bool {
        switch pin.action {
        case .mount:
            return device.isReadWrite
        case .restore, .reset:
            return device.isMounted && device.isReadOnly && !device.isUnmounted
        case .unmount:
            return device.isUnmounted || !device.isMounted
        case .eject, .format:
            return false
        case .rename:
            guard device.isMounted, !device.isUnmounted else { return false }
            guard let expected = pin.expectedVolumeName, !expected.isEmpty else { return true }
            return device.volumeName == expected
        case .repair:
            return device.isMounted && !device.isUnmounted
        }
    }

    /// 同盘兄弟在目标卸/挂时，diskutil 常短暂报「已卸载」。
    /// 若 held 仍是已挂载只读/读写，不能被这份瞬态盖掉，否则 UI 先变已卸载，
    /// 外层又会对它再走一遍卸→挂。
    static func shouldHoldSibling(held: NTFSDevice, live: NTFSDevice, pin: Pin) -> Bool {
        switch pin.action {
        case .mount, .restore, .reset, .repair, .rename:
            break
        case .unmount, .eject, .format:
            return false
        }
        let heldMounted = held.isMounted && !held.isUnmounted
        let liveGone = live.isUnmounted || !live.isMounted
        return heldMounted && liveGone
    }

    /// `scanned` 缺了正在切换的分区，或还停在卸载中间态时，沿用 `held`。
    /// 身份始终是 devicePath：同一张卡原地改状态，不拆不插。
    /// 同盘另一分区：空扫描留卡；瞬态「已卸载」也留 held 挂载态。
    static func merge(scanned: [NTFSDevice], held: [NTFSDevice], pins: [Pin]) -> [NTFSDevice] {
        guard !pins.isEmpty else { return scanned }
        var byPath = Dictionary(scanned.map { ($0.devicePath, $0) }, uniquingKeysWith: { _, last in last })
        for item in held {
            guard let pin = pins.first(where: {
                $0.devicePath == item.devicePath || $0.parentDisk == item.parentDisk
            }) else { continue }
            let isTarget = pin.devicePath == item.devicePath
            if isTarget {
                if let live = byPath[item.devicePath], isSettled(live, pin: pin) {
                    continue
                }
                byPath[item.devicePath] = item
            } else if let live = byPath[item.devicePath] {
                if shouldHoldSibling(held: item, live: live, pin: pin) {
                    byPath[item.devicePath] = item
                }
            } else {
                byPath[item.devicePath] = item
            }
        }
        return byPath.values.sorted { $0.disk < $1.disk }
    }
}
