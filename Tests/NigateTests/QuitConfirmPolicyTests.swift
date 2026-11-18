import XCTest
@testable import Nigate

final class QuitConfirmPolicyTests: XCTestCase {
    func testTrayQuitAlwaysPresentsConfirm() {
        XCTAssertEqual(QuitRequest.decide(phase: .idle, didHardExit: false), .presentConfirm)
        XCTAssertEqual(QuitRequest.decide(phase: .confirming, didHardExit: false), .presentConfirm)
    }

    func testExitingSkipsConfirm() {
        XCTAssertEqual(QuitRequest.decide(phase: .exiting, didHardExit: false), .exitNow)
        XCTAssertEqual(QuitRequest.decide(phase: .idle, didHardExit: true), .exitNow)
    }

    func testWatchdogKeepsConfirmOnMainWindow() {
        XCTAssertEqual(
            QuitConfirmWatchdog.decide(confirmOpen: true, mainWindowVisible: true),
            .keep
        )
    }

    func testWatchdogExitsWhenConfirmLostItsHost() {
        XCTAssertEqual(
            QuitConfirmWatchdog.decide(confirmOpen: true, mainWindowVisible: false),
            .exit
        )
        XCTAssertEqual(
            QuitConfirmWatchdog.decide(confirmOpen: false, mainWindowVisible: true),
            .exit
        )
    }
}
