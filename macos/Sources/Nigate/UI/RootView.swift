import SwiftUI
import AppKit

enum Palette {
    static let accent = Color(red: 0, green: 0.48, blue: 1)
    /// 关于图标：浅一点的信息蓝，不要海军深蓝。
    static let about = Color(red: 0.29, green: 0.64, blue: 1)
    static let success = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let warning = Color(red: 1, green: 0.58, blue: 0)
    static let error = Color(red: 1, green: 0.23, blue: 0.19)
    static let coffee = Color(red: 0.55, green: 0.27, blue: 0.07)
    static let smart = Color(red: 0.10, green: 0.61, blue: 0.56)
    static let heart = Color(red: 0.92, green: 0.28, blue: 0.40)
    /// GitHub 常用紫（图标与项目地址同色）。
    static let github = Color(red: 0.51, green: 0.31, blue: 0.87)
    /// 博客 / RSS 常用橙。
    static let blog = Color(red: 0.95, green: 0.40, blue: 0.13)
    /// 邮箱常用红，避免三条联系方式都落成链接蓝。
    static let mail = Color(red: 0.91, green: 0.26, blue: 0.21)
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

private struct LinkPointerModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay {
                LinkCursorProbe()
                    .allowsHitTesting(false)
            }
            .onHover { hovering in
                // SwiftUI 会在同一轮把光标改回箭头/I 形，推迟一拍才能稳住手形。
                DispatchQueue.main.async {
                    if hovering {
                        NSCursor.pointingHand.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
            }
    }
}

private struct LinkCursorProbe: NSViewRepresentable {
    func makeNSView(context: Context) -> LinkCursorView {
        LinkCursorView()
    }

    func updateNSView(_ nsView: LinkCursorView, context: Context) {}
}

/// 点击穿透，只用跟踪区域把手形钉在链接上。
private final class LinkCursorView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .cursorUpdate],
                owner: self,
                userInfo: nil
            )
        )
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.pointingHand.set()
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.pointingHand.set()
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

extension View {
    func nigateHelp(_ text: String) -> some View {
        modifier(NigateHelpModifier(text: text))
    }

    func linkPointer() -> some View {
        modifier(LinkPointerModifier())
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
        .id(model.languageStamp)
        .frame(minWidth: WindowLayout.width, maxWidth: WindowLayout.width, minHeight: WindowLayout.minHeight)
        .background(Color(nsColor: .windowBackgroundColor))
        .background(MainWindowLock())
        .sheet(item: $model.passwordSheet, onDismiss: {
            model.cancelPassword()
        }) { sheet in
            PasswordSheet(state: sheet)
        }
        .sheet(isPresented: $model.aboutOpen) {
            AboutSheet()
        }
        .sheet(isPresented: $model.supportOpen) {
            SupportAuthorSheet()
        }
        .sheet(isPresented: $model.quitConfirmOpen) {
            QuitConfirmSheet()
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
            if let hint = model.progressHint {
                HStack(alignment: .top, spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(hint)
                        .font(.callout)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: 640, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
            } else if let toast = model.toast {
                Text(toast)
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 18)
            }
        }
        .onChange(of: model.toast) { _, toast in
            guard let toast, model.progressHint == nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                if model.toast == toast, model.progressHint == nil { model.toast = nil }
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
