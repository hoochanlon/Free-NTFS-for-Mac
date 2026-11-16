import Foundation
import NigateFSKitCore

enum AppTab: String, Codable, CaseIterable, Sendable {
    case dependencies, devices, help, settings
}

enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case system, zhCN = "zh-CN", zhTW = "zh-TW", ja, en, de
}

enum SleepMode: String, Sendable {
    case off, always, smart
}

struct Capacity: Sendable, Equatable {
    var total: Int64
    var used: Int64
    var available: Int64

    /// 进度条告警：80% 起注意，90% 起危险。低于 80% 保持默认。
    enum FillLevel: Equatable, Sendable {
        case normal, warning, critical
    }

    var fillLevel: FillLevel {
        guard total > 0, used > 0 else { return .normal }
        if used * 10 >= total * 9 { return .critical }
        if used * 5 >= total * 4 { return .warning }
        return .normal
    }

    /// 与进度条同一口径。不足 1% 但不为 0 时不显示成 0%，避免细条和「使用率 0%」矛盾。
    var usedPercentLabel: String {
        guard total > 0 else { return "0%" }
        let ratio = min(1, max(0, Double(used) / Double(total)))
        let percent = Int((ratio * 100).rounded())
        if percent == 0, used > 0 { return "<1%" }
        return "\(percent)%"
    }
}

struct NTFSDevice: Sendable, Equatable, Identifiable {
    var disk: String
    var devicePath: String
    var volume: String
    var volumeName: String
    var volumeUuid: String?
    var partitionUuid: String? = nil
    var isReadOnly: Bool
    var options: String
    var isMounted: Bool
    var isUnmounted: Bool
    var canFormat: Bool
    var capacity: Capacity?

    /// 列表身份跟分区走，不跟后到的 UUID 走，避免只读↔读写时卡片被拆掉再插一次。
    var id: String { devicePath }
    /// MBR NTFS 常常没有 Volume UUID。空字符串不能当身份，否则两块「新加卷」会撞成同一条已尝试记录。
    var identity: String {
        if let volumeUuid, !volumeUuid.isEmpty { return volumeUuid }
        if let partitionUuid, !partitionUuid.isEmpty { return partitionUuid }
        return disk
    }
    var parentDisk: String { DiskSafety.parentDiskId(disk) }

    /// 挂载表同一分区可能打出两行，diskutil 也可能再给一个节点。
    /// 路径、盘号或 UUID 对上才是同一卷。挂载点相同但 diskNsM 不同，只是卷标撞车。
    func sameMount(as other: NTFSDevice) -> Bool {
        if devicePath == other.devicePath || disk == other.disk { return true }
        if let volumeUuid, !volumeUuid.isEmpty, volumeUuid == other.volumeUuid { return true }
        if let partitionUuid, !partitionUuid.isEmpty, partitionUuid == other.partitionUuid { return true }
        if !volume.isEmpty, volume == other.volume, !isDistinctPartition(from: other) {
            return true
        }
        return false
    }

    /// 两个不同的可挂载节点，即使都叫「新加卷」也不是同一张卡。
    func isDistinctPartition(from other: NTFSDevice) -> Bool {
        DiskSafety.isMountableNode(devicePath)
            && DiskSafety.isMountableNode(other.devicePath)
            && devicePath != other.devicePath
    }
    var isReadWrite: Bool { isMounted && !isReadOnly && !isUnmounted }
    var needsMount: Bool { isUnmounted || !isMounted }
}

struct DependencyStatus: Sendable, Equatable {
    var swift: Bool = false
    var brew: Bool = false
    var macfuse: Bool = false
    var ntfs3g: Bool = false
    var ntfs3gPath: String? = nil
    var macosVersion: Bool = false
    var macosVersionString: String = "未知"
    /// 系统版本是否达到 FSKit 门槛（≥15.4）
    var fsKitSupported: Bool = false
    /// 扩展已安装且已启用（控制面可挂载）
    var fsKitControlPlaneAvailable: Bool = false
    var fsKitExtensionInstalled: Bool = false
    var fsKitExtensionEnabled: Bool = false
    var fsKitDiagnostic: NigateFSKitControlPlaneDiagnostic? = nil
    var fswatch: Bool = false

    var missingCore: Bool { !macosVersion || !macfuse || !ntfs3g }
}

struct AppSettings: Codable, Sendable, Equatable {
    var savePassword: Bool = true
    var startupTab: AppTab = .dependencies
    var language: AppLanguage = .system
    var autoStart: Bool = false
    var preventSleep: Bool = true
    var keepAwake: Bool = false
    var manuallyReadOnlyDevices: [String] = []
    var mountBackend: NigateMountBackend = .ntfs3gCompatibility
    var themeIsLight: Bool = true
    var showButtonHints: Bool = false

    var sleepMode: SleepMode {
        if keepAwake { return .always }
        if preventSleep { return .smart }
        return .off
    }

    mutating func applySleepMode(_ mode: SleepMode) {
        keepAwake = mode == .always
        preventSleep = mode == .smart
    }
}

enum DeviceAction: String, Sendable {
    case mount, unmount, restore, reset, repair, rename, format, eject
}

struct AppAlert: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var message: String
    var kind: Kind = .info

    enum Kind { case info, warning, error }
}

let appId = "io.hoochanlon.github"
let githubReleases = "https://github.com/hoochanlon/Free-NTFS-for-Mac/releases"
let githubRepo = "https://github.com/hoochanlon/Free-NTFS-for-Mac"
let authorBlog = "https://hoochanlon.github.io"
let authorEmail = "hoochanlon@outlook.com"
