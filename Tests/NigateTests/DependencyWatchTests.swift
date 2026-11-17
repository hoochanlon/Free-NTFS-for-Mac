import XCTest
@testable import Nigate

final class DependencyWatchTests: XCTestCase {
    func testWatchRootsCoverFuseAndHomebrewBins() {
        let dirs = DependencyWatch.directories()
        XCTAssertTrue(dirs.contains("/Library/Filesystems"))
        XCTAssertTrue(dirs.contains("/usr/local/lib"))
        XCTAssertTrue(dirs.contains("/opt/homebrew/bin"))
        XCTAssertTrue(dirs.contains("/opt/homebrew/lib"))
        XCTAssertFalse(dirs.contains("/"))
        XCTAssertEqual(Set(dirs).count, dirs.count)
    }

    func testWatchAddsParentOfCachedBinary() {
        let dirs = DependencyWatch.directories(extraFiles: [
            "/opt/homebrew/Cellar/ntfs-3g-mac/2026.9.28/bin/ntfs-3g"
        ])
        XCTAssertTrue(dirs.contains("/opt/homebrew/Cellar/ntfs-3g-mac/2026.9.28/bin"))
    }

    func testWatchIgnoresEmptyAndRootExtra() {
        let dirs = DependencyWatch.directories(extraFiles: ["", "/", "/ntfs-3g"])
        XCTAssertFalse(dirs.contains("/"))
        XCTAssertFalse(dirs.contains(""))
    }

    func testDirectoryWriteEmitsAfterChange() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("nigate-dep-watch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let gate = EmitGate()
        let watch = DependencyWatch(roots: [dir.path], debounce: 0.05)
        watch.start { gate.ping() }

        let armed = expectation(description: "armed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { armed.fulfill() }
        wait(for: [armed], timeout: 1)

        let changed = expectation(description: "dir-change")
        gate.arm(changed)
        XCTAssertTrue(
            FileManager.default.createFile(
                atPath: dir.appendingPathComponent("ntfs-3g").path,
                contents: Data("x".utf8)
            )
        )
        wait(for: [changed], timeout: 2)
        watch.stop()
    }
}

private final class EmitGate: @unchecked Sendable {
    private let lock = NSLock()
    private var expectation: XCTestExpectation?

    func arm(_ expectation: XCTestExpectation) {
        lock.lock()
        self.expectation = expectation
        lock.unlock()
    }

    func ping() {
        lock.lock()
        let expectation = self.expectation
        lock.unlock()
        expectation?.fulfill()
    }
}
