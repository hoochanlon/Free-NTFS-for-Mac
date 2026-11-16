import Foundation

/// 同名 NTFS 卷不能都挂到 `/Volumes/新加卷`。按 Finder 习惯让出 `新加卷 1`、`新加卷 2`。
enum VolumeMountPoint {
    static func allocate(
        name: String,
        disk: String,
        preferred: String?,
        occupied: Set<String>
    ) -> String {
        if let preferred,
           DiskSafety.isSafeMountPoint(preferred),
           !occupied.contains(preferred) {
            return preferred
        }
        let baseName = DiskSafety.sanitizeVolumeName(name)
        let base = "/Volumes/\(baseName)"
        if !occupied.contains(base), DiskSafety.isSafeMountPoint(base) {
            return base
        }
        var index = 1
        while index < 100 {
            let candidate = "\(base) \(index)"
            if !occupied.contains(candidate), DiskSafety.isSafeMountPoint(candidate) {
                return candidate
            }
            index += 1
        }
        let fallback = "/Volumes/\(DiskSafety.sanitizeVolumeName("\(baseName)-\(disk)"))"
        return DiskSafety.isSafeMountPoint(fallback) ? fallback : base
    }

    static func allocate(for device: NTFSDevice, mounts: [MountedVolume]) -> String {
        allocate(
            name: device.volumeName.isEmpty ? device.disk : device.volumeName,
            disk: device.disk,
            preferred: device.volume.isEmpty ? nil : device.volume,
            occupied: occupied(from: mounts, excludingDevicePath: device.devicePath)
        )
    }

    static func occupied(from mounts: [MountedVolume], excludingDevicePath: String) -> Set<String> {
        Set(mounts.compactMap { $0.devicePath == excludingDevicePath ? nil : $0.mountPoint })
    }
}
