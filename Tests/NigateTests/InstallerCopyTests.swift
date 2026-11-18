import XCTest
@testable import Nigate

final class InstallerCopyTests: XCTestCase {
    func testOneClickScopeCoversFullChain() {
        for language: AppLanguage in [.zhCN, .zhTW, .en, .ja, .de] {
            let copy = InstallerCopy.resolve(language)
            XCTAssertTrue(copy.scope.contains("MacFUSE"), "\(language)")
            XCTAssertTrue(copy.scope.contains("ntfs-3g"), "\(language)")
            XCTAssertTrue(copy.scope.contains("Homebrew"), "\(language)")
            XCTAssertTrue(copy.scope.contains("Xcode"), "\(language)")
            XCTAssertTrue(copy.installingCLT.contains("Xcode") || copy.installingCLT.contains("Command Line"), "\(language)")
            XCTAssertTrue(copy.installingBrew.contains("Homebrew"), "\(language)")
            XCTAssertFalse(copy.scope.isEmpty, "\(language)")
        }
    }

    func testGeneratedScriptInstallsCLTAndBrew() {
        let script = Installer.dependencyScript(language: .en)
        XCTAssertTrue(script.contains("xcode-select --install"))
        XCTAssertTrue(script.contains("NONINTERACTIVE=1"))
        XCTAssertTrue(script.contains("https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"))
        XCTAssertTrue(script.contains("https://gitee.com/ineo6/homebrew-install/raw/master/install.sh"))
        XCTAssertTrue(script.contains("macfuse"))
        XCTAssertTrue(script.contains("ntfs-3g"))
        XCTAssertFalse(script.contains("spctl --master-disable"))
        XCTAssertFalse(script.contains("cannot install them"))
        XCTAssertFalse(script.contains("This script cannot install"))
    }
}
