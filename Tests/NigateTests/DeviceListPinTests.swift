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
