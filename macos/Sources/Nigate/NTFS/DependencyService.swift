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
        status.macfuse = await macfuseInstalled(brew: status.brew)
        if let path = await PathLookup.ntfs3g() {
            status.ntfs3g = true
            status.ntfs3gPath = path
        }
        return status
    }

    private static func macfuseInstalled(brew: Bool) async -> Bool {
        if brew, let brewPath = Shell.which("brew") {
            let listed = await Shell.runQuiet(brewPath, ["list", "--cask", "macfuse"], timeout: 5)
            if listed.ok { return true }
        }
        let files = [
            "/Library/Filesystems/macfuse.fs/Contents/Resources/mount_macfuse",
            "/Library/Filesystems/macfuse.fs/Contents/Resources/load_macfuse",
            "/usr/local/lib/libfuse.dylib",
            "/opt/homebrew/lib/libfuse.dylib"
        ]
        if files.contains(where: Shell.exists) { return true }

        let ext = await Shell.runQuiet("/usr/bin/systemextensionsctl", ["list"], timeout: 3).stdout.lowercased()
        if ext.contains("macfuse") || ext.contains("fuse") {
            for line in ext.split(whereSeparator: \.isNewline).map(String.init) {
                if (line.contains("macfuse") || line.contains("fuse")) &&
                    (line.contains("enabled") || line.contains("activated") || line.contains("running") || line.contains("*")) {
                    return true
                }
            }
        }
        return false
    }
}
