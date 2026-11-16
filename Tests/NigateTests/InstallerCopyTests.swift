import XCTest
@testable import Nigate

final class InstallerCopyTests: XCTestCase {
    func testOneClickScopeIsBrewPackagesOnly() {
        for language: AppLanguage in [.zhCN, .zhTW, .en, .ja, .de] {
            let copy = InstallerCopy.resolve(language)
            XCTAssertTrue(copy.scope.contains("MacFUSE"), "\(language)")
            XCTAssertTrue(copy.scope.contains("ntfs-3g"), "\(language)")
            XCTAssertFalse(copy.scope.contains("Xcode"), "\(language)")
            XCTAssertTrue(copy.excluded.contains("Xcode"), "\(language)")
            XCTAssertTrue(copy.excluded.contains("Homebrew"), "\(language)")
            XCTAssertTrue(copy.missingCLT.contains("xcode-select --install"), "\(language)")
            XCTAssertTrue(copy.missingBrew.contains("https://brew.sh"), "\(language)")
        }
    }
}
