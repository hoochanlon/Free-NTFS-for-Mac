import XCTest
@testable import Nigate

final class HelpBubbleLayoutTests: XCTestCase {
    private let window = CGSize(width: 900, height: 680)
    private let bubble = CGSize(width: 260, height: 64)
    private let chip = CGSize(width: 72, height: 28)

    func testCentersUnderHostWhenItFits() {
        let host = CGRect(x: 400, y: 12, width: 22, height: 22)
        let origin = HelpBubbleLayout.origin(host: host, bubble: chip, window: window)
        XCTAssertEqual(origin.x + chip.width / 2, host.midX, accuracy: 0.5)
        XCTAssertEqual(origin.y, host.maxY + HelpBubbleLayout.gap, accuracy: 0.5)
    }

    func testWideBubbleCentersUnderToolbarButtonWhenItFits() {
        let host = CGRect(x: 680, y: 80, width: 88, height: 24)
        let origin = HelpBubbleLayout.origin(host: host, bubble: bubble, window: window)
        XCTAssertEqual(origin.x + bubble.width / 2, host.midX, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(origin.x, HelpBubbleLayout.pad)
        XCTAssertLessThanOrEqual(origin.x + bubble.width, window.width - HelpBubbleLayout.pad)
    }

    func testNearRightEdgeIsClamped() {
        let host = CGRect(x: 870, y: 12, width: 22, height: 22)
        let origin = HelpBubbleLayout.origin(host: host, bubble: bubble, window: window)
        XCTAssertLessThan(origin.x + bubble.width / 2, host.midX)
        XCTAssertGreaterThanOrEqual(origin.x, HelpBubbleLayout.pad)
        XCTAssertLessThanOrEqual(origin.x + bubble.width, window.width - HelpBubbleLayout.pad)
        XCTAssertGreaterThanOrEqual(origin.y, HelpBubbleLayout.pad)
        XCTAssertLessThanOrEqual(origin.y + bubble.height, window.height - HelpBubbleLayout.pad)
    }

    func testNearLeftEdgeIsClamped() {
        let host = CGRect(x: 8, y: 80, width: 22, height: 22)
        let origin = HelpBubbleLayout.origin(host: host, bubble: bubble, window: window)
        XCTAssertGreaterThan(origin.x + bubble.width / 2, host.midX)
        XCTAssertGreaterThanOrEqual(origin.x, HelpBubbleLayout.pad)
        XCTAssertLessThanOrEqual(origin.x + bubble.width, window.width - HelpBubbleLayout.pad)
    }

    func testFlipsAboveWhenNotEnoughRoomBelow() {
        let host = CGRect(x: 40, y: 630, width: 40, height: 24)
        let origin = HelpBubbleLayout.origin(host: host, bubble: bubble, window: window)
        XCTAssertLessThanOrEqual(origin.y + bubble.height, host.minY)
        XCTAssertGreaterThanOrEqual(origin.y, HelpBubbleLayout.pad)
    }

    func testGermanReadOnlyLabelHugsContentInsteadOfStretching() {
        // "Alle schreibgeschützt" 字数超过旧阈值 18，但仍是单行短标签。
        let german = CGFloat("Alle schreibgeschützt".count)
        XCTAssertGreaterThan(german, 18)
        XCTAssertEqual(HelpBubbleLayout.fittedWidth(168), 168)
        XCTAssertLessThan(HelpBubbleLayout.fittedWidth(168), HelpBubbleLayout.maxWidth)
    }

    func testLongHintCapsAtMaxWidth() {
        XCTAssertEqual(HelpBubbleLayout.fittedWidth(480), HelpBubbleLayout.maxWidth)
        XCTAssertEqual(HelpBubbleLayout.fittedWidth(0), 0)
        XCTAssertEqual(HelpBubbleLayout.fittedWidth(-10), 0)
    }
}
