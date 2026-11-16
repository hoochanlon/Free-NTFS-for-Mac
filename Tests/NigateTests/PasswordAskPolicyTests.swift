import XCTest
@testable import Nigate

final class PasswordAskPolicyTests: XCTestCase {
    override func tearDown() {
        PasswordMemory.forget()
        super.tearDown()
    }

    func testRememberedPasswordIsUsedOnlyWhenSaveIsOn() {
        XCTAssertEqual(
            PasswordAskPolicy.decide(savePassword: true, remembered: "secret"),
            .useRemembered("secret")
        )
    }

    func testAskEveryTimeIgnoresMemory() {
        XCTAssertEqual(
            PasswordAskPolicy.decide(savePassword: false, remembered: "secret"),
            .prompt
        )
    }

    func testEmptyOrMissingMemoryStillPrompts() {
        XCTAssertEqual(
            PasswordAskPolicy.decide(savePassword: true, remembered: nil),
            .prompt
        )
        XCTAssertEqual(
            PasswordAskPolicy.decide(savePassword: true, remembered: ""),
            .prompt
        )
    }

    func testSessionMemoryDoesNotSurviveForget() {
        PasswordMemory.remember("secret")
        XCTAssertEqual(PasswordMemory.read(), "secret")
        PasswordMemory.forget()
        XCTAssertNil(PasswordMemory.read())
    }
}
