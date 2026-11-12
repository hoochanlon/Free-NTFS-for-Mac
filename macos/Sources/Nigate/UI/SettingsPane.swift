import SwiftUI
import AppKit
import NigateFSKitCore

struct SettingsPane: View {
    @EnvironmentObject private var model: AppModel

    /// 依赖 @Published fsKitControlPlane，避免只读 MountBackendPolicy 静态值导致 UI 不刷新。
    private var fsKitSelectable: Bool {
        _ = model.fsKitControlPlane
        return MountBackendPolicy.canUseFSKit()
    }

    var body: some View {
        Form {
            Section(L10n.t("settings.title")) {
                Toggle(L10n.t("settings.savePassword"), isOn: bind(\.savePassword))
                Text(L10n.t("settings.savePasswordDesc")).font(.caption).foregroundStyle(.secondary)
                Button(L10n.t("settings.deletePassword")) {
                    let confirmed = ConfirmAlert.run(
                        .init(
                            title: L10n.t("settings.deletePasswordConfirm"),
                            message: "",
                            symbolName: "key.slash",
                            style: .warning,
                            continueTitle: L10n.t("dialog.confirm"),
                            cancelTitle: L10n.t("dialog.cancel"),
                            minContentWidth: 400
                        )
                    )
                    if confirmed {
                        model.deleteSavedPassword()
                    }
                }
                Toggle(L10n.t("settings.autoMount"), isOn: bind(\.autoMount))
                    .disabled(model.protectLocked)
                Text(L10n.t("settings.autoMountDesc")).font(.caption).foregroundStyle(.secondary)
                Picker(L10n.t("settings.mountBackend"), selection: mountBackendBinding) {
                    // 默认与产品主路径：ntfs-3g 兼容；FSKit 为可选增强。
                    Text(L10n.t("settings.ntfs3gCompatibilityBackend")).tag(NigateMountBackend.ntfs3gCompatibility)
                    Text(fsKitLabel).tag(NigateMountBackend.fsKit)
                }
                Text(L10n.t(fsKitSelectable ? "settings.mountBackendDesc" : "settings.mountBackendUnavailableDesc"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !fsKitSelectable, let diagnostic = model.fsKitControlPlane.diagnostic {
                    Text(L10n.fsKitDiagnosticText(diagnostic))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
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

    private var fsKitLabel: String {
        let base = L10n.t("settings.fsKitBackend")
        return fsKitSelectable ? base : "\(base) — \(L10n.t("settings.fsKitBackendUnavailable"))"
    }

    /// 控制面未接通时禁止选回 FSKit，避免再次落入不可用状态。
    private var mountBackendBinding: Binding<NigateMountBackend> {
        Binding(
            get: { MountBackendPolicy.sanitize(model.settings.mountBackend) },
            set: { value in
                let next = MountBackendPolicy.sanitize(value)
                model.settings.mountBackend = next
                model.persist()
            }
        )
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
