import Foundation
import NigateFSKitCore

enum SettingsStore {
    private static var url: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = root.appendingPathComponent("Nigate", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("settings.json")
    }

    static func load() -> AppSettings {
        var settings = AppSettings()
        guard let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return settings
        }
        if let value = raw["savePassword"] as? Bool { settings.savePassword = value }
        if let value = raw["startupTab"] as? String {
            settings.startupTab = AppTab(rawValue: value) ?? .dependencies
        }
        if let value = raw["language"] as? String {
            settings.language = AppLanguage(rawValue: value) ?? .system
        }
        if let value = raw["autoStart"] as? Bool { settings.autoStart = value }
        if let value = raw["preventSleep"] as? Bool { settings.preventSleep = value }
        if let value = raw["keepAwake"] as? Bool { settings.keepAwake = value }
        if let value = raw["manuallyReadOnlyDevices"] as? [String] {
            settings.manuallyReadOnlyDevices = value
        }
        if let value = raw["mountBackend"] as? String {
            let parsed = NigateMountBackend(rawValue: value) ?? .ntfs3gCompatibility
            // 控制面未接通时，历史 fsKit 选择不可用，纠正为兼容后端
            settings.mountBackend = MountBackendPolicy.sanitize(parsed)
        }
        if let value = raw["themeIsLight"] as? Bool { settings.themeIsLight = value }
        // 只认新键。旧 showButtonHints:false 是上一版默认值被整表写入，不是用户关掉的。
        if let value = raw["showHoverIconButtonHints"] as? Bool {
            settings.showButtonHints = value
        }
        if let value = raw["trayListHeight"] as? Double, value > 0 {
            settings.trayListHeight = value
        } else if let value = raw["trayListHeight"] as? Int, value > 0 {
            settings.trayListHeight = Double(value)
        }
        return settings
    }

    static func save(_ settings: AppSettings) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(settings) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
