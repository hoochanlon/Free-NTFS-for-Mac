import XCTest
@testable import Nigate

final class CapacityFillTests: XCTestCase {
    func testBelowEightyStaysNormal() {
        XCTAssertEqual(fill(used: 0, total: 100).fillLevel, .normal)
        XCTAssertEqual(fill(used: 79, total: 100).fillLevel, .normal)
    }

    func testEightyIsWarningUntilNinety() {
        XCTAssertEqual(fill(used: 80, total: 100).fillLevel, .warning)
        XCTAssertEqual(fill(used: 89, total: 100).fillLevel, .warning)
    }

    func testNinetyAndAboveIsCritical() {
        XCTAssertEqual(fill(used: 90, total: 100).fillLevel, .critical)
        XCTAssertEqual(fill(used: 100, total: 100).fillLevel, .critical)
    }

    func testUsedPercentMatchesTheBar() {
        XCTAssertEqual(fill(used: 0, total: 100).usedPercentLabel, "0%")
        XCTAssertEqual(fill(used: 1, total: 1000).usedPercentLabel, "<1%")
        XCTAssertEqual(fill(used: 88, total: 100).usedPercentLabel, "88%")
        XCTAssertEqual(fill(used: 150, total: 100).usedPercentLabel, "100%")
    }

    func testScreenshotNearlyFullDiskIsCritical() {
        let total: Int64 = 30_550_000_000
        let available: Int64 = 3_020_000_000
        XCTAssertEqual(fill(used: total - available, total: total).fillLevel, .critical)
    }

    private func fill(used: Int64, total: Int64) -> Capacity {
        Capacity(total: total, used: used, available: max(0, total - used))
    }
}
