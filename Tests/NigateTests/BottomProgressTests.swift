import XCTest
@testable import Nigate

final class BottomProgressTests: XCTestCase {
    func testSingleRemountShowsThatName() {
        var session = BottomProgress.Session()
        session = BottomProgress.insertingRemount(session, item("Samsung USB", "/dev/disk4s1"))
        XCTAssertEqual(BottomProgress.kind(session), .remountReadWrite(names: ["Samsung USB"]))
    }

    func testMultipleRemountKeepsOrderAndDedups() {
        var session = BottomProgress.Session()
        session = BottomProgress.insertingRemounts(session, [
            item("Samsung USB", "/dev/disk4s1"),
            item("SanDisk 32G", "/dev/disk5s1"),
            item("Samsung USB", "/dev/disk4s1")
        ])
        XCTAssertEqual(
            BottomProgress.kind(session),
            .remountReadWrite(names: ["Samsung USB", "SanDisk 32G"])
        )

        session = BottomProgress.removingRemount(session, id: "/dev/disk4s1")
        XCTAssertEqual(BottomProgress.kind(session), .remountReadWrite(names: ["SanDisk 32G"]))

        session = BottomProgress.removingRemount(session, id: "/dev/disk5s1")
        XCTAssertNil(BottomProgress.kind(session))
    }

    func testFormatOutranksRemountAndDoesNotClearIt() {
        var session = BottomProgress.Session()
        session = BottomProgress.insertingRemounts(session, [
            item("Samsung USB", "/dev/disk4s1"),
            item("SanDisk 32G", "/dev/disk5s1")
        ])
        session = BottomProgress.insertingFormat(session, id: "/dev/disk6s1", name: "Backup")
        XCTAssertEqual(BottomProgress.kind(session), .format(name: "Backup"))

        session = BottomProgress.removingFormat(session, id: "/dev/disk6s1")
        XCTAssertEqual(
            BottomProgress.kind(session),
            .remountReadWrite(names: ["Samsung USB", "SanDisk 32G"])
        )
    }

    func testRemovingUnknownIdIsNoOp() {
        var session = BottomProgress.Session()
        session = BottomProgress.insertingRemount(session, item("Samsung USB", "/dev/disk4s1"))
        session = BottomProgress.removingRemount(session, id: "/dev/disk9s1")
        session = BottomProgress.removingFormat(session, id: "/dev/disk4s1")
        XCTAssertEqual(BottomProgress.kind(session), .remountReadWrite(names: ["Samsung USB"]))
    }

    func testRemountItemsOnlyTakeMountedReadOnly() {
        let readOnly = sample(disk: "disk4s1", name: "Samsung USB", mounted: true, readOnly: true)
        let readWrite = sample(disk: "disk5s1", name: "SanDisk 32G", mounted: true, readOnly: false)
        let unmounted = sample(disk: "disk6s1", name: "Orphan", mounted: false, readOnly: true)
        let items = BottomProgress.remountItems(from: [readOnly, readWrite, unmounted])
        XCTAssertEqual(items.map(\.id), ["/dev/disk4s1"])
        XCTAssertEqual(items.map(\.name), ["Samsung USB"])
    }

    func testDropsRemountHintOnceDeviceIsReadWrite() {
        var session = BottomProgress.Session()
        session = BottomProgress.insertingRemounts(session, [
            item("Samsung USB", "/dev/disk5s1"),
            item("SanDisk 32G", "/dev/disk4s2")
        ])
        let samsungRW = sample(disk: "disk5s1", name: "Samsung USB", mounted: true, readOnly: false)
        let sandiskRO = sample(disk: "disk4s2", name: "SanDisk 32G", mounted: true, readOnly: true)
        session = BottomProgress.droppingFinishedRemounts(session, devices: [samsungRW, sandiskRO])
        XCTAssertEqual(BottomProgress.kind(session), .remountReadWrite(names: ["SanDisk 32G"]))

        let sandiskRW = sample(disk: "disk4s2", name: "SanDisk 32G", mounted: true, readOnly: false)
        session = BottomProgress.droppingFinishedRemounts(session, devices: [samsungRW, sandiskRW])
        XCTAssertNil(BottomProgress.kind(session))
    }

    func testKeepsRemountHintIfCardTemporarilyMissing() {
        var session = BottomProgress.Session()
        session = BottomProgress.insertingRemount(session, item("Samsung USB", "/dev/disk5s1"))
        session = BottomProgress.droppingFinishedRemounts(session, devices: [])
        XCTAssertEqual(BottomProgress.kind(session), .remountReadWrite(names: ["Samsung USB"]))
    }

    func testManyRemountTextJoinsNames() {
        let kind = BottomProgress.Kind.remountReadWrite(names: ["Samsung USB", "SanDisk 32G"])
        let text = BottomProgress.text(kind) { key, params in
            if key == "messages.nameListSeparator" { return "、" }
            if key == "messages.remountingReadWriteMany" {
                return "MANY \(params["count"] ?? "") \(params["names"] ?? "")"
            }
            return key
        }
        XCTAssertEqual(text, "MANY 2 Samsung USB、SanDisk 32G")
    }

    func testDropsRemountWhenPathChangedButNameIsUnique() {
        var session = BottomProgress.Session()
        session = BottomProgress.insertingRemount(session, item("Samsung USB", "/dev/disk5s1"))
        let remounted = sample(disk: "disk9s1", name: "Samsung USB", mounted: true, readOnly: false)
        session = BottomProgress.droppingFinishedRemounts(session, devices: [remounted])
        XCTAssertNil(BottomProgress.kind(session))
    }

    func testKeepsRemountWhenSameNameStillReadOnly() {
        var session = BottomProgress.Session()
        session = BottomProgress.insertingRemount(session, item("Samsung USB", "/dev/disk5s1"))
        let stillRO = sample(disk: "disk9s1", name: "Samsung USB", mounted: true, readOnly: true)
        session = BottomProgress.droppingFinishedRemounts(session, devices: [stillRO])
        XCTAssertEqual(BottomProgress.kind(session), .remountReadWrite(names: ["Samsung USB"]))
    }

    private func item(_ name: String, _ id: String) -> BottomProgress.Item {
        BottomProgress.Item(id: id, name: name)
    }

    private func sample(disk: String, name: String, mounted: Bool, readOnly: Bool) -> NTFSDevice {
        NTFSDevice(
            disk: disk,
            devicePath: "/dev/\(disk)",
            volume: mounted ? "/Volumes/\(name)" : "",
            volumeName: name,
            volumeUuid: nil,
            isReadOnly: readOnly,
            options: readOnly ? "read-only" : "local",
            isMounted: mounted,
            isUnmounted: !mounted,
            canFormat: true,
            capacity: nil
        )
    }
}
