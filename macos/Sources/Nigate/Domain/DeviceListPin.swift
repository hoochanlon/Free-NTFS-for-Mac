import Foundation

/// 只读↔读写会先卸载再挂上。中间那一次扫描常常是空的，
/// 不能拿它覆盖当前列表，否则卡片会先消失再插回来。
enum DeviceListPin {
    struct Pin: Equatable, Sendable {
        var devicePath: String
        var parentDisk: String
        var action: DeviceAction
    }

    /// 扫描结果已经和这次操作的目标态一致，才允许替换钉住的卡片。
    static func isSettled(_ device: NTFSDevice, action: DeviceAction) -> Bool {
        switch action {
        case .mount:
            return device.isReadWrite
        case .restore, .reset:
            return device.isMounted && device.isReadOnly && !device.isUnmounted
        case .unmount:
            return device.isUnmounted || !device.isMounted
        case .eject, .format:
            return false
        default:
            return device.isMounted && !device.isUnmounted
        }
    }

    /// `scanned` 缺了正在切换的分区，或还停在卸载中间态时，沿用 `held`。
    /// 身份始终是 devicePath：同一张卡原地改状态，不拆不插。
    static func merge(scanned: [NTFSDevice], held: [NTFSDevice], pins: [Pin]) -> [NTFSDevice] {
        guard !pins.isEmpty else { return scanned }
        var byPath = Dictionary(scanned.map { ($0.devicePath, $0) }, uniquingKeysWith: { _, last in last })
        for item in held {
            guard let pin = pins.first(where: {
                $0.parentDisk == item.parentDisk || $0.devicePath == item.devicePath
            }) else { continue }
            if let live = byPath[item.devicePath], isSettled(live, action: pin.action) {
                continue
            }
            byPath[item.devicePath] = item
        }
        return byPath.values.sorted { $0.disk < $1.disk }
    }
}
