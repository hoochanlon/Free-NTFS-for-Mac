import Foundation

/// 关于页和更新检查用的版本。打包后的 .app 读包内 Info.plist；
/// `swift run` 没有这份 plist，才回退到源码树里的 macos/Info.plist。
let appVersion = AppVersion.current

enum AppVersion {
    static var current: String {
        resolve(
            bundleVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            sourcePlist: sourceInfoPlistURL()
        )
    }

    static func resolve(bundleVersion: String?, sourcePlist: URL?) -> String {
        if let version = concrete(bundleVersion) { return version }
        if let sourcePlist, let version = shortVersion(in: sourcePlist) { return version }
        return "0"
    }

    static func sourceInfoPlistURL(startingAt file: String = #filePath) -> URL? {
        var directory = URL(fileURLWithPath: file).deletingLastPathComponent()
        for _ in 0..<8 {
            let candidate = directory.appendingPathComponent("Info.plist")
            if shortVersion(in: candidate) != nil { return candidate }
            let parent = directory.deletingLastPathComponent()
            if parent.path == directory.path { break }
            directory = parent
        }
        return nil
    }

    static func shortVersion(in plist: URL) -> String? {
        guard let root = dictionary(in: plist),
              root["CFBundlePackageType"] as? String == "APPL" else { return nil }
        return concrete(root["CFBundleShortVersionString"] as? String)
    }

    static func concrete(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let version = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !version.isEmpty, !version.contains("$(") else { return nil }
        return version
    }

    private static func dictionary(in plist: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: plist),
              let root = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return root
    }
}
