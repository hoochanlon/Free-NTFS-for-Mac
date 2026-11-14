import XCTest
@testable import Nigate

final class FuseLibraryTests: XCTestCase {
    func testUsableRequiresBothDylibAndFilesystem() {
        let onlyDylib = FuseLibrary.inspect { $0 == FuseLibrary.installName }
        XCTAssertEqual(onlyDylib.dylibPath, FuseLibrary.installName)
        XCTAssertFalse(onlyDylib.filesystemPresent)
        XCTAssertFalse(onlyDylib.isUsable)
        XCTAssertNil(onlyDylib.dyldLibraryPath)

        let onlyFS = FuseLibrary.inspect { $0.contains("mount_macfuse") }
        XCTAssertNil(onlyFS.dylibPath)
        XCTAssertTrue(onlyFS.filesystemPresent)
        XCTAssertFalse(onlyFS.isUsable)

        let both = FuseLibrary.inspect {
            $0 == FuseLibrary.installName || $0.contains("mount_macfuse")
        }
        XCTAssertTrue(both.isUsable)
        XCTAssertNil(both.dyldLibraryPath)
    }

    func testHomebrewDylibNeedsDyldOverride() {
        let snapshot = FuseLibrary.inspect {
            $0 == "/opt/homebrew/lib/libfuse.2.dylib" || $0.contains("load_macfuse")
        }
        XCTAssertTrue(snapshot.isUsable)
        XCTAssertEqual(snapshot.dylibPath, "/opt/homebrew/lib/libfuse.2.dylib")
        XCTAssertEqual(snapshot.dyldLibraryPath, "/opt/homebrew/lib")
    }

    func testLaunchEnvEmptyWhenInstallNameExists() throws {
        let env = try FuseLibrary.launchEnv {
            $0 == FuseLibrary.installName || $0.contains("mount_macfuse")
        }
        XCTAssertTrue(env.isEmpty)
    }

    func testLaunchEnvInjectsDyldWhenLibraryIsElsewhere() throws {
        let env = try FuseLibrary.launchEnv {
            $0 == "/opt/homebrew/lib/libfuse.2.dylib" || $0.contains("mount_macfuse")
        }
        XCTAssertEqual(env["DYLD_LIBRARY_PATH"], "/opt/homebrew/lib")
        XCTAssertEqual(env["DYLD_FALLBACK_LIBRARY_PATH"], "/opt/homebrew/lib")
    }

    func testLaunchEnvThrowsWhenIncomplete() {
        XCTAssertThrowsError(try FuseLibrary.launchEnv { _ in false }) { error in
            guard case AppError.macfuseMissing = error else {
                return XCTFail("expected macfuseMissing, got \(error)")
            }
        }
    }

    func testDetectsNtfs3gDyldError() {
        let sample = """
        dyld[48297]: Library not loaded: /usr/local/lib/libfuse.2.dylib
        Referenced from: /opt/homebrew/Cellar/ntfs-3g-mac/2026.9.28/bin/ntfs-3g
        Reason: tried: '/usr/local/lib/libfuse.2.dylib' (no such file)
        """
        XCTAssertTrue(FuseLibrary.isMissingLibraryError(sample))
        XCTAssertFalse(FuseLibrary.isMissingLibraryError("ntfs-3g: failed to mount /dev/disk4s1"))
        XCTAssertFalse(FuseLibrary.isMissingLibraryError("Library not loaded: /usr/lib/libfoo.dylib"))
    }

    func testBrewCaskListingIsNotAUsabilitySignal() {
        // 回归：仅 Caskroom / brew list 不能当成已安装。
        let snapshot = FuseLibrary.inspect { path in
            path.contains("Caskroom/macfuse")
        }
        XCTAssertFalse(snapshot.isUsable)
        XCTAssertNil(snapshot.dylibPath)
        XCTAssertFalse(snapshot.filesystemPresent)
    }
}
