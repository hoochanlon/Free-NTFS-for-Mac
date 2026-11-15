import XCTest
@testable import Nigate

final class CapacityRefreshTests: XCTestCase {
    func testNoSampleLeavesListUntouched() {
        let device = sample(mounted: true, capacity: cap(available: 6_420_000_000))
        XCTAssertNil(CapacityRefresh.applying([device], samples: [:]))
    }

    func testSameCapacityDoesNotPublish() {
        let capacity = cap(available: 6_420_000_000)
        let device = sample(mounted: true, capacity: capacity)
        XCTAssertNil(CapacityRefresh.applying([device], samples: [device.devicePath: capacity]))
    }

    func testMountedCardTakesNewAvailable() {
        let device = sample(mounted: true, capacity: cap(available: 6_420_000_000))
        let next = cap(available: 8_200_000_000)
        let applied = CapacityRefresh.applying([device], samples: [device.devicePath: next])
        XCTAssertEqual(applied?.map(\.capacity), [next])
    }

    func testUnmountedCardIgnoresSample() {
        let device = sample(mounted: false, capacity: cap(available: 6_420_000_000))
        XCTAssertNil(CapacityRefresh.applying([device], samples: [device.devicePath: cap(available: 8_200_000_000)]))
    }

    func testOtherCardsStayPut() {
        let stale = sample(disk: "disk5s2", mounted: true, capacity: cap(available: 6_420_000_000))
        let other = sample(disk: "disk4s1", mounted: true, capacity: cap(available: 127_790_000_000))
        let next = cap(available: 8_200_000_000)
        let applied = CapacityRefresh.applying([other, stale], samples: [stale.devicePath: next])
        XCTAssertEqual(applied?.map(\.devicePath), [other.devicePath, stale.devicePath])
        XCTAssertEqual(applied?[0].capacity, other.capacity)
        XCTAssertEqual(applied?[1].capacity, next)
    }

    private func cap(available: Int64) -> Capacity {
        let total: Int64 = 30_550_000_000
        return Capacity(total: total, used: total - available, available: available)
    }

    private func sample(disk: String = "disk5s2", mounted: Bool, capacity: Capacity) -> NTFSDevice {
        NTFSDevice(
            disk: disk,
            devicePath: "/dev/\(disk)",
            volume: mounted ? "/Volumes/SanDisk 32G" : "",
            volumeName: "SanDisk 32G",
            volumeUuid: nil,
            partitionUuid: nil,
            isReadOnly: false,
            options: "",
            isMounted: mounted,
            isUnmounted: !mounted,
            canFormat: true,
            capacity: capacity
        )
    }
}
