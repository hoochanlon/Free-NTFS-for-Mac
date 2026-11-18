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

    func testNoMainWindowHostsConfirmOnTray() {
        XCTAssertEqual(QuitConfirmHost.decide(mainWindowVisible: false), .tray)
        XCTAssertEqual(QuitConfirmHost.decide(mainWindowVisible: true), .mainWindow)
    }

    func testWatchdogKeepsConfirmOnTrayWithoutMainWindow() {
        XCTAssertEqual(
            QuitConfirmWatchdog.decide(confirmOpen: true, mainWindowVisible: false, trayVisible: true),
            .keep
        )
    }

    func testWatchdogKeepsConfirmOnMainWindow() {
        XCTAssertEqual(
            QuitConfirmWatchdog.decide(confirmOpen: true, mainWindowVisible: true, trayVisible: false),
            .keep
        )
    }

    func testWatchdogExitsWhenConfirmLostItsHost() {
        XCTAssertEqual(
            QuitConfirmWatchdog.decide(confirmOpen: true, mainWindowVisible: false, trayVisible: false),
            .exit
        )
        XCTAssertEqual(
            QuitConfirmWatchdog.decide(confirmOpen: false, mainWindowVisible: false, trayVisible: true),
            .exit
        )
    }
}
