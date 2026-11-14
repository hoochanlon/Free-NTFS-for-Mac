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
