import Foundation
import NigateFSKitCore

enum DependencyService {
    static func check() async -> DependencyStatus {
        async let versionTask = Shell.runQuiet("/usr/bin/sw_vers", ["-productVersion"], timeout: 3)
        async let ntfsTask = PathLookup.ntfs3g()

        var status = DependencyStatus()
        status.isProbed = true
        let plane = MountBackendPolicy.controlPlaneState
        status.fsKitSupported = NigateFSKit.isSupportedOnCurrentSystem
        status.fsKitControlPlaneAvailable = plane.isControlPlaneAvailable
        status.fsKitExtensionInstalled = plane.extensionInstalled
        status.fsKitExtensionEnabled = plane.extensionEnabled
        status.fsKitDiagnostic = plane.diagnostic
        status.swift = Shell.which("swift") != nil
        status.brew = Shell.which("brew") != nil
        status.fswatch = Shell.which("fswatch") != nil
        status.macfuse = FuseLibrary.inspect().isUsable

        let version = await versionTask.stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
        status.macosVersionString = version
        let major = Int(version.split(separator: ".").first.map(String.init) ?? "0") ?? 0
        status.macosVersion = major >= 14
        if let path = await ntfsTask {
            status.ntfs3g = true
            status.ntfs3gPath = path
        }
        return status
    }
}
