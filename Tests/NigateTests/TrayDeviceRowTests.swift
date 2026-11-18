import XCTest
@testable import Nigate

final class TrayDeviceRowTests: XCTestCase {
    func testUnmountedRowWithoutCapacityKeepsNameAndStatus() {
        let device = sample(mounted: false, capacity: nil)
        XCTAssertNil(TrayDeviceRow.capacityLine(device))
        XCTAssertEqual(TrayDeviceRow.accessibilityLabel(device, status: "已卸载"), "新加卷, 已卸载")
    }

    func testMountedRowWithoutCapacityKeepsNameAndStatus() {
        let device = sample(mounted: true, capacity: nil)
        XCTAssertNil(TrayDeviceRow.capacityLine(device))
        XCTAssertEqual(TrayDeviceRow.accessibilityLabel(device, status: "可读写"), "新加卷, 可读写")
    }

    func testCapacityLineMatchesMainInterface() {
        let previous = L10n.language
        L10n.apply(.zhCN)
        defer { L10n.apply(previous) }

        let capacity = cap(total: 32_011_000_000, used: 8_581_000_000, available: 23_430_000_000)
        let mounted = sample(mounted: true, capacity: capacity)
        let unmounted = sample(mounted: false, capacity: capacity)

        XCTAssertEqual(TrayDeviceRow.capacityLine(mounted), CapacityText.summary(capacity))
        XCTAssertEqual(TrayDeviceRow.capacityLine(unmounted), CapacityText.summary(capacity))
        XCTAssertTrue(CapacityText.summary(capacity).contains(L10n.t("devices.available")))
        XCTAssertTrue(CapacityText.summary(capacity).contains(L10n.t("devices.total")))
        XCTAssertTrue(CapacityText.summary(capacity).contains(L10n.t("devices.usageRate")))
        XCTAssertTrue(CapacityText.summary(capacity).contains(capacity.usedPercentLabel))
    }
}

final class TrayPanelPlacementTests: XCTestCase {
    private let visible = CGRect(x: 0, y: 0, width: 1440, height: 878)
    private let size = CGSize(width: TrayLayout.width, height: 320)

    func testEstimatedHeightGrowsWithDevices() {
        let one = TrayLayout.estimatedHeight(deviceCount: 1, hasHint: false)
        let two = TrayLayout.estimatedHeight(deviceCount: 2, hasHint: false)
        XCTAssertEqual(two - one, TrayLayout.cardHeight + TrayLayout.cardGap, accuracy: 0.5)
        XCTAssertEqual(two, TrayLayout.estimatedHeight(deviceCount: 4, hasHint: false), accuracy: 0.5)
        XCTAssertEqual(
            TrayLayout.estimatedHeight(deviceCount: 4, hasHint: false),
            TrayLayout.estimatedHeight(deviceCount: 6, hasHint: false),
            accuracy: 0.5
        )
        XCTAssertEqual(
            TrayLayout.estimatedHeight(deviceCount: 1, hasHint: true) - one,
            30,
            accuracy: 0.5
        )
    }

    func testFourOrMoreDevicesScrollInsteadOfGrowing() {
        XCTAssertFalse(TrayLayout.needsScroll(1))
        XCTAssertFalse(TrayLayout.needsScroll(2))
        XCTAssertTrue(TrayLayout.needsScroll(3))
        XCTAssertTrue(TrayLayout.needsScroll(4))
        XCTAssertEqual(TrayLayout.listHeight(deviceCount: 4), TrayLayout.defaultListHeight, accuracy: 0.5)
        XCTAssertEqual(TrayLayout.listHeight(deviceCount: 2), TrayLayout.defaultListHeight, accuracy: 0.5)
        XCTAssertLessThan(TrayLayout.listHeight(deviceCount: 1), TrayLayout.defaultListHeight)
    }

    func testBottomDragCapsAtFourCards() {
        let two = TrayListResize.minListHeight(deviceCount: 6)
        let four = TrayListResize.maxListHeight(deviceCount: 6)
        XCTAssertEqual(two, TrayLayout.defaultListHeight, accuracy: 0.5)
        XCTAssertEqual(four, TrayLayout.maxListHeight, accuracy: 0.5)
        XCTAssertEqual(four - two, 2 * (TrayLayout.cardHeight + TrayLayout.cardGap), accuracy: 0.5)
        XCTAssertEqual(TrayListResize.clamp(0, deviceCount: 6), two, accuracy: 0.5)
        XCTAssertEqual(TrayListResize.clamp(10_000, deviceCount: 6), four, accuracy: 0.5)
        XCTAssertFalse(TrayListResize.canResize(deviceCount: 0))
        XCTAssertFalse(TrayListResize.canResize(deviceCount: 1))
        XCTAssertFalse(TrayListResize.canResize(deviceCount: 2))
        XCTAssertTrue(TrayListResize.canResize(deviceCount: 3))
        XCTAssertTrue(TrayListResize.canResize(deviceCount: 4))
        XCTAssertEqual(
            TrayListResize.maxListHeight(deviceCount: 3),
            TrayLayout.listHeight(deviceCount: 3, limit: 4),
            accuracy: 0.5
        )
        XCTAssertLessThan(TrayListResize.maxListHeight(deviceCount: 3), four)
    }

    func testMaxStretchStopsAtMeasuredCards() {
        let measured: CGFloat = 400
        XCTAssertEqual(
            TrayListResize.maxListHeight(deviceCount: 4, contentHeight: measured),
            measured,
            accuracy: 0.5
        )
        XCTAssertEqual(
            TrayListResize.clamp(10_000, deviceCount: 4, contentHeight: measured),
            measured,
            accuracy: 0.5
        )
        let card = (measured - 3 * TrayLayout.cardGap) / 4
        XCTAssertEqual(
            TrayListResize.minListHeight(deviceCount: 4, contentHeight: measured),
            2 * card + TrayLayout.cardGap,
            accuracy: 0.5
        )
        XCTAssertLessThan(
            TrayListResize.maxListHeight(deviceCount: 6, contentHeight: 600),
            600
        )
    }

    func testCentersUnderStatusItemWhenItFits() {
        let button = CGRect(x: 700, y: 878, width: 22, height: 22)
        let origin = TrayPanelPlacement.origin(button: button, size: size, visible: visible)
        XCTAssertEqual(origin.x + size.width / 2, button.midX, accuracy: 0.5)
        XCTAssertEqual(origin.y + size.height, button.minY - TrayPanelPlacement.gap, accuracy: 0.5)
    }

    func testTopEdgeStaysGluedWhenHeightChanges() {
        let button = CGRect(x: 700, y: 878, width: 22, height: 22)
        let short = TrayPanelPlacement.origin(
            button: button,
            size: CGSize(width: TrayLayout.width, height: 200),
            visible: visible
        )
        let tall = TrayPanelPlacement.origin(
            button: button,
            size: CGSize(width: TrayLayout.width, height: 500),
            visible: visible
        )
        let expectedTop = button.minY - TrayPanelPlacement.gap
        XCTAssertEqual(short.y + 200, expectedTop, accuracy: 0.5)
        XCTAssertEqual(tall.y + 500, expectedTop, accuracy: 0.5)
    }

    func testAttachesToVisibleTopWhenButtonSitsInsideMenuBar() {
        let button = CGRect(x: 700, y: 880, width: 22, height: 22)
        let origin = TrayPanelPlacement.origin(button: button, size: size, visible: visible)
        XCTAssertEqual(origin.y + size.height, visible.maxY - TrayPanelPlacement.gap, accuracy: 0.5)
    }

    func testNearRightEdgeIsClamped() {
        let button = CGRect(x: 1420, y: 878, width: 22, height: 22)
        let origin = TrayPanelPlacement.origin(button: button, size: size, visible: visible)
        XCTAssertLessThan(origin.x + size.width / 2, button.midX)
        XCTAssertGreaterThanOrEqual(origin.x, visible.minX + TrayPanelPlacement.screenPad)
        XCTAssertLessThanOrEqual(origin.x + size.width, visible.maxX - TrayPanelPlacement.screenPad)
    }

    func testNearLeftEdgeIsClamped() {
        let button = CGRect(x: 8, y: 878, width: 22, height: 22)
        let origin = TrayPanelPlacement.origin(button: button, size: size, visible: visible)
        XCTAssertGreaterThan(origin.x + size.width / 2, button.midX)
        XCTAssertGreaterThanOrEqual(origin.x, visible.minX + TrayPanelPlacement.screenPad)
    }

    func testTallPanelDoesNotGoBelowVisibleArea() {
        let button = CGRect(x: 200, y: 200, width: 22, height: 22)
        let tall = CGSize(width: TrayLayout.width, height: 500)
        let origin = TrayPanelPlacement.origin(button: button, size: tall, visible: visible)
        XCTAssertGreaterThanOrEqual(origin.y, visible.minY + TrayPanelPlacement.screenPad)
    }
}

final class TrayBatchAvailabilityTests: XCTestCase {
    func testMountUnmountedOnlyWhenNeedsMount() {
        XCTAssertTrue(TrayBatchAvailability.canMountUnmounted([sample(mounted: false, readOnly: true)]))
        XCTAssertFalse(TrayBatchAvailability.canMountUnmounted([sample(mounted: true, readOnly: true)]))
        XCTAssertFalse(TrayBatchAvailability.canMountUnmounted([]))
    }

    func testMountReadOnlyOnlyWhenMountedReadOnly() {
        XCTAssertTrue(TrayBatchAvailability.canMountReadOnly([sample(mounted: true, readOnly: true)]))
        XCTAssertFalse(TrayBatchAvailability.canMountReadOnly([sample(mounted: true, readOnly: false)]))
        XCTAssertFalse(TrayBatchAvailability.canMountReadOnly([sample(mounted: false, readOnly: true)]))
    }

    func testRestoreOnlyWhenReadWrite() {
        XCTAssertTrue(TrayBatchAvailability.canRestore([sample(mounted: true, readOnly: false)]))
        XCTAssertFalse(TrayBatchAvailability.canRestore([sample(mounted: true, readOnly: true)]))
        XCTAssertFalse(TrayBatchAvailability.canRestore([sample(mounted: false, readOnly: true)]))
    }

    func testUnmountWhenMounted() {
        XCTAssertTrue(TrayBatchAvailability.canUnmount([sample(mounted: true, readOnly: true)]))
        XCTAssertFalse(TrayBatchAvailability.canUnmount([sample(mounted: false, readOnly: true)]))
    }

    func testEjectWhenListIsNotEmpty() {
        XCTAssertTrue(TrayBatchAvailability.canEject([sample(mounted: false, readOnly: true)]))
        XCTAssertFalse(TrayBatchAvailability.canEject([]))
    }

    private func sample(mounted: Bool, readOnly: Bool) -> NTFSDevice {
        NTFSDevice(
            disk: "disk4s1",
            devicePath: "/dev/disk4s1",
            volume: mounted ? "/Volumes/新加卷" : "",
            volumeName: "新加卷",
            volumeUuid: nil,
            isReadOnly: readOnly,
            options: "",
            isMounted: mounted,
            isUnmounted: !mounted,
            canFormat: false,
            capacity: nil
        )
    }
}

private func sample(mounted: Bool, capacity: Capacity?) -> NTFSDevice {
    NTFSDevice(
        disk: "disk4s1",
        devicePath: "/dev/disk4s1",
        volume: mounted ? "/Volumes/新加卷" : "",
        volumeName: "新加卷",
        volumeUuid: nil,
        isReadOnly: !mounted,
        options: "",
        isMounted: mounted,
        isUnmounted: !mounted,
        canFormat: false,
        capacity: capacity
    )
}

private func cap(
    total: Int64 = 32_011_000_000,
    used: Int64 = 8_581_000_000,
    available: Int64 = 23_430_000_000
) -> Capacity {
    Capacity(total: total, used: used, available: available)
}
