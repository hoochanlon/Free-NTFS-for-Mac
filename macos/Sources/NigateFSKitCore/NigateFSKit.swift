import Foundation

/// FSKit 与主应用共享的稳定边界。
///
/// 这里只描述模块身份、系统能力和资源元数据；实际文件系统状态由 FSKit 扩展拥有，
/// 主应用通过控制面查询，不直接持有扩展内部对象。
public enum NigateFSKit {
    public static let moduleIdentifier = "io.hoochanlon.github.NigateFSKitExtension"
    public static let fileSystemName = "NigateNTFS"
    public static let shortName = "NigateNTFS"
    public static let minimumMajorVersion = 15
    public static let minimumMinorVersion = 4

    /// 数据面已随本版本一并交付；是否“可用”仍取决于系统版本 + 扩展安装/启用。
    public static let isDataPlaneImplemented = true

    public static var isSupportedOnCurrentSystem: Bool {
        if #available(macOS 15.4, *) {
            return true
        }
        return false
    }

    public static var availabilityOnCurrentSystem: NigateFSKitAvailability {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return isSupported(version)
            ? .supported
            : .requiresMacOS15_4(current: .init(version))
    }

    public static func isSupported(_ version: OperatingSystemVersion) -> Bool {
        isSupported(.init(version))
    }

    public static func isSupported(_ version: NigateSystemVersion) -> Bool {
        guard version.major >= minimumMajorVersion else { return false }
        guard version.major != minimumMajorVersion else {
            return version.minor >= minimumMinorVersion
        }
        return true
    }
}

/// 可跨模块传递的系统版本快照。
public struct NigateSystemVersion: Codable, Equatable, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init(_ version: OperatingSystemVersion) {
        self.init(
            major: version.majorVersion,
            minor: version.minorVersion,
            patch: version.patchVersion
        )
    }
}

public enum NigateMountBackend: String, Codable, Equatable, Sendable {
    /// 默认与对外主路径：ntfs-3g + FUSE 兼容数据面。
    case ntfs3gCompatibility
    /// 可选：真实 FSKit 数据面；不支持时必须明确失败，不能自动切换后端。
    case fsKit
}

public enum NigateFSKitAvailability: Equatable, Sendable {
    case supported
    case requiresMacOS15_4(current: NigateSystemVersion)
}

/// 可本地化的 FSKit 控制面诊断；共享层传递状态，界面层负责翻译。
public enum NigateFSKitControlPlaneDiagnostic: Codable, Equatable, Sendable {
    case controlPlaneUnavailable
    case unsupportedSystem(current: NigateSystemVersion)
    case extensionDisabled
    case extensionNotRegistered
}

/// 控制面探测结果：系统能力 + 扩展身份 + 启用态。
///
/// `isControlPlaneAvailable` 的判定是：
/// 系统支持 ∧ 数据面已实现 ∧ 扩展已安装 ∧ 扩展已启用。
public struct NigateFSKitControlPlaneState: Codable, Equatable, Sendable {
    public var systemSupported: Bool
    public var dataPlaneImplemented: Bool
    public var extensionInstalled: Bool
    public var extensionEnabled: Bool
    public var moduleURL: String?
    public var election: NigateFSKitExtensionElection
    public var source: NigateFSKitControlPlaneSource
    public var diagnostic: NigateFSKitControlPlaneDiagnostic?

    public init(
        systemSupported: Bool,
        dataPlaneImplemented: Bool = NigateFSKit.isDataPlaneImplemented,
        extensionInstalled: Bool,
        extensionEnabled: Bool,
        moduleURL: String? = nil,
        election: NigateFSKitExtensionElection = .unknown,
        source: NigateFSKitControlPlaneSource = .none,
        diagnostic: NigateFSKitControlPlaneDiagnostic? = nil
    ) {
        self.systemSupported = systemSupported
        self.dataPlaneImplemented = dataPlaneImplemented
        self.extensionInstalled = extensionInstalled
        self.extensionEnabled = extensionEnabled
        self.moduleURL = moduleURL
        self.election = election
        self.source = source
        self.diagnostic = diagnostic
    }

    public var isControlPlaneAvailable: Bool {
        systemSupported
            && dataPlaneImplemented
            && extensionInstalled
            && extensionEnabled
    }

    public static let unavailable = NigateFSKitControlPlaneState(
        systemSupported: false,
        dataPlaneImplemented: NigateFSKit.isDataPlaneImplemented,
        extensionInstalled: false,
        extensionEnabled: false,
        source: .none,
        diagnostic: .controlPlaneUnavailable
    )

    public static func unsupportedSystem(_ version: NigateSystemVersion) -> NigateFSKitControlPlaneState {
        NigateFSKitControlPlaneState(
            systemSupported: false,
            extensionInstalled: false,
            extensionEnabled: false,
            source: .none,
            diagnostic: .unsupportedSystem(current: version)
        )
    }
}

public enum NigateFSKitExtensionElection: String, Codable, Equatable, Sendable {
    case use
    case ignore
    case debugger
    case superseded
    case defaulted
    case unknown
}

public enum NigateFSKitControlPlaneSource: String, Codable, Equatable, Sendable {
    case none
    case fsClient
    case pluginKit
    case combined
}

/// 主应用与数据面之间的选择约束。
///
/// 控制面状态由主应用注入；未注入时默认不可用（失败关闭）。
/// 已保存的无效选择由 `sanitize` 纠正到可工作的兼容后端——这是配置自愈，
/// 不是挂载路径上的静默降级。
public enum MountBackendPolicyError: Error, Equatable, Sendable {
    case fsKitRequiresMacOS15_4
    case fsKitControlPlaneUnavailable
    case compatibilityBackendNotSelected
}

public enum MountBackendPolicy {
    /// 运行时注入的控制面快照。测试与主应用共用同一判定入口。
    nonisolated(unsafe) private static var injectedState: NigateFSKitControlPlaneState = .unavailable

    public static var controlPlaneState: NigateFSKitControlPlaneState {
        get { injectedState }
        set { injectedState = newValue }
    }

    public static var isControlPlaneAvailable: Bool {
        controlPlaneState.isControlPlaneAvailable
    }

    public static func updateControlPlaneState(_ state: NigateFSKitControlPlaneState) {
        injectedState = state
    }

    public static func canUseFSKit(
        systemVersion: NigateSystemVersion = .init(ProcessInfo.processInfo.operatingSystemVersion),
        isFSKitControlPlaneAvailable: Bool = isControlPlaneAvailable
    ) -> Bool {
        NigateFSKit.isSupported(systemVersion) && isFSKitControlPlaneAvailable
    }

    /// 纠正无法工作的后端选择，返回实际应使用的后端。
    public static func sanitize(
        _ backend: NigateMountBackend,
        systemVersion: NigateSystemVersion = .init(ProcessInfo.processInfo.operatingSystemVersion),
        isFSKitControlPlaneAvailable: Bool = isControlPlaneAvailable
    ) -> NigateMountBackend {
        switch backend {
        case .ntfs3gCompatibility:
            return .ntfs3gCompatibility
        case .fsKit:
            return canUseFSKit(
                systemVersion: systemVersion,
                isFSKitControlPlaneAvailable: isFSKitControlPlaneAvailable
            ) ? .fsKit : .ntfs3gCompatibility
        }
    }

    public static func validate(
        _ backend: NigateMountBackend,
        systemVersion: NigateSystemVersion,
        isFSKitControlPlaneAvailable: Bool
    ) throws {
        switch backend {
        case .fsKit:
            guard NigateFSKit.isSupported(systemVersion) else {
                throw MountBackendPolicyError.fsKitRequiresMacOS15_4
            }
            guard isFSKitControlPlaneAvailable else {
                throw MountBackendPolicyError.fsKitControlPlaneUnavailable
            }
        case .ntfs3gCompatibility:
            break
        }
    }
}

/// 主应用向控制面传递的最小资源描述。
///
/// `devicePath` 只允许来自系统枚举结果；扩展侧仍必须在实际 I/O 前重新校验设备身份。
public struct NigateFSKitResource: Codable, Equatable, Hashable, Sendable {
    public let devicePath: String
    public let diskIdentifier: String
    public let volumeName: String
    public let volumeUUID: String?
    public let readOnly: Bool

    public init(
        devicePath: String,
        diskIdentifier: String,
        volumeName: String,
        volumeUUID: String?,
        readOnly: Bool
    ) {
        self.devicePath = devicePath
        self.diskIdentifier = diskIdentifier
        self.volumeName = volumeName
        self.volumeUUID = volumeUUID
        self.readOnly = readOnly
    }
}
