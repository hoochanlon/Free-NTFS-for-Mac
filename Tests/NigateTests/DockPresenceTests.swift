import XCTest
@testable import Nigate

final class DockPresenceTests: XCTestCase {
    func testIdleWithoutWindowDoesNotClaimDock() {
        XCTAssertEqual(
            DockPresence.action(phase: .idle, windowVisible: false, policyIsRegular: false),
            .leave
        )
    }

    func testIdleWithoutWindowDropsStaleDockIcon() {
        XCTAssertEqual(
            DockPresence.action(phase: .idle, windowVisible: false, policyIsRegular: true),
            .hide
        )
    }

    func testIdleWithWindowShowsDockOnce() {
        XCTAssertEqual(
            DockPresence.action(phase: .idle, windowVisible: true, policyIsRegular: false),
            .show
        )
        XCTAssertEqual(
            DockPresence.action(phase: .idle, windowVisible: true, policyIsRegular: true),
            .leave
        )
    }

    func testConfirmWithoutWindowExitsInsteadOfRestoringDock() {
        XCTAssertEqual(
            DockPresence.action(phase: .confirming, windowVisible: false, policyIsRegular: true),
            .exit
        )
        XCTAssertEqual(
            DockPresence.action(phase: .confirming, windowVisible: false, policyIsRegular: false),
            .exit
        )
    }

    func testConfirmKeepsVisibleWindow() {
        XCTAssertEqual(
            DockPresence.action(phase: .confirming, windowVisible: true, policyIsRegular: true),
            .leave
        )
    }

    func testExitingDoesNotTouchDock() {
        XCTAssertEqual(
            DockPresence.action(phase: .exiting, windowVisible: false, policyIsRegular: true),
            .leave
        )
        XCTAssertEqual(
            DockPresence.action(phase: .exiting, windowVisible: true, policyIsRegular: false),
            .leave
        )
    }

    func testExitPrepHidesWindowBeforeDroppingDock() {
        XCTAssertEqual(
            DockPresence.exitPrep(windowVisible: true, policyIsRegular: true),
            .hideWindowsThenDrop
        )
        XCTAssertEqual(
            DockPresence.exitPrep(windowVisible: true, policyIsRegular: false),
            .hideWindowsThenDrop
        )
    }

    func testExitPrepDropsStaleDockIconWithoutWindow() {
        XCTAssertEqual(
            DockPresence.exitPrep(windowVisible: false, policyIsRegular: true),
            .drop
        )
        XCTAssertEqual(
            DockPresence.exitPrep(windowVisible: false, policyIsRegular: false),
            .none
        )
    }
}
