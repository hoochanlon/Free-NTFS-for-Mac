import Foundation
import NigateFSKitCore

enum DependencyService {
    static func check() async -> DependencyStatus {
        var status = DependencyStatus()
        let version = await Shell.runQuiet("/usr/bin/sw_vers", ["-productVersion"], timeout: 3).stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
        status.macosVersionString = version.isEmpty ? "未知" : version
        let major = Int(version.split(separator: ".").first.map(String.init) ?? "0") ?? 0
        status.macosVersion = major >= 14
        status.fsKitSupported = NigateFSKit.isSupportedOnCurrentSystem
        // 控制面快照由 AppModel 注入；依赖页直接读取，避免重复 probe。
        let plane = MountBackendPolicy.controlPlaneState
        status.fsKitControlPlaneAvailable = plane.isControlPlaneAvailable
        status.fsKitExtensionInstalled = plane.extensionInstalled
        status.fsKitExtensionEnabled = plane.extensionEnabled
        status.fsKitDiagnostic = plane.diagnostic
        status.swift = Shell.which("swift") != nil
        status.brew = Shell.which("brew") != nil
        status.fswatch = Shell.which("fswatch") != nil
        status.macfuse = FuseLibrary.inspect().isUsable
        if let path = await PathLookup.ntfs3g() {
            status.ntfs3g = true
            status.ntfs3gPath = path
        }
        return status
    }
}
