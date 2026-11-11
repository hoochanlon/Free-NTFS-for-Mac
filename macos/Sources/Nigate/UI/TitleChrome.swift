import SwiftUI
import AppKit

struct TitleChrome: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Text("Nigate（Free NTFS for Mac）")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            iconButton("bolt.horizontal.circle", L10n.t("devices.autoMount"), active: model.settings.autoMount, tint: Palette.accent) {
                model.toggleAutoMount()
            }
            .disabled(model.protectLocked)
            iconButton("menubar.dock.rectangle", L10n.t("settings.trayMode"), active: model.settings.trayMode, tint: .purple) {
                model.toggleTray()
            }
            .disabled(model.protectLocked)
            iconButton("cup.and.saucer.fill", sleepTitle, active: model.settings.sleepMode != .off, tint: sleepTint) {
                model.cycleSleep()
            }
            .disabled(model.protectLocked)
            Image(systemName: model.protectLocked ? "lock.shield.fill" : "lock.shield")
                .foregroundStyle(model.protectLocked ? Palette.success : Color.primary.opacity(0.7))
                .help(model.protectLocked ? L10n.t("app.protectTooltipLocked") : L10n.t("app.protectTooltip"))
                .onLongPressGesture(minimumDuration: 3) {
                    model.toggleProtect()
                }
            iconButton("power", L10n.t("menu.quit"), active: false, tint: Palette.error) {
                NSApp.terminate(nil)
            }
            iconButton("info.circle", L10n.t("app.about"), active: false, tint: Palette.accent) {
                model.aboutOpen = true
            }
            Button {
                model.toggleTheme()
            } label: {
                Image(systemName: model.settings.themeIsLight ? "moon.fill" : "sun.max.fill")
            }
            .buttonStyle(.plain)
            .help(L10n.t("theme.toggle"))
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(model.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 6)
        }
        .padding(.leading, 78)
        .padding(.trailing, 18)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var sleepTitle: String {
        model.settings.sleepMode == .smart ? L10n.t("titleBar.preventSleepSmart") : L10n.t("titleBar.preventSleep")
    }

    private var sleepTint: Color {
        switch model.settings.sleepMode {
        case .off: return .secondary
        case .always: return Palette.coffee
        case .smart: return Palette.smart
        }
    }

    private var statusColor: Color {
        if model.dependencies.missingCore { return Palette.warning }
        if model.devices.contains(where: \.isReadOnly) { return Palette.warning }
        if !model.devices.isEmpty { return Palette.success }
        return .secondary
    }

    private func iconButton(_ system: String, _ title: String, active: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .foregroundStyle(active ? tint : Color.primary.opacity(0.7))
        }
        .buttonStyle(.plain)
        .help(title)
    }
}
