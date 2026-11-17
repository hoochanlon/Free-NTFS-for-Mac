import XCTest
@testable import Nigate

final class DependencyStatusTests: XCTestCase {
    func testUncheckedDefaultsAreNotMissingCore() {
        XCTAssertFalse(DependencyStatus().isProbed)
        XCTAssertFalse(DependencyStatus().missingCore)
    }

    func testProbedAbsenceIsMissingCore() {
        var status = DependencyStatus()
        status.isProbed = true
        XCTAssertTrue(status.missingCore)
    }

    func testProbedCorePresentIsNotMissing() {
        var status = DependencyStatus()
        status.isProbed = true
        status.macosVersion = true
        status.macfuse = true
        status.ntfs3g = true
        XCTAssertFalse(status.missingCore)
    }
}
