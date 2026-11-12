import SwiftUI
import AppKit

struct TitleChrome: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Text("Nigate（Free NTFS for Mac）")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            // 交互区必须禁止“标题栏拖窗口”，否则状态刷新后系统拖拽热区会吞掉点击。
            HStack(spacing: 10) {
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

                protectButton

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
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
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
                        .lineLimit(1)
                }
                .padding(.leading, 6)
            }
            .background(TitleBarClickThroughFix())
        }
        .padding(.leading, 78)
        .padding(.trailing, 18)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var protectButton: some View {
        Image(systemName: model.protectLocked ? "lock.shield.fill" : "lock.shield")
            .foregroundStyle(model.protectLocked ? Palette.success : Color.primary.opacity(0.7))
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
            .help(model.protectLocked ? L10n.t("app.protectTooltipLocked") : L10n.t("app.protectTooltip"))
            // longPress 不要直接挂在裸 Image 上扩散手势；限制在固定 hit box 内。
            .gesture(
                LongPressGesture(minimumDuration: 3)
                    .onEnded { _ in model.toggleProtect() }
            )
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
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

/// hiddenTitleBar 下，AppKit 会把标题区域当成拖拽窗口热区。
/// 在控件背后放一个 mouseDownCanMoveWindow=false 的 NSView，强制点击落到按钮而不是拖窗口。
private struct TitleBarClickThroughFix: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        TitleBarNonDraggableView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class TitleBarNonDraggableView: NSView {
    override var mouseDownCanMoveWindow: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // 不绘制、不拦截 hit-test，只影响所在区域的 window-move 行为。
        wantsLayer = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
