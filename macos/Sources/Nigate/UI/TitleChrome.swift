import SwiftUI
import AppKit

struct TitleChrome: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                NigateMark()
                Text("Nigate（Free NTFS for Mac）")
                    .font(.system(size: 15, weight: .semibold))
            }
            Spacer()
            // 交互区必须禁止“标题栏拖窗口”，否则状态刷新后系统拖拽热区会吞掉点击。
            HStack(spacing: 10) {
                iconButton(
                    "cup.and.saucer.fill",
                    SleepChrome.title(model.settings.sleepMode),
                    active: model.settings.sleepMode != .off,
                    tint: SleepChrome.tint(model.settings.sleepMode)
                ) {
                    model.cycleSleep()
                }
                .disabled(model.protectLocked)

                ChromeProtectButton()

                iconButton("power", L10n.t("menu.quit"), active: model.quitConfirmOpen, tint: Palette.error) {
                    model.requestQuit()
                }

                iconButton("heart.fill", L10n.t("support.title"), active: model.supportOpen, tint: Palette.heart) {
                    model.supportOpen = true
                }

                iconButton("info.circle", L10n.t("app.about"), active: model.aboutOpen, tint: Palette.about) {
                    model.aboutOpen = true
                }

                ChromeThemeButton()

                ChromeStatusChip()
                    .padding(.leading, 6)
            }
            .background(TitleBarClickThroughFix())
        }
        .padding(.leading, 78)
        .padding(.trailing, 18)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func iconButton(_ system: String, _ title: String, active: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        ChromeIconButton(system: system, title: title, active: active, tint: tint, action: action)
    }
}

enum SleepChrome {
    static func title(_ mode: SleepMode) -> String {
        mode == .smart ? L10n.t("titleBar.preventSleepSmart") : L10n.t("titleBar.preventSleep")
    }

    static func tint(_ mode: SleepMode) -> Color {
        switch mode {
        case .off: return .secondary
        case .always: return Palette.coffee
        case .smart: return Palette.smart
        }
    }
}

/// 标题栏 / 托盘共用白色剪影。随正文色走，避免红色 AppIcon 抢色。
struct NigateMark: View {
    var size: CGFloat = 22

    var body: some View {
        if let logo = Self.nigateLogo {
            Image(nsImage: logo)
                .renderingMode(.template)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .foregroundStyle(Color.primary.opacity(0.78))
                .accessibilityHidden(true)
        }
    }

    private static let nigateLogo: NSImage? = {
        guard let url = Bundle.module.url(forResource: "AppIcon-white", withExtension: "icns"),
              let loaded = NSImage(contentsOf: url) else { return nil }
        let image = loaded.copy() as? NSImage ?? loaded
        image.isTemplate = true
        return image
    }()
}

/// 标题栏 / 托盘共用。长按 3 秒切换，避免误触。
struct ChromeProtectButton: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Image(systemName: model.protectLocked ? "lock.shield.fill" : "lock.shield")
            .foregroundStyle(model.protectLocked ? Palette.success : Color.primary.opacity(0.7))
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
            .nigateHelp(model.protectLocked ? L10n.t("app.protectTooltipLocked") : L10n.t("app.protectTooltip"))
            // longPress 不要直接挂在裸 Image 上扩散手势；限制在固定 hit box 内。
            .gesture(
                LongPressGesture(minimumDuration: 3)
                    .onEnded { _ in model.toggleProtect() }
            )
    }
}

/// 浅色显示月亮、深色显示太阳。标题栏 / 托盘共用。
struct ChromeThemeButton: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Button {
            model.toggleTheme()
        } label: {
            Image(systemName: model.settings.themeIsLight ? "moon.fill" : "sun.max.fill")
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .nigateHelp(model.settings.themeIsLight ? L10n.t("theme.toggleDark") : L10n.t("theme.toggleLight"))
    }
}

/// 22pt 线性图标。悬停提示画在窗口层，水平居中钉在图标下方。
struct ChromeIconButton: View {
    let system: String
    let title: String
    var active: Bool
    var tint: Color
    var spinning: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if spinning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: system)
                        .foregroundStyle(active ? tint : Color.primary.opacity(0.7))
                }
            }
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .nigateHelp(title)
    }
}

struct ChromeStatusChip: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(model.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var color: Color {
        if !model.dependencies.isProbed { return .secondary }
        if model.dependencies.missingCore { return Palette.error }
        if model.devices.contains(where: \.isReadOnly) { return Palette.warning }
        if !model.devices.isEmpty { return Palette.success }
        return .secondary
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
