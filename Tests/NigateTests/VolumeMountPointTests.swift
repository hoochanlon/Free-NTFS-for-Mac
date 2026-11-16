import XCTest
@testable import Nigate

final class VolumeMountPointTests: XCTestCase {
    func testKeepsPreferredWhenFree() {
        let path = VolumeMountPoint.allocate(
            name: "新加卷",
            disk: "disk8s2",
            preferred: "/Volumes/新加卷",
            occupied: []
        )
        XCTAssertEqual(path, "/Volumes/新加卷")
    }

    func testYieldsFinderStyleSuffixWhenPreferredTaken() {
        let occupied: Set<String> = ["/Volumes/新加卷"]
        let path = VolumeMountPoint.allocate(
            name: "新加卷",
            disk: "disk8s2",
            preferred: "/Volumes/新加卷",
            occupied: occupied
        )
        XCTAssertEqual(path, "/Volumes/新加卷 1")
    }

    func testSkipsTakenSuffixes() {
        let occupied: Set<String> = ["/Volumes/新加卷", "/Volumes/新加卷 1"]
        let path = VolumeMountPoint.allocate(
            name: "新加卷",
            disk: "disk8s2",
            preferred: nil,
            occupied: occupied
        )
        XCTAssertEqual(path, "/Volumes/新加卷 2")
    }

    func testIgnoresOwnMountWhenCollectingOccupied() {
        let mounts = [
            MountedVolume(
                devicePath: "/dev/disk8s1",
                mountPoint: "/Volumes/新加卷",
                driver: "ntfs-3g",
                options: ["ntfs-3g"]
            ),
            MountedVolume(
                devicePath: "/dev/disk8s2",
                mountPoint: "/Volumes/新加卷 1",
                driver: "ntfs-3g",
                options: ["ntfs-3g"]
            )
        ]
        let occupied = VolumeMountPoint.occupied(from: mounts, excludingDevicePath: "/dev/disk8s2")
        XCTAssertEqual(occupied, ["/Volumes/新加卷"])
    }

    func testAllocateForDeviceYieldsSiblingPath() {
        let device = NTFSDevice(
            disk: "disk8s2",
            devicePath: "/dev/disk8s2",
            volume: "/Volumes/新加卷",
            volumeName: "新加卷",
            volumeUuid: "vol-b",
            isReadOnly: true,
            options: "read-only",
            isMounted: false,
            isUnmounted: true,
            canFormat: true,
            capacity: nil
        )
        let mounts = [
            MountedVolume(
                devicePath: "/dev/disk8s1",
                mountPoint: "/Volumes/新加卷",
                driver: "ntfs-3g",
                options: ["ntfs-3g"]
            )
        ]
        XCTAssertEqual(VolumeMountPoint.allocate(for: device, mounts: mounts), "/Volumes/新加卷 1")
    }

    func testSuffixVolumeNameDoesNotDoubleIndex() {
        let path = VolumeMountPoint.allocate(
            name: "新加卷 1",
            disk: "disk5s2",
            preferred: "/Volumes/新加卷 1",
            occupied: ["/Volumes/新加卷"]
        )
        XCTAssertEqual(path, "/Volumes/新加卷 1")
    }
}
