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

    func testDoesNotDropOtherRemountWhenDuplicateNames() {
        var session = BottomProgress.Session()
        session = BottomProgress.insertingRemounts(session, [
            item("新加卷", "/dev/disk8s1"),
            item("新加卷", "/dev/disk8s2")
        ])
        let firstRW = sample(disk: "disk8s1", name: "新加卷", mounted: true, readOnly: false)
        let secondRO = sample(disk: "disk8s2", name: "新加卷", mounted: true, readOnly: true)
        session = BottomProgress.droppingFinishedRemounts(session, devices: [firstRW, secondRO])
        XCTAssertEqual(BottomProgress.kind(session), .remountReadWrite(names: ["新加卷"]))
    }

    func testSingleRestoreShowsThatName() {
        var session = BottomProgress.Session()
        session = BottomProgress.insertingRestore(session, item("新加卷 1", "/dev/disk5s2"))
        XCTAssertEqual(BottomProgress.kind(session), .restoreReadOnly(names: ["新加卷 1"]))
    }

    func testMultipleRestoreKeepsOrderAndDedups() {
        var session = BottomProgress.Session()
        session = BottomProgress.insertingRestores(session, [
            item("新加卷 1", "/dev/disk5s2"),
            item("SanDisk 32G", "/dev/disk4s2"),
            item("新加卷 1", "/dev/disk5s2")
        ])
        XCTAssertEqual(
            BottomProgress.kind(session),
            .restoreReadOnly(names: ["新加卷 1", "SanDisk 32G"])
        )

        session = BottomProgress.removingRestore(session, id: "/dev/disk5s2")
        XCTAssertEqual(BottomProgress.kind(session), .restoreReadOnly(names: ["SanDisk 32G"]))

        session = BottomProgress.removingRestore(session, id: "/dev/disk4s2")
        XCTAssertNil(BottomProgress.kind(session))
    }

    func testRemountOutranksRestore() {
        var session = BottomProgress.Session()
        session = BottomProgress.insertingRestore(session, item("新加卷 1", "/dev/disk5s2"))
        session = BottomProgress.insertingRemount(session, item("SanDisk 32G", "/dev/disk4s2"))
        XCTAssertEqual(BottomProgress.kind(session), .remountReadWrite(names: ["SanDisk 32G"]))

        session = BottomProgress.removingRemount(session, id: "/dev/disk4s2")
        XCTAssertEqual(BottomProgress.kind(session), .restoreReadOnly(names: ["新加卷 1"]))
    }

    func testRestoreItemsOnlyTakeReadWrite() {
        let readOnly = sample(disk: "disk4s1", name: "Samsung USB", mounted: true, readOnly: true)
        let readWrite = sample(disk: "disk5s2", name: "新加卷 1", mounted: true, readOnly: false)
        let unmounted = sample(disk: "disk6s1", name: "Orphan", mounted: false, readOnly: true)
        let items = BottomProgress.restoreItems(from: [readOnly, readWrite, unmounted])
        XCTAssertEqual(items.map(\.id), ["/dev/disk5s2"])
        XCTAssertEqual(items.map(\.name), ["新加卷 1"])
    }

    func testDropsRestoreHintOnceDeviceIsReadOnly() {
        var session = BottomProgress.Session()
        session = BottomProgress.insertingRestores(session, [
            item("新加卷 1", "/dev/disk5s2"),
            item("SanDisk 32G", "/dev/disk4s2")
        ])
        let restored = sample(disk: "disk5s2", name: "新加卷 1", mounted: true, readOnly: true)
        let stillRW = sample(disk: "disk4s2", name: "SanDisk 32G", mounted: true, readOnly: false)
        session = BottomProgress.droppingFinishedRestores(session, devices: [restored, stillRW])
        XCTAssertEqual(BottomProgress.kind(session), .restoreReadOnly(names: ["SanDisk 32G"]))

        let sandiskRO = sample(disk: "disk4s2", name: "SanDisk 32G", mounted: true, readOnly: true)
        session = BottomProgress.droppingFinishedRestores(session, devices: [restored, sandiskRO])
        XCTAssertNil(BottomProgress.kind(session))
    }

    func testKeepsRestoreHintIfCardTemporarilyMissing() {
        var session = BottomProgress.Session()
        session = BottomProgress.insertingRestore(session, item("新加卷 1", "/dev/disk5s2"))
        session = BottomProgress.droppingFinishedRestores(session, devices: [])
        XCTAssertEqual(BottomProgress.kind(session), .restoreReadOnly(names: ["新加卷 1"]))
    }

    func testKeepsRestoreHintWhileStillReadWrite() {
        var session = BottomProgress.Session()
        session = BottomProgress.insertingRestore(session, item("新加卷 1", "/dev/disk5s2"))
        let stillRW = sample(disk: "disk5s2", name: "新加卷 1", mounted: true, readOnly: false)
        session = BottomProgress.droppingFinishedRestores(session, devices: [stillRW])
        XCTAssertEqual(BottomProgress.kind(session), .restoreReadOnly(names: ["新加卷 1"]))
    }

    func testManyRestoreTextJoinsNames() {
        let kind = BottomProgress.Kind.restoreReadOnly(names: ["新加卷 1", "SanDisk 32G"])
        let text = BottomProgress.text(kind) { key, params in
            if key == "messages.nameListSeparator" { return "、" }
            if key == "messages.restoringReadOnlyMany" {
                return "MANY \(params["count"] ?? "") \(params["names"] ?? "")"
            }
            return key
        }
        XCTAssertEqual(text, "MANY 2 新加卷 1、SanDisk 32G")
    }

    func testDoesNotDropOtherRestoreWhenDuplicateNames() {
        var session = BottomProgress.Session()
        session = BottomProgress.insertingRestores(session, [
            item("新加卷", "/dev/disk5s1"),
            item("新加卷", "/dev/disk5s2")
        ])
        let firstRO = sample(disk: "disk5s1", name: "新加卷", mounted: true, readOnly: true)
        let secondRW = sample(disk: "disk5s2", name: "新加卷", mounted: true, readOnly: false)
        session = BottomProgress.droppingFinishedRestores(session, devices: [firstRO, secondRW])
        XCTAssertEqual(BottomProgress.kind(session), .restoreReadOnly(names: ["新加卷"]))
    }

    func testMountItemsOnlyTakeUnmounted() {
        let readOnly = sample(disk: "disk4s1", name: "Samsung USB", mounted: true, readOnly: true)
        let unmounted = sample(disk: "disk6s1", name: "Orphan", mounted: false, readOnly: true)
        let items = BottomProgress.mountItems(from: [readOnly, unmounted])
        XCTAssertEqual(items.map(\.id), ["/dev/disk6s1"])
        XCTAssertEqual(items.map(\.name), ["Orphan"])
    }

    func testUnmountItemsOnlyTakeMounted() {
        let readOnly = sample(disk: "disk4s1", name: "Samsung USB", mounted: true, readOnly: true)
        let readWrite = sample(disk: "disk5s2", name: "新加卷 1", mounted: true, readOnly: false)
        let unmounted = sample(disk: "disk6s1", name: "Orphan", mounted: false, readOnly: true)
        let items = BottomProgress.unmountItems(from: [readOnly, readWrite, unmounted])
        XCTAssertEqual(items.map(\.id), ["/dev/disk4s1", "/dev/disk5s2"])
        XCTAssertEqual(items.map(\.name), ["Samsung USB", "新加卷 1"])
    }

    func testEjectItemsTakeEveryDevice() {
        let readOnly = sample(disk: "disk4s1", name: "Samsung USB", mounted: true, readOnly: true)
        let unmounted = sample(disk: "disk6s1", name: "Orphan", mounted: false, readOnly: true)
        let items = BottomProgress.ejectItems(from: [readOnly, unmounted])
        XCTAssertEqual(items.map(\.id), ["/dev/disk4s1", "/dev/disk6s1"])
    }

    func testDropsMountHintOnceDeviceIsReadWrite() {
        var session = BottomProgress.Session()
        session = BottomProgress.insertingMounts(session, [
            item("Orphan", "/dev/disk6s1"),
            item("Backup", "/dev/disk7s1")
        ])
        let mounted = sample(disk: "disk6s1", name: "Orphan", mounted: true, readOnly: false)
        let stillOff = sample(disk: "disk7s1", name: "Backup", mounted: false, readOnly: true)
        session = BottomProgress.droppingFinishedMounts(session, devices: [mounted, stillOff])
        XCTAssertEqual(BottomProgress.kind(session), .mount(names: ["Backup"]))
    }

    func testKeepsMountHintIfCardTemporarilyMissing() {
        var session = BottomProgress.Session()
        session = BottomProgress.insertingMount(session, item("Orphan", "/dev/disk6s1"))
        session = BottomProgress.droppingFinishedMounts(session, devices: [])
        XCTAssertEqual(BottomProgress.kind(session), .mount(names: ["Orphan"]))
    }

    func testDropsUnmountHintOnceDeviceIsUnmounted() {
        var session = BottomProgress.Session()
        session = BottomProgress.insertingUnmounts(session, [
            item("Samsung USB", "/dev/disk4s1"),
            item("新加卷 1", "/dev/disk5s2")
        ])
        let unmounted = sample(disk: "disk4s1", name: "Samsung USB", mounted: false, readOnly: true)
        let stillOn = sample(disk: "disk5s2", name: "新加卷 1", mounted: true, readOnly: false)
        session = BottomProgress.droppingFinishedUnmounts(session, devices: [unmounted, stillOn])
        XCTAssertEqual(BottomProgress.kind(session), .unmount(names: ["新加卷 1"]))
    }

    func testKeepsUnmountHintIfCardTemporarilyMissing() {
        var session = BottomProgress.Session()
        session = BottomProgress.insertingUnmount(session, item("Samsung USB", "/dev/disk4s1"))
        session = BottomProgress.droppingFinishedUnmounts(session, devices: [])
        XCTAssertEqual(BottomProgress.kind(session), .unmount(names: ["Samsung USB"]))
    }

    func testDropsEjectHintOnceCardLeavesNonEmptyList() {
        var session = BottomProgress.Session()
        session = BottomProgress.insertingEjects(session, [
            item("Samsung USB", "/dev/disk4s1"),
            item("新加卷 1", "/dev/disk5s2")
        ])
        let leftover = sample(disk: "disk5s2", name: "新加卷 1", mounted: true, readOnly: false)
        session = BottomProgress.droppingFinishedEjects(session, devices: [leftover])
        XCTAssertEqual(BottomProgress.kind(session), .eject(names: ["新加卷 1"]))
    }

    func testKeepsEjectHintIfListTemporarilyEmpty() {
        var session = BottomProgress.Session()
        session = BottomProgress.insertingEject(session, item("Samsung USB", "/dev/disk4s1"))
        session = BottomProgress.droppingFinishedEjects(session, devices: [])
        XCTAssertEqual(BottomProgress.kind(session), .eject(names: ["Samsung USB"]))
    }

    func testEjectOutranksRemount() {
        var session = BottomProgress.Session()
        session = BottomProgress.insertingRemount(session, item("Samsung USB", "/dev/disk4s1"))
        session = BottomProgress.insertingEject(session, item("新加卷 1", "/dev/disk5s2"))
        XCTAssertEqual(BottomProgress.kind(session), .eject(names: ["新加卷 1"]))

        session = BottomProgress.removingEject(session, id: "/dev/disk5s2")
        XCTAssertEqual(BottomProgress.kind(session), .remountReadWrite(names: ["Samsung USB"]))
    }

    func testUnmountOutranksMount() {
        var session = BottomProgress.Session()
        session = BottomProgress.insertingMount(session, item("Orphan", "/dev/disk6s1"))
        session = BottomProgress.insertingUnmount(session, item("Samsung USB", "/dev/disk4s1"))
        XCTAssertEqual(BottomProgress.kind(session), .unmount(names: ["Samsung USB"]))

        session = BottomProgress.removingUnmount(session, id: "/dev/disk4s1")
        XCTAssertEqual(BottomProgress.kind(session), .mount(names: ["Orphan"]))
    }

    func testManyMountTextJoinsNames() {
        let kind = BottomProgress.Kind.mount(names: ["Orphan", "Backup"])
        let text = BottomProgress.text(kind) { key, params in
            if key == "messages.nameListSeparator" { return "、" }
            if key == "messages.mountingMany" {
                return "MANY \(params["count"] ?? "") \(params["names"] ?? "")"
            }
            return key
        }
        XCTAssertEqual(text, "MANY 2 Orphan、Backup")
    }

    func testDoesNotDropOtherUnmountWhenDuplicateNames() {
        var session = BottomProgress.Session()
        session = BottomProgress.insertingUnmounts(session, [
            item("新加卷", "/dev/disk8s1"),
            item("新加卷", "/dev/disk8s2")
        ])
        let firstOff = sample(disk: "disk8s1", name: "新加卷", mounted: false, readOnly: true)
        let secondOn = sample(disk: "disk8s2", name: "新加卷", mounted: true, readOnly: true)
        session = BottomProgress.droppingFinishedUnmounts(session, devices: [firstOff, secondOn])
        XCTAssertEqual(BottomProgress.kind(session), .unmount(names: ["新加卷"]))
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
