import XCTest
@testable import Nigate

final class SleepGuardTests: XCTestCase {
    func testIgnoresIostatHeaders() {
        let text = """
                      disk4
            KB/t  tps  MB/s
        """
        XCTAssertTrue(SleepIOStats.numericRows(in: text).isEmpty)
    }

    func testParsesDeviceRows() {
        let text = """
           16.00    0  0.00
           12.50   24  0.30
        """
        let rows = SleepIOStats.numericRows(in: text)
        XCTAssertEqual(rows.count, 2)
        XCTAssertFalse(SleepIOStats.isBusy(rows[0]))
        XCTAssertTrue(SleepIOStats.isBusy(rows[1]))
    }

    func testIdleMetadataIsNotATransfer() {
        XCTAssertFalse(SleepIOStats.isBusy([16, 1, 0.01]))
        XCTAssertFalse(SleepIOStats.isBusy([16, 7, 0.09]))
    }

    func testCopyThroughputCountsAsBusy() {
        XCTAssertTrue(SleepIOStats.isBusy([32, 40, 1.2]))
        XCTAssertTrue(SleepIOStats.isBusy([16, 8, 0.0]))
        XCTAssertTrue(SleepIOStats.isBusy([64, 0, 0.1]))
    }

    func testUptimeAverageLooksBusyAndMustBeSkippedByCaller() {
        // iostat 第一行是开机平均，智能模式必须丢掉这一行。
        XCTAssertTrue(SleepIOStats.isBusy([27.80, 753, 20.43]))
    }
}
