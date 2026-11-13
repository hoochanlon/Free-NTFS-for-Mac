import SwiftUI
import AppKit

enum Palette {
    static let accent = Color(red: 0, green: 0.48, blue: 1)
    static let success = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let warning = Color(red: 1, green: 0.58, blue: 0)
    static let error = Color(red: 1, green: 0.23, blue: 0.19)
    static let coffee = Color(red: 0.55, green: 0.27, blue: 0.07)
    static let smart = Color(red: 0.10, green: 0.61, blue: 0.56)
}

/// 按钮悬停提示：只在设置打开时挂 `.help`，默认关闭。
private struct NigateHelpModifier: ViewModifier {
    @EnvironmentObject private var model: AppModel
    let text: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if model.settings.showButtonHints {
            content.help(text)
        } else {
            content
        }
    }
}

extension View {
    func nigateHelp(_ text: String) -> some View {
        modifier(NigateHelpModifier(text: text))
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            TitleChrome()
            tabBar
            Divider()
            Group {
                switch model.tab {
                case .dependencies: DependenciesPane()
                case .devices: DevicesPane()
                case .help: HelpPane()
                case .settings: SettingsPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 900, minHeight: 680)
        .background(Color(nsColor: .windowBackgroundColor))
        .id(model.languageStamp)
        .sheet(item: $model.passwordSheet, onDismiss: {
            model.cancelPassword()
        }) { sheet in
            PasswordSheet(state: sheet)
        }
        .sheet(isPresented: $model.aboutOpen) {
            AboutSheet()
        }
        .sheet(item: $model.renameDevice) { device in
            RenameSheet(device: device)
        }
        .alert(
            model.alert?.title ?? "",
            isPresented: Binding(
                get: { model.alert != nil },
                set: { if !$0 { model.alert = nil } }
            )
        ) {
            Button(L10n.t("dialog.ok"), role: .cancel) { model.alert = nil }
        } message: {
            Text(model.alert?.message ?? "")
        }
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                Text(toast)
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 18)
            }
        }
        .onChange(of: model.toast) { _, toast in
            guard let toast else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                if model.toast == toast { model.toast = nil }
            }
        }
        .preferredColorScheme(model.settings.themeIsLight ? .light : .dark)
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            tabButton(.dependencies, "puzzlepiece.extension", L10n.t("tabs.dependencies"))
            tabButton(.devices, "externaldrive", L10n.t("tabs.devices"))
            tabButton(.help, "questionmark.circle", L10n.t("tabs.help"))
            tabButton(.settings, "gearshape", L10n.t("tabs.settings"))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func tabButton(_ tab: AppTab, _ icon: String, _ title: String) -> some View {
        Button {
            model.setTab(tab)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(model.tab == tab ? Color.accentColor.opacity(0.16) : Color.clear, in: Capsule())
            .contentShape(Rectangle())
            .foregroundStyle(model.tab == tab ? Color.accentColor : Color.primary.opacity(0.75))
        }
        .buttonStyle(.plain)
    }
}
