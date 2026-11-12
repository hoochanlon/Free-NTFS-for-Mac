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

    var id: String { volumeUuid ?? partitionUuid ?? disk }
    var identity: String { volumeUuid ?? partitionUuid ?? disk }
    var parentDisk: String { DiskSafety.parentDiskId(disk) }
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
    var autoMount: Bool = false
    var startupTab: AppTab = .dependencies
    var language: AppLanguage = .system
    var trayMode: Bool = false
    var autoStart: Bool = false
    var preventSleep: Bool = false
    var keepAwake: Bool = false
    var manuallyReadOnlyDevices: [String] = []
    var mountBackend: NigateMountBackend = .ntfs3gCompatibility
    var themeIsLight: Bool = true

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

let appVersion = "1.6.0"
let appId = "io.hoochanlon.github"
let githubReleases = "https://github.com/hoochanlon/Free-NTFS-for-Mac/releases"
let githubRepo = "https://github.com/hoochanlon/Free-NTFS-for-Mac"
let authorEmail = "hoochanlon@outlook.com"
