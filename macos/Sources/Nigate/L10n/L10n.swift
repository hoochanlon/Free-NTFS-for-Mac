import Foundation
import NigateFSKitCore

enum L10n {
    private static let table = LockedValue<[String: Any]>([:])
    private static let resolved = LockedValue<AppLanguage>(.zhCN)

    static var language: AppLanguage { resolved.value }

    static func apply(_ preferred: AppLanguage) {
        let selected = resolve(preferred)
        resolved.set(selected)
        table.set(load(selected))
    }

    static func resolve(_ preferred: AppLanguage) -> AppLanguage {
        if preferred != .system { return preferred }
        let code = Locale.preferredLanguages.first ?? "zh-CN"
        if code.hasPrefix("ja") { return .ja }
        if code.hasPrefix("de") { return .de }
        if code.hasPrefix("en") { return .en }
        if code.contains("TW") || code.contains("Hant") { return .zhTW }
        if code.hasPrefix("zh") { return .zhCN }
        return .zhCN
    }

    static func t(_ key: String, _ params: [String: String] = [:]) -> String {
        var value: Any? = table.value
        for part in key.split(separator: ".") {
            value = (value as? [String: Any])?[String(part)]
        }
        var text = value as? String ?? key
        for (name, replacement) in params {
            text = text.replacingOccurrences(of: "{\(name)}", with: replacement)
        }
        return text
    }

    static func fsKitDiagnosticText(_ diagnostic: NigateFSKitControlPlaneDiagnostic) -> String {
        switch diagnostic {
        case .controlPlaneUnavailable:
            return t("dependencies.fsKit.diagnosticUnavailable")
        case let .unsupportedSystem(current):
            return t("dependencies.fsKit.diagnosticUnsupportedSystem", [
                "version": "\(current.major).\(current.minor).\(current.patch)"
            ])
        case .extensionDisabled:
            return t("dependencies.fsKit.diagnosticExtensionDisabled")
        case .extensionNotRegistered:
            return t("dependencies.fsKit.diagnosticExtensionNotRegistered")
        }
    }

    static func helpMarkdown() -> String {
        let name: String
        switch resolved.value {
        case .zhCN, .system: name = "help.zh-CN"
        case .zhTW: name = "help.zh-TW"
        case .ja: name = "help.ja"
        case .en: name = "help.en"
        case .de: name = "help.de"
        }
        if let url = resource("Help/\(name).md") ?? resource("Help/help.md"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            return text
        }
        return L10n.t("help.loadError", ["error": "missing"])
    }

    static func resource(_ relative: String) -> URL? {
        if let url = Bundle.module.url(forResource: relative, withExtension: nil) {
            return url
        }
        let parts = relative.split(separator: "/").map(String.init)
        guard let filename = parts.last else {
            return Bundle.main.url(forResource: relative, withExtension: nil)
        }
        let directory = parts.dropLast().joined(separator: "/")
        let ext = (filename as NSString).pathExtension
        let stem = (filename as NSString).deletingPathExtension
        if !directory.isEmpty,
           let url = Bundle.module.url(
            forResource: stem,
            withExtension: ext.isEmpty ? nil : ext,
            subdirectory: directory
           ) {
            return url
        }
        return Bundle.main.url(forResource: relative, withExtension: nil)
    }

    private static func load(_ language: AppLanguage) -> [String: Any] {
        let file = language == .system ? "zh-CN" : language.rawValue
        let url = Bundle.module.url(forResource: file, withExtension: "json", subdirectory: "Locales")
            ?? Bundle.module.url(forResource: "zh-CN", withExtension: "json", subdirectory: "Locales")
        guard let url, let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }
}
