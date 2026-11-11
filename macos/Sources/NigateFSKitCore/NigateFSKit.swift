import Foundation

/// FSKit 与主应用共享的稳定边界。
///
/// 这里只描述模块身份、系统能力和资源元数据；实际文件系统状态由 FSKit 扩展拥有，
/// 主应用通过后续控制面查询，不直接持有扩展内部对象。
public enum NigateFSKit {
    public static let moduleIdentifier = "io.hoochanlon.github.NigateFSKitExtension"
    public static let fileSystemName = "NigateNTFS"
    public static let minimumMajorVersion = 15
    public static let minimumMinorVersion = 4

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
///
/// `OperatingSystemVersion` 不提供稳定的值语义；控制面状态不能直接携带它，
/// 因此在进入共享模型时立即转换为纯值结构。
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
    /// 真实 FSKit 数据面；不支持时必须明确失败，不能自动切换后端。
    case fsKit
    /// 仅在用户明确选择时启用的历史兼容数据面。
    case ntfs3gCompatibility
}

public enum NigateFSKitAvailability: Equatable, Sendable {
    case supported
    case requiresMacOS15_4(current: NigateSystemVersion)
}

/// 主应用与数据面之间的选择约束。
///
/// FSKit 控制面尚未接通时，`.fsKit` 只能返回明确错误；它不能把请求转发给 ntfs-3g。
public enum MountBackendPolicyError: Error, Equatable, Sendable {
    case fsKitRequiresMacOS15_4
    case fsKitControlPlaneUnavailable
    case compatibilityBackendNotSelected
}

public enum MountBackendPolicy {
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
