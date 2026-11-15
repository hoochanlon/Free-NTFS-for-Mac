import XCTest
@testable import Nigate

final class AppVersionTests: XCTestCase {
    func testBundleVersionWinsOverSourcePlist() throws {
        let plist = try appPlist()
        XCTAssertEqual(AppVersion.resolve(bundleVersion: "9.9.9", sourcePlist: plist), "9.9.9")
    }

    func testUnexpandedBuildSettingFallsBackToSourcePlist() throws {
        let plist = try appPlist()
        let expected = try XCTUnwrap(AppVersion.shortVersion(in: plist))
        XCTAssertEqual(
            AppVersion.resolve(bundleVersion: "$(MARKETING_VERSION)", sourcePlist: plist),
            expected
        )
        XCTAssertEqual(AppVersion.resolve(bundleVersion: "  ", sourcePlist: plist), expected)
    }

    func testSourceWalkFindsAppPlistNotExtensionPlist() throws {
        let source = repoRoot()
            .appendingPathComponent("macos/Sources/Nigate/Domain/AppVersion.swift")
        let found = try XCTUnwrap(AppVersion.sourceInfoPlistURL(startingAt: source.path))
        XCTAssertEqual(found.standardizedFileURL, try appPlist().standardizedFileURL)
    }

    func testMissingVersionIsZero() {
        XCTAssertEqual(AppVersion.resolve(bundleVersion: nil, sourcePlist: nil), "0")
        XCTAssertNil(AppVersion.concrete("$(CURRENT_PROJECT_VERSION)"))
    }

    private func appPlist() throws -> URL {
        let plist = repoRoot().appendingPathComponent("macos/Info.plist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: plist.path))
        return plist
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
