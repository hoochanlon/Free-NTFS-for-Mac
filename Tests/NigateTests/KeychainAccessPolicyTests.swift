import XCTest
import Security
@testable import Nigate

final class KeychainAccessPolicyTests: XCTestCase {
    func testEmptySelectorDoesNotNeedRewrite() {
        XCTAssertFalse(KeychainAccessPolicy.shouldRewritePromptSelector([]))
    }

    func testUnsignedSelectorNeedsRewrite() {
        XCTAssertTrue(KeychainAccessPolicy.shouldRewritePromptSelector(.unsigned))
        XCTAssertTrue(KeychainAccessPolicy.shouldRewritePromptSelector([.unsigned, .unsignedAct]))
    }

    func testPassphraseSelectorNeedsRewrite() {
        XCTAssertTrue(KeychainAccessPolicy.shouldRewritePromptSelector(.requirePassphase))
    }
}
