import XCTest
@testable import Nigate

final class DeviceScanCommitTests: XCTestCase {
    func testConfirmStillPublishesDeviceCards() {
        XCTAssertEqual(DeviceScanCommit.decide(.confirming), .publishWithoutSideEffects)
        XCTAssertTrue(DeviceScanCommit.decide(.confirming).allowsScan)
    }

    func testIdlePublishesAndContinues() {
        XCTAssertEqual(DeviceScanCommit.decide(.idle), .publish)
        XCTAssertTrue(DeviceScanCommit.decide(.idle).allowsScan)
    }

    func testExitDropsTheScan() {
        XCTAssertEqual(DeviceScanCommit.decide(.exiting), .drop)
        XCTAssertFalse(DeviceScanCommit.decide(.exiting).allowsScan)
    }

    func testConfirmDoesNotShowEmptyBeforeFirstScan() {
        XCTAssertEqual(
            DeviceListAppearance.decide(
                deviceCount: 0,
                isScanning: false,
                didFinish: false,
                rescanPending: false,
                quitPhase: .confirming
            ),
            .scanning
        )
    }

    func testConfirmWithPendingRescanStaysScanning() {
        XCTAssertEqual(
            DeviceListAppearance.decide(
                deviceCount: 0,
                isScanning: false,
                didFinish: true,
                rescanPending: true,
                quitPhase: .confirming
            ),
            .scanning
        )
    }

    func testIdleEmptyAfterScanShowsEmpty() {
        XCTAssertEqual(
            DeviceListAppearance.decide(
                deviceCount: 0,
                isScanning: false,
                didFinish: true,
                rescanPending: false,
                quitPhase: .idle
            ),
            .empty
        )
    }

    func testCardsWinOverQuitConfirm() {
        XCTAssertEqual(
            DeviceListAppearance.decide(
                deviceCount: 2,
                isScanning: false,
                didFinish: true,
                rescanPending: true,
                quitPhase: .confirming
            ),
            .cards
        )
    }
}
