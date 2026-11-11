import SwiftUI
import AppKit
import NigateFSKitCore

struct SettingsPane: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section(L10n.t("settings.title")) {
                Toggle(L10n.t("settings.savePassword"), isOn: bind(\.savePassword))
                Text(L10n.t("settings.savePasswordDesc")).font(.caption).foregroundStyle(.secondary)
                Button(L10n.t("settings.deletePassword")) {
                    let alert = NSAlert()
                    alert.messageText = L10n.t("settings.deletePasswordConfirm")
                    alert.addButton(withTitle: L10n.t("dialog.confirm"))
                    alert.addButton(withTitle: L10n.t("dialog.cancel"))
                    if alert.runModal() == .alertFirstButtonReturn {
                        model.deleteSavedPassword()
                    }
                }
                Toggle(L10n.t("settings.autoMount"), isOn: bind(\.autoMount))
                    .disabled(model.protectLocked)
                Text(L10n.t("settings.autoMountDesc")).font(.caption).foregroundStyle(.secondary)
                Picker(L10n.t("settings.mountBackend"), selection: bind(\.mountBackend)) {
                    Text(L10n.t("settings.fsKitBackend")).tag(NigateMountBackend.fsKit)
                    Text(L10n.t("settings.ntfs3gCompatibilityBackend")).tag(NigateMountBackend.ntfs3gCompatibility)
                }
                Text(L10n.t("settings.mountBackendDesc"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle(L10n.t("settings.trayMode"), isOn: Binding(
                    get: { model.settings.trayMode },
                    set: { model.setTrayMode($0) }
                ))
                    .disabled(model.protectLocked)
                Text(L10n.t("settings.trayModeDesc")).font(.caption).foregroundStyle(.secondary)
                Toggle(L10n.t("settings.preventSleep"), isOn: Binding(
                    get: { model.settings.preventSleep },
                    set: { value in
                        model.settings.preventSleep = value
                        if value { model.settings.keepAwake = false }
                        model.persist()
                    }
                ))
                .disabled(model.protectLocked)
                Text(L10n.t("settings.preventSleepDesc")).font(.caption).foregroundStyle(.secondary)
                Toggle(L10n.t("settings.autoStart"), isOn: bind(\.autoStart))
                Text(L10n.t("settings.autoStartDesc")).font(.caption).foregroundStyle(.secondary)
                Picker(L10n.t("settings.startupTab"), selection: bind(\.startupTab)) {
                    Text(L10n.t("tabs.dependencies")).tag(AppTab.dependencies)
                    Text(L10n.t("tabs.devices")).tag(AppTab.devices)
                    Text(L10n.t("tabs.help")).tag(AppTab.help)
                    Text(L10n.t("tabs.settings")).tag(AppTab.settings)
                }
                Picker(L10n.t("settings.language"), selection: bind(\.language)) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(L10n.t("settings.languages.\(language.rawValue)")).tag(language)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }

    private func bind<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { value in
                model.settings[keyPath: keyPath] = value
                model.persist()
            }
        )
    }
}
