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

/// 悬停图标按钮提示：只在设置打开时挂 `.help`，默认开启。
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
        .sheet(item: $model.renameDevice) { device in
            RenameSheet(device: device)
        }
        .sheet(item: $model.windowConfirm) { confirm in
            WindowConfirmCard(confirm: confirm)
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
            // overlay 会给出整窗宽度。系统 ProgressView 会把多出来的宽度吃掉，
            // 转圈和文字就被撕到两端。芯片自己按内容收拢，再在窗口里居中。
            VStack {
                if let hint = model.progressHint {
                    bottomChip(hint, spinning: true)
                } else if let toast = model.toast {
                    bottomChip(toast, spinning: false)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 18)
            .allowsHitTesting(false)
        }
        .overlay {
            // 条件分支的理想尺寸是卡片本身，遮罩会跟着缩成卡片大小，窗口其余部分仍可拖走。
            // GeometryReader 拿到的是整窗尺寸，遮罩必须按这个尺寸铺满。
            GeometryReader { proxy in
                if model.quitConfirmOpen {
                    windowModal(size: proxy.size) {
                        QuitConfirmSheet()
                    }
                }
            }
        }
        .onChange(of: model.toast) { _, toast in
            scheduleToastDismiss(toast)
        }
        .onChange(of: model.progressHint) { _, hint in
            // 转读写的长提示挡着 toast 写入时，关掉提示后要补一次消失计时。
            guard hint == nil else { return }
            scheduleToastDismiss(model.toast)
        }
        .preferredColorScheme(model.settings.themeIsLight ? .light : .dark)
    }

    private func scheduleToastDismiss(_ toast: String?) {
        guard let toast, model.progressHint == nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            if model.toast == toast, model.progressHint == nil { model.toast = nil }
        }
    }

    private func bottomChip(_ text: String, spinning: Bool) -> some View {
        HStack(alignment: .center, spacing: 6) {
            if spinning {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .labelsHidden()
                    .fixedSize()
                    .scaleEffect(0.85)
                    .frame(width: 14, height: 14)
            }
            Text(text)
                .font(.callout)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: spinning ? 12 : 20, style: .continuous)
        )
        .fixedSize()
        .padding(.horizontal, 24)
    }

    private func windowModal<Content: View>(size: CGSize, @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.46)
            // 遮罩盖住标题栏后，系统拖拽热区收不到鼠标。灰底自己把窗口拖走，卡片上的按钮仍在上层。
            WindowMoveScrim()
                .frame(width: size.width, height: size.height)
            content()
        }
        .frame(width: size.width, height: size.height)
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

/// 确认层盖住整窗。灰底按下时拖动窗口，卡片按钮在更上层，不会跟着被拖。
private struct WindowMoveScrim: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowMoveScrimView {
        WindowMoveScrimView()
    }

    func updateNSView(_ nsView: WindowMoveScrimView, context: Context) {}
}

private final class WindowMoveScrimView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
