import XCTest
@testable import Nigate

final class PathLookupTests: XCTestCase {
    func testStaleCacheIsDropped() {
        XCTAssertNil(PathLookup.acceptedCache("/opt/homebrew/bin/ntfs-3g", validate: { _ in false }))
        XCTAssertNil(PathLookup.acceptedCache("", validate: { _ in true }))
        XCTAssertNil(PathLookup.acceptedCache(nil, validate: { _ in true }))
    }

    func testValidCacheIsKept() {
        XCTAssertEqual(
            PathLookup.acceptedCache("/opt/homebrew/bin/ntfs-3g") { $0.hasSuffix("ntfs-3g") },
            "/opt/homebrew/bin/ntfs-3g"
        )
    }

    func testWellKnownPathsCoverOptKegs() {
        let paths = PathLookup.wellKnownNTFS3GPaths
        XCTAssertTrue(paths.contains("/opt/homebrew/opt/ntfs-3g-mac/bin/ntfs-3g"))
        XCTAssertTrue(paths.contains("/opt/homebrew/opt/ntfs-3g/sbin/ntfs-3g"))
        XCTAssertTrue(paths.contains("/usr/local/opt/ntfs-3g-mac/bin/ntfs-3g"))
        XCTAssertTrue(paths.contains("/usr/local/opt/ntfs-3g/bin/ntfs-3g"))
    }
}
