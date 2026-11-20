import Foundation

/// 设备列表对外状态。标题文案、标题圆点、托盘圆点共用这一份计数。
/// 已卸载不是只读：未挂载卷的 isReadOnly 只是占位，不能拿来上色或计数。
enum DeviceFleetStatus: Equatable {
    /// 没有已挂载设备。列表空，或只剩已卸载。
    case ready
    case allReadWrite
    case allReadOnly
    case mixed
    /// 有已卸载，已挂载里只有读写。圆点左绿右灰。
    case readWriteUnmounted
    /// 有已卸载，已挂载的都是只读。圆点左橙右灰。
    case readOnlyUnmounted
    /// 读写、只读、已卸载同时在场。圆点左绿、中橙、右灰。
    case mixedUnmounted

    /// 圆点色块。从左到右固定为读写、只读、已卸载，只保留在场的。
    /// 等宽，不按数量切：8px 上少数派会缩成一条缝。
    enum Tone: Equatable {
        case readWrite, readOnly, unmounted
    }

    struct Counts: Equatable {
        var readWrite: Int
        var readOnly: Int
        var unmounted: Int

        var mounted: Int { readWrite + readOnly }

        static func tally(_ devices: [NTFSDevice]) -> Counts {
            devices.reduce(into: Counts(readWrite: 0, readOnly: 0, unmounted: 0)) { counts, device in
                if device.isUnmounted || !device.isMounted {
                    counts.unmounted += 1
                } else if device.isReadOnly {
                    counts.readOnly += 1
                } else {
                    counts.readWrite += 1
                }
            }
        }
    }

    init(devices: [NTFSDevice]) {
        self.init(counts: Counts.tally(devices))
    }

    init(counts: Counts) {
        switch (counts.readWrite > 0, counts.readOnly > 0, counts.unmounted > 0) {
        case (false, false, _):
            self = .ready
        case (true, false, false):
            self = .allReadWrite
        case (false, true, false):
            self = .allReadOnly
        case (true, true, false):
            self = .mixed
        case (true, false, true):
            self = .readWriteUnmounted
        case (false, true, true):
            self = .readOnlyUnmounted
        case (true, true, true):
            self = .mixedUnmounted
        }
    }

    var tones: [Tone] {
        switch self {
        case .ready: [.unmounted]
        case .allReadWrite: [.readWrite]
        case .allReadOnly: [.readOnly]
        case .mixed: [.readWrite, .readOnly]
        case .readWriteUnmounted: [.readWrite, .unmounted]
        case .readOnlyUnmounted: [.readOnly, .unmounted]
        case .mixedUnmounted: [.readWrite, .readOnly, .unmounted]
        }
    }

    /// 两种并存只报需要留意的部分。三种都在时，文案必须把绿橙灰都点名，否则圆点对不上。
    static func text(devices: [NTFSDevice]) -> String {
        text(counts: Counts.tally(devices))
    }

    static func text(counts: Counts) -> String {
        if counts.readWrite > 0, counts.readOnly > 0, counts.unmounted > 0 {
            return L10n.t("status.devicesMixedUnmounted", [
                "readWrite": "\(counts.readWrite)",
                "readOnly": "\(counts.readOnly)",
                "unmounted": "\(counts.unmounted)"
            ])
        }
        if counts.readOnly > 0, counts.unmounted > 0 {
            return L10n.t("status.devicesReadOnlyUnmounted", [
                "readOnly": "\(counts.readOnly)",
                "unmounted": "\(counts.unmounted)"
            ])
        }
        if counts.unmounted > 0 {
            return L10n.t("status.devicesUnmounted", ["count": "\(counts.unmounted)"])
        }
        if counts.readOnly > 0 {
            return L10n.t("status.devicesReadOnly", ["count": "\(counts.readOnly)"])
        }
        return L10n.t("status.devicesReady", ["count": "\(counts.readWrite)"])
    }
}
