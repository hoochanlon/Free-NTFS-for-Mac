import Foundation

enum PathLookup {
    private static let ntfs3gCache = LockedValue<String?>(nil)

    static func reset() {
        ntfs3gCache.set(nil)
    }

    static func ntfs3g() async -> String? {
        if let cached = ntfs3gCache.value { return cached }
        if let found = Shell.which("ntfs-3g") {
            ntfs3gCache.set(found)
            return found
        }
        guard let brew = Shell.which("brew") else { return nil }
        for formula in ["ntfs-3g-mac", "ntfs-3g"] {
            let result = await Shell.runQuiet(brew, ["--prefix", formula], timeout: 3)
            let prefix = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prefix.isEmpty else { continue }
            for dir in ["bin", "sbin"] {
                let candidate = "\(prefix)/\(dir)/ntfs-3g"
                if let trusted = Shell.trustedExecutable(candidate) {
                    ntfs3gCache.set(trusted)
                    return trusted
                }
            }
        }
        return nil
    }

    static func sibling(of ntfs3g: String?, named tool: String) -> String? {
        if let found = Shell.which(tool) { return found }
        if let ntfs3g {
            let candidate = URL(fileURLWithPath: ntfs3g).deletingLastPathComponent().appendingPathComponent(tool).path
            return Shell.trustedExecutable(candidate)
        }
        return nil
    }

    static func resolvedNTFS3G(_ path: String) throws -> String {
        if let trusted = Shell.trustedExecutable(path) { return trusted }
        let prefixed = "/System/Volumes/Data" + path
        if let trusted = Shell.trustedExecutable(prefixed) { return trusted }
        throw AppError.failed("ntfs-3g 路径不存在或不受信任: \(path)")
    }
}

final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) {
        storage = value
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func set(_ value: Value) {
        lock.lock()
        storage = value
        lock.unlock()
    }
}
