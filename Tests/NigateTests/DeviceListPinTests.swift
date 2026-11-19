import XCTest
@testable import Nigate

final class DeviceListPinTests: XCTestCase {
    func testIdentityStaysOnDevicePathAcrossReadOnlyReadWrite() {
        let readOnly = sample(disk: "disk4s1", mounted: true, readOnly: true)
        var readWrite = readOnly
        readWrite.isReadOnly = false
        XCTAssertEqual(readOnly.id, "/dev/disk4s1")
        XCTAssertEqual(readOnly.id, readWrite.id)
        XCTAssertNotEqual(readOnly, readWrite)
    }

    func testEmptyScanDuringMountKeepsHeldCard() {
        let held = sample(disk: "disk4s1", mounted: true, readOnly: true)
        let merged = DeviceListPin.merge(
            scanned: [],
            held: [held],
            pins: [pin(held, .mount)]
        )
        XCTAssertEqual(merged.map(\.devicePath), [held.devicePath])
        XCTAssertTrue(merged[0].isReadOnly)
    }

    func testTransientUnmountedScanDuringMountDoesNotReplaceCard() {
        let held = sample(disk: "disk4s1", mounted: true, readOnly: true)
        let unmounted = sample(disk: "disk4s1", mounted: false, readOnly: true)
        let merged = DeviceListPin.merge(
            scanned: [unmounted],
            held: [held],
            pins: [pin(held, .mount)]
        )
        XCTAssertEqual(merged, [held])
        XCTAssertTrue(merged[0].isMounted)
        XCTAssertTrue(merged[0].isReadOnly)
    }

    func testSettledReadWriteScanReplacesHeldInPlace() {
        let held = sample(disk: "disk4s1", mounted: true, readOnly: true)
        var live = held
        live.isReadOnly = false
        live.volume = "/Volumes/Data"
        let merged = DeviceListPin.merge(
            scanned: [live],
            held: [held],
            pins: [pin(held, .mount)]
        )
        XCTAssertEqual(merged.map(\.id), [held.id])
        XCTAssertTrue(merged[0].isReadWrite)
        XCTAssertEqual(merged[0].volume, "/Volumes/Data")
    }

    func testEmptyScanDuringRestoreKeepsHeldCard() {
        let held = sample(disk: "disk4s1", mounted: true, readOnly: false)
        let merged = DeviceListPin.merge(
            scanned: [],
            held: [held],
            pins: [pin(held, .restore)]
        )
        XCTAssertEqual(merged.map(\.devicePath), [held.devicePath])
        XCTAssertTrue(merged[0].isReadWrite)
    }

    func testSettledReadOnlyScanReplacesHeldInPlace() {
        let held = sample(disk: "disk4s1", mounted: true, readOnly: false)
        var live = held
        live.isReadOnly = true
        let merged = DeviceListPin.merge(
            scanned: [live],
            held: [held],
            pins: [pin(held, .restore)]
        )
        XCTAssertEqual(merged.map(\.id), [held.id])
        XCTAssertTrue(merged[0].isReadOnly)
        XCTAssertTrue(merged[0].isMounted)
    }

    func testUnpinnedMissingDeviceIsDropped() {
        let kept = sample(disk: "disk4s1", mounted: true, readOnly: true)
        let other = sample(disk: "disk5s1", mounted: true, readOnly: true)
        let merged = DeviceListPin.merge(
            scanned: [kept],
            held: [kept, other],
            pins: [pin(kept, .mount)]
        )
        XCTAssertEqual(merged.map(\.devicePath), [kept.devicePath])
    }

    func testStaleNameDuringRenameKeepsOptimisticLabel() {
        var held = sample(disk: "disk4s2", mounted: true, readOnly: false)
        held.volumeName = "SanDisk 32"
        held.volume = "/Volumes/SanDisk 32"
        let stale = sample(disk: "disk4s2", mounted: true, readOnly: false)
        var renamePin = pin(held, .rename)
        renamePin.expectedVolumeName = "SanDisk 32"
        let merged = DeviceListPin.merge(
            scanned: [stale],
            held: [held],
            pins: [renamePin]
        )
        XCTAssertEqual(merged.map(\.devicePath), [held.devicePath])
        XCTAssertEqual(merged[0].volumeName, "SanDisk 32")
        XCTAssertEqual(merged[0].volume, "/Volumes/SanDisk 32")
    }

    func testSettledRenameReplacesHeldInPlace() {
        var held = sample(disk: "disk4s2", mounted: true, readOnly: false)
        held.volumeName = "SanDisk 32"
        held.volume = "/Volumes/SanDisk 32"
        var live = held
        live.capacity = Capacity(total: 100, used: 90, available: 10)
        var renamePin = pin(held, .rename)
        renamePin.expectedVolumeName = "SanDisk 32"
        let merged = DeviceListPin.merge(
            scanned: [live],
            held: [held],
            pins: [renamePin]
        )
        XCTAssertEqual(merged.map(\.id), [held.id])
        XCTAssertEqual(merged[0].volumeName, "SanDisk 32")
        XCTAssertEqual(merged[0].capacity?.used, 90)
    }

    func testNoPinsReturnsScannedEvenIfEmpty() {
        let held = sample(disk: "disk4s1", mounted: true, readOnly: true)
        let merged = DeviceListPin.merge(scanned: [], held: [held], pins: [])
        XCTAssertTrue(merged.isEmpty)
    }

    func testSiblingOnSameDiskIsNotFrozenToMountTarget() {
        let target = sample(disk: "disk8s1", mounted: true, readOnly: true)
        var sibling = sample(disk: "disk8s2", mounted: true, readOnly: true)
        sibling.volume = "/Volumes/新加卷 1"
        var liveTarget = target
        liveTarget.isReadOnly = false
        let merged = DeviceListPin.merge(
            scanned: [liveTarget, sibling],
            held: [target, sibling],
            pins: [pin(target, .mount)]
        )
        XCTAssertEqual(Set(merged.map(\.disk)), ["disk8s1", "disk8s2"])
        XCTAssertEqual(merged.first { $0.disk == "disk8s1" }?.isReadWrite, true)
        XCTAssertEqual(merged.first { $0.disk == "disk8s2" }?.isReadOnly, true)
        XCTAssertEqual(merged.first { $0.disk == "disk8s2" }?.volume, "/Volumes/新加卷 1")
    }

    func testEmptyScanKeepsSiblingOnPinnedDisk() {
        let target = sample(disk: "disk8s1", mounted: true, readOnly: true)
        let sibling = sample(disk: "disk8s2", mounted: true, readOnly: true)
        let merged = DeviceListPin.merge(
            scanned: [],
            held: [target, sibling],
            pins: [pin(target, .mount)]
        )
        XCTAssertEqual(Set(merged.map(\.disk)), ["disk8s1", "disk8s2"])
    }

    /// 转读写 disk4s1 时，扫描常把同盘 disk4s2 瞬态打成已卸载；不能盖掉仍挂着的只读卡。
    func testTransientUnmountedSiblingKeepsHeldMountedCard() {
        let target = sample(disk: "disk4s1", mounted: true, readOnly: true)
        var sibling = sample(disk: "disk4s2", mounted: true, readOnly: true)
        sibling.volume = "/Volumes/新加卷 1"
        sibling.volumeName = "新加卷 1"
        var liveTarget = target
        liveTarget.isReadOnly = false
        let ghostSibling = sample(disk: "disk4s2", mounted: false, readOnly: true)
        let merged = DeviceListPin.merge(
            scanned: [liveTarget, ghostSibling],
            held: [target, sibling],
            pins: [pin(target, .mount)]
        )
        XCTAssertEqual(merged.first { $0.disk == "disk4s1" }?.isReadWrite, true)
        let kept = merged.first { $0.disk == "disk4s2" }
        XCTAssertEqual(kept?.isMounted, true)
        XCTAssertEqual(kept?.isUnmounted, false)
        XCTAssertEqual(kept?.isReadOnly, true)
        XCTAssertEqual(kept?.volume, "/Volumes/新加卷 1")
    }

    func testSiblingTrulyUnmountedHeldIsNotForcedMounted() {
        let target = sample(disk: "disk4s1", mounted: true, readOnly: true)
        let sibling = sample(disk: "disk4s2", mounted: false, readOnly: true)
        var liveTarget = target
        liveTarget.isReadOnly = false
        let liveSibling = sample(disk: "disk4s2", mounted: false, readOnly: true)
        let merged = DeviceListPin.merge(
            scanned: [liveTarget, liveSibling],
            held: [target, sibling],
            pins: [pin(target, .mount)]
        )
        XCTAssertEqual(merged.first { $0.disk == "disk4s2" }?.isUnmounted, true)
    }

    private func pin(_ device: NTFSDevice, _ action: DeviceAction) -> DeviceListPin.Pin {
        DeviceListPin.Pin(devicePath: device.devicePath, parentDisk: device.parentDisk, action: action)
    }

    private func sample(disk: String, mounted: Bool, readOnly: Bool) -> NTFSDevice {
        NTFSDevice(
            disk: disk,
            devicePath: "/dev/\(disk)",
            volume: mounted ? "/Volumes/Data" : "",
            volumeName: "Data",
            volumeUuid: "vol-\(disk)",
            partitionUuid: "part-\(disk)",
            isReadOnly: readOnly,
            options: readOnly ? "read-only" : "",
            isMounted: mounted,
            isUnmounted: !mounted,
            canFormat: true,
            capacity: nil
        )
    }
}
