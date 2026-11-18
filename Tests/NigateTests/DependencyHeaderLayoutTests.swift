import XCTest
@testable import Nigate

final class DependencyHeaderLayoutTests: XCTestCase {
    func testChineseKeepsTitleAndActionsOnOneRow() {
        XCTAssertEqual(DependencyHeaderLayout.resolve(.zhCN), .inline)
        XCTAssertEqual(DependencyHeaderLayout.resolve(.zhTW), .inline)
    }

    func testLongerLocalesMoveActionsUnderTitle() {
        XCTAssertEqual(DependencyHeaderLayout.resolve(.en), .stacked)
        XCTAssertEqual(DependencyHeaderLayout.resolve(.ja), .stacked)
        XCTAssertEqual(DependencyHeaderLayout.resolve(.de), .stacked)
    }
}
