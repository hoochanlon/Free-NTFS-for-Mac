import AppKit

/// 确认弹窗：小图标与标题同一行。
/// 不用 NSAlert——清空 messageText 后系统仍保留大块标题区，造成顶部空白。
@MainActor
enum ConfirmAlert {
    struct Presentation {
        var title: String
        var message: String
        var symbolName: String
        var style: NSAlert.Style
        var continueTitle: String
        var cancelTitle: String
        var minContentWidth: CGFloat = 440
    }

    @discardableResult
    static func run(_ presentation: Presentation) -> Bool {
        let controller = PanelController(presentation: presentation)
        return controller.run()
    }
}

// MARK: - Keyable borderless panel

/// borderless 默认 canBecomeKey=false，runModal 后主窗口被挡、面板又点不到 → 整 app 假死。
private final class ConfirmPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - Panel

@MainActor
private final class PanelController: NSObject {
    private let presentation: ConfirmAlert.Presentation
    private var confirmed = false
    private var panel: ConfirmPanel?
    private var finished = false

    init(presentation: ConfirmAlert.Presentation) {
        self.presentation = presentation
    }

    func run() -> Bool {
        let width = presentation.minContentWidth
        let corner: CGFloat = 14
        let content = ContentView(presentation: presentation, width: width) { [self] ok in
            finish(ok)
        }
        content.translatesAutoresizingMaskIntoConstraints = false

        // 内层：圆角裁剪内容
        let card = NSVisualEffectView()
        card.material = .headerView
        card.blendingMode = .withinWindow
        card.state = .active
        card.wantsLayer = true
        card.layer?.cornerRadius = corner
        card.layer?.cornerCurve = .continuous
        card.layer?.masksToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)

        // 外层：只负责圆角阴影（masksToBounds=false）。窗口 hasShadow 是矩形，会露出直角。
        let shadowHost = NSView()
        shadowHost.wantsLayer = true
        shadowHost.layer?.masksToBounds = false
        shadowHost.layer?.cornerRadius = corner
        shadowHost.layer?.cornerCurve = .continuous
        shadowHost.layer?.backgroundColor = NSColor.clear.cgColor
        shadowHost.layer?.shadowColor = NSColor.black.cgColor
        shadowHost.layer?.shadowOpacity = 0.28
        shadowHost.layer?.shadowRadius = 18
        shadowHost.layer?.shadowOffset = CGSize(width: 0, height: -3)
        shadowHost.translatesAutoresizingMaskIntoConstraints = false
        shadowHost.addSubview(card)

        // contentView 必须允许窗口用 frame/autoresizing 管理尺寸；false 会导致内容塌成 0 高，模态假死。
        let root = NSView(frame: NSRect(x: 0, y: 0, width: width + 84, height: 160))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.clear.cgColor
        root.autoresizingMask = [.width, .height]
        root.addSubview(shadowHost)

        // 给阴影留出绘制边距，避免被窗口矩形裁掉
        let inset: CGFloat = 24
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),

            card.leadingAnchor.constraint(equalTo: shadowHost.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: shadowHost.trailingAnchor),
            card.topAnchor.constraint(equalTo: shadowHost.topAnchor),
            card.bottomAnchor.constraint(equalTo: shadowHost.bottomAnchor),

            shadowHost.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: inset),
            shadowHost.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -inset),
            shadowHost.topAnchor.constraint(equalTo: root.topAnchor, constant: inset),
            shadowHost.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -inset)
        ])

        let panel = ConfirmPanel(
            contentRect: NSRect(x: 0, y: 0, width: width + 36 + inset * 2, height: 140 + inset * 2),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.level = .modalPanel
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.worksWhenModal = true
        panel.contentView = root

        root.layoutSubtreeIfNeeded()
        let cardSize = card.fittingSize
        let panelSize = NSSize(
            width: max(cardSize.width, width + 36) + inset * 2,
            height: max(cardSize.height, 88) + inset * 2
        )
        panel.setContentSize(panelSize)
        // 阴影路径跟圆角一致，避免矩形光晕
        let shadowBounds = CGRect(
            x: 0,
            y: 0,
            width: panelSize.width - inset * 2,
            height: panelSize.height - inset * 2
        )
        shadowHost.layer?.shadowPath = CGPath(
            roundedRect: shadowBounds,
            cornerWidth: corner,
            cornerHeight: corner,
            transform: nil
        )

        self.panel = panel
        let host = hostWindow(excluding: panel)
        // 用最终尺寸相对宿主内容区居中；orderFront 后再钉一次，避免首帧位置漂移。
        place(panel, size: panelSize, over: host)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        place(panel, size: panelSize, over: host)
        // Escape 兜底：即使按钮未成为 first responder 也能退出模态，避免假死。
        let escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.finish(false)
                return nil
            }
            return event
        }
        NSApp.runModal(for: panel)
        if let escMonitor {
            NSEvent.removeMonitor(escMonitor)
        }
        panel.orderOut(nil)
        self.panel = nil
        return confirmed
    }

    /// 找主应用窗口：key/main 优先，否则取最大的可见普通窗口。
    private func hostWindow(excluding panel: NSWindow) -> NSWindow? {
        func usable(_ window: NSWindow) -> Bool {
            guard window !== panel else { return false }
            // 排除菜单、状态栏、我们自己的无边框模态面板
            if window is NSPanel, window.styleMask.contains(.borderless) { return false }
            if window.frame.width < 240 || window.frame.height < 160 { return false }
            return true
        }

        let preferred = [NSApp.keyWindow, NSApp.mainWindow]
            .compactMap { $0 }
            .first(where: usable)
        if let preferred { return preferred }

        // SwiftUI Window 有时 key/main 暂时为空，用面积最大的可见窗口兜底。
        return NSApp.windows
            .filter(usable)
            .filter(\.isVisible)
            .max { lhs, rhs in
                (lhs.frame.width * lhs.frame.height) < (rhs.frame.width * rhs.frame.height)
            }
    }

    /// 相对宿主窗口内容区几何中心放置；无宿主时退回主屏可见区域中心（真中心，不用 NSWindow.center 的偏上布局）。
    private func place(_ panel: NSWindow, size: NSSize, over host: NSWindow?) {
        let target: NSRect = {
            if let host {
                // contentView.bounds → 窗口坐标 → 屏幕坐标，作为视觉居中基准。
                if let content = host.contentView {
                    let inWindow = content.convert(content.bounds, to: nil)
                    return host.convertToScreen(inWindow)
                }
                return host.frame
            }
            return (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
                ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        }()

        var frame = NSRect(
            x: target.midX - size.width / 2,
            y: target.midY - size.height / 2,
            width: size.width,
            height: size.height
        )

        let anchor = NSPoint(x: target.midX, y: target.midY)
        let screen = host?.screen
            ?? NSScreen.screens.first { NSMouseInRect(anchor, $0.frame, false) }
            ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            // 夹紧到可见区域，避免多屏/刘海屏裁切。
            frame.origin.x = min(
                max(frame.origin.x, visible.minX + 8),
                max(visible.minX + 8, visible.maxX - frame.width - 8)
            )
            frame.origin.y = min(
                max(frame.origin.y, visible.minY + 8),
                max(visible.minY + 8, visible.maxY - frame.height - 8)
            )
        }
        panel.setFrame(frame, display: true)
    }

    private func finish(_ ok: Bool) {
        guard !finished else { return }
        finished = true
        confirmed = ok
        NSApp.stopModal(withCode: ok ? .OK : .cancel)
        panel?.orderOut(nil)
    }
}

// MARK: - Content

@MainActor
private final class ContentView: NSView {
    private let onFinish: (Bool) -> Void

    init(presentation: ConfirmAlert.Presentation, width: CGFloat, onFinish: @escaping (Bool) -> Void) {
        self.onFinish = onFinish
        super.init(frame: .zero)

        let iconColor: NSColor = {
            switch presentation.style {
            case .critical: return .systemRed
            case .warning: return .systemOrange
            default: return .controlAccentColor
            }
        }()

        let iconView = NSImageView()
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.contentTintColor = iconColor
        if let base = NSImage(systemSymbolName: presentation.symbolName, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            iconView.image = base.withSymbolConfiguration(config)
        }
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(wrappingLabelWithString: presentation.title)
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let header = NSStackView(views: [iconView, titleLabel])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 8
        header.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(header)

        let message = presentation.message.trimmingCharacters(in: .whitespacesAndNewlines)
        if !message.isEmpty {
            let messageLabel = NSTextField(wrappingLabelWithString: message)
            messageLabel.font = .systemFont(ofSize: 13)
            messageLabel.textColor = .secondaryLabelColor
            messageLabel.preferredMaxLayoutWidth = width - 28
            messageLabel.translatesAutoresizingMaskIntoConstraints = false

            let messageRow = NSStackView()
            messageRow.orientation = .horizontal
            messageRow.spacing = 0
            messageRow.translatesAutoresizingMaskIntoConstraints = false
            let indent = NSView()
            indent.translatesAutoresizingMaskIntoConstraints = false
            indent.widthAnchor.constraint(equalToConstant: 28).isActive = true
            messageRow.addArrangedSubview(indent)
            messageRow.addArrangedSubview(messageLabel)
            stack.addArrangedSubview(messageRow)
        }

        let cancel = NSButton(title: presentation.cancelTitle, target: self, action: #selector(cancelTapped))
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"

        let confirm = NSButton(title: presentation.continueTitle, target: self, action: #selector(confirmTapped))
        confirm.bezelStyle = .rounded
        confirm.keyEquivalent = "\r"
        if #available(macOS 11.0, *), presentation.style == .critical {
            confirm.hasDestructiveAction = true
        }

        let buttons = NSStackView(views: [cancel, confirm])
        buttons.orientation = .horizontal
        buttons.spacing = 10
        buttons.alignment = .centerY
        buttons.translatesAutoresizingMaskIntoConstraints = false

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttonRow = NSStackView(views: [spacer, buttons])
        buttonRow.orientation = .horizontal
        buttonRow.distribution = .fill
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(buttonRow)

        addSubview(stack)
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            widthAnchor.constraint(equalToConstant: width)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    @objc private func cancelTapped() { onFinish(false) }
    @objc private func confirmTapped() { onFinish(true) }
}
