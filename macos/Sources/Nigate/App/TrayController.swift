import AppKit
import SwiftUI

enum TrayDeviceStatus: Equatable {
    case ready
    case allReadWrite
    case allReadOnly
    case mixed

    init(devices: [NTFSDevice]) {
        let mounted = devices.filter { $0.isMounted && !$0.isUnmounted }
        let readWriteCount = mounted.filter(\.isReadWrite).count
        if mounted.isEmpty {
            self = .ready
        } else if readWriteCount == 0 {
            self = .allReadOnly
        } else if readWriteCount == mounted.count {
            self = .allReadWrite
        } else {
            self = .mixed
        }
    }
}

enum TrayDeviceRow {
    /// 有实测占用就跟主界面同一行文案。没有容量时只报名和状态。
    static func capacityLine(_ device: NTFSDevice) -> String? {
        guard let capacity = device.capacity else { return nil }
        return CapacityText.summary(capacity)
    }

    static func accessibilityLabel(_ device: NTFSDevice, status: String) -> String {
        if let line = capacityLine(device) {
            return "\(device.volumeName), \(status), \(line)"
        }
        return "\(device.volumeName), \(status)"
    }
}

@MainActor
final class TrayController: NSObject {
    static let shared = TrayController()
    private var item: NSStatusItem?
    private weak var model: AppModel?
    /// tearDown 之后禁止再把状态栏图标装回去。扫描回调晚到一步就会让退出变成后台驻留。
    private var tornDown = false
    private var panel: NSPanel?
    private var effectView: NSVisualEffectView?
    private var hostingView: NSHostingView<TrayPopoverRoot>?
    private var resizeStrip: TrayResizeStrip?
    private var outsideMonitors: [Any] = []
    private var lastSize: CGSize = NSSize(width: TrayLayout.width, height: 200)
    private let metrics = TrayMetrics()
    /// 拖底时 SwiftUI 尺寸回传可能滞后，不能把面板打回默认高。
    private var resizing = false
    /// 按下时记下：顶边、抓点相对底边、chrome = 面板高 − 列表高。拖动只改底边。
    private var resizeTop: CGFloat = 0
    private var resizeGrabOffset: CGFloat = 0
    private var resizeChrome: CGFloat = 0
    private lazy var trayLogo: NSImage? = {
        guard let url = Bundle.module.url(forResource: "AppIcon-white", withExtension: "icns") else { return nil }
        return NSImage(contentsOf: url)
    }()

    func attach(_ model: AppModel) {
        guard !tornDown else { return }
        self.model = model
        metrics.preferredListHeight = model.settings.trayListHeight.map { CGFloat($0) }
        metrics.prepareForShow(deviceCount: model.devices.count)
        reload()
    }

    func tearDown() {
        tornDown = true
        hidePanel()
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
        hostingView = nil
        resizeStrip = nil
        effectView = nil
        panel = nil
    }

    /// 设备列表 / 读写态变化后调用。浮层跟 SwiftUI 观察 model，这里只同步图标和位置。
    func reload() {
        guard !tornDown, let model else { return }
        ensureStatusItem()
        item?.button?.toolTip = L10n.t("tray.tooltip")
        updateStatusItemTint(from: model)
        let appearance = NSApp.appearance
        hostingView?.appearance = appearance
        effectView?.appearance = appearance
        panel?.appearance = appearance
        let previous = metrics.listHeight
        if resizing {
            metrics.listHeight = TrayListResize.clamp(
                metrics.listHeight,
                deviceCount: model.devices.count,
                contentHeight: metrics.contentHeight
            )
        } else {
            metrics.listHeight = TrayListResize.restoredListHeight(
                preferred: metrics.preferredListHeight,
                deviceCount: model.devices.count,
                contentHeight: metrics.contentHeight
            )
        }
        lastSize.height = max(lastSize.height + (metrics.listHeight - previous), 1)
        resizeStrip?.isEnabled = TrayListResize.canResize(
            deviceCount: model.devices.count,
            contentHeight: metrics.contentHeight
        )
        if panel?.isVisible == true, !resizing {
            applyFrame(lastSize)
        }
    }

    func prepareForAction() {}

    func syncAfterAction() {
        reload()
    }

    var isVisible: Bool { !tornDown && panel?.isVisible == true }

    func present() {
        guard !tornDown else { return }
        if panel?.isVisible != true {
            showPanel()
        }
    }

    func dismiss() {
        hidePanel()
    }

    @objc private func togglePanel() {
        guard !tornDown else { return }
        if panel?.isVisible == true {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func ensureStatusItem() {
        guard item == nil else { return }
        let created = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        created.button?.image = makeStatusItemImage(status: .ready)
        created.button?.image?.accessibilityDescription = "Nigate"
        created.button?.target = self
        created.button?.action = #selector(togglePanel)
        created.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
        item = created
    }

    private func showPanel() {
        guard let model else { return }
        ensurePanel(model)
        metrics.prepareForShow(deviceCount: model.devices.count)
        resizeStrip?.isEnabled = TrayListResize.canResize(
            deviceCount: model.devices.count,
            contentHeight: metrics.contentHeight
        )
        lastSize = CGSize(
            width: TrayLayout.width,
            height: TrayLayout.estimatedHeight(
                deviceCount: model.devices.count,
                hasHint: model.progressHint != nil,
                listHeight: model.devices.isEmpty ? nil : metrics.listHeight
            )
        )
        applyFrame(lastSize)
        panel?.makeKeyAndOrderFront(nil)
        startOutsideClickMonitor()
    }

    private func hidePanel() {
        if resizing {
            NSCursor.pop()
        }
        resizing = false
        stopOutsideClickMonitor()
        panel?.orderOut(nil)
    }

    private func ensurePanel(_ model: AppModel) {
        if panel != nil, hostingView != nil { return }
        let root = TrayPopoverRoot(model: model, metrics: metrics) { [weak self] size in
            Task { @MainActor in self?.handleSize(size) }
        }
        let hosted = TrayHostingView(rootView: root)
        hosted.sizingOptions = .intrinsicContentSize
        hosted.safeAreaRegions = []
        hosted.appearance = NSApp.appearance

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: lastSize))
        effect.material = .menu
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.autoresizingMask = [.width, .height]
        hosted.frame = effect.bounds
        hosted.autoresizingMask = [.width, .height]
        effect.addSubview(hosted)

        let strip = TrayResizeStrip(frame: NSRect(x: 0, y: 0, width: lastSize.width, height: TrayLayout.resizeStripHeight))
        strip.autoresizingMask = [.width]
        strip.onBegin = { [weak self] in self?.beginResize() }
        strip.onTrack = { [weak self] in self?.trackResize() }
        strip.onEnd = { [weak self] in self?.endResize() }
        effect.addSubview(strip)

        let panel = TrayPanel(
            contentRect: NSRect(origin: .zero, size: lastSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.appearance = NSApp.appearance
        panel.contentView = effect
        self.effectView = effect
        self.hostingView = hosted
        self.resizeStrip = strip
        self.panel = panel
        applyPanelShape()
    }

    private func handleSize(_ size: CGSize) {
        guard !resizing else { return }
        let next = NSSize(width: max(size.width, 1), height: max(size.height, 1))
        guard abs(next.width - lastSize.width) > 0.5 || abs(next.height - lastSize.height) > 0.5 else { return }
        lastSize = next
        guard panel?.isVisible == true else { return }
        applyFrame(next)
    }

    private func applyFrame(_ size: CGSize) {
        guard let panel else { return }
        let fitted = NSSize(width: max(size.width, 1), height: max(size.height, 1))
        let origin = panelOrigin(for: fitted)
        panel.setFrame(NSRect(origin: origin, size: fitted), display: true)
        let bounds = NSRect(origin: .zero, size: fitted)
        effectView?.frame = bounds
        hostingView?.frame = bounds
        resizeStrip?.frame = NSRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: TrayLayout.resizeStripHeight
        )
        if let strip = resizeStrip {
            panel.invalidateCursorRects(for: strip)
        }
        applyPanelShape()
    }

    /// 拖动中只改 frame：顶边钉住，底边跟鼠标。圆角和阴影放到松开后再铺。
    private func applyLiveFrame(_ size: CGSize) {
        guard let panel else { return }
        let fitted = NSSize(width: max(size.width, 1), height: max(size.height, 1))
        let origin = panelOrigin(for: fitted)
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        panel.setFrame(NSRect(origin: origin, size: fitted), display: true)
        NSAnimationContext.endGrouping()
    }

    private func beginResize() {
        resizing = true
        NSCursor.resizeUpDown.push()
        resizeChrome = max(lastSize.height - metrics.listHeight, 0)
        resizeGrabOffset = NSEvent.mouseLocation.y - (panel?.frame.minY ?? 0)
        resizeTop = panel?.frame.maxY ?? 0
    }

    /// 用鼠标绝对位置算高度，不要累加 deltaY。抓点一直贴在底边上。
    private func trackResize() {
        guard let model else { return }
        let desiredBottom = NSEvent.mouseLocation.y - resizeGrabOffset
        let desiredPanel = resizeTop - desiredBottom
        let nextList = TrayListResize.clamp(
            desiredPanel - resizeChrome,
            deviceCount: model.devices.count,
            contentHeight: metrics.contentHeight
        )
        let nextPanel = resizeChrome + nextList
        guard abs(nextPanel - lastSize.height) > 0.05 else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            metrics.listHeight = nextList
        }
        lastSize = CGSize(width: TrayLayout.width, height: nextPanel)
        applyLiveFrame(lastSize)
    }

    private func endResize() {
        guard resizing else { return }
        resizing = false
        NSCursor.pop()
        applyFrame(lastSize)
        rememberListHeight()
    }

    private func rememberListHeight() {
        guard let model else { return }
        metrics.preferredListHeight = metrics.listHeight
        let value = Double(metrics.listHeight)
        guard model.settings.trayListHeight != value else { return }
        model.settings.trayListHeight = value
        model.persist()
    }

    /// behindWindow 材质不走 CALayer 圆角，窗口仍是矩形，底角会漏出直角。
    /// maskImage 裁的是窗口 alpha；阴影才能跟着圆角走。
    private func applyPanelShape() {
        let radius = TrayLayout.cornerRadius
        if let effect = effectView {
            if effect.maskImage == nil {
                effect.maskImage = Self.stretchableRoundedMask(radius: radius)
            }
            clipRounded(effect, radius: radius)
        }
        if let hosted = hostingView {
            clipRounded(hosted, radius: radius)
        }
        panel?.invalidateShadow()
    }

    private func clipRounded(_ view: NSView, radius: CGFloat) {
        view.wantsLayer = true
        view.clipsToBounds = true
        view.layer?.cornerRadius = radius
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
    }

    private static func stretchableRoundedMask(radius: CGFloat) -> NSImage {
        let side = radius * 2 + 1
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    private func panelOrigin(for size: CGSize) -> CGPoint {
        guard let button = item?.button, let window = button.window else {
            return .zero
        }
        var buttonScreen = window.convertToScreen(button.convert(button.bounds, to: nil))
        // 状态栏窗口下沿才是菜单栏底。按钮自己的 22pt 框会缩在栏内，用更低的那条边贴。
        buttonScreen.origin.y = min(buttonScreen.minY, window.frame.minY)
        let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        return TrayPanelPlacement.origin(button: buttonScreen, size: size, visible: visible)
    }

    private func startOutsideClickMonitor() {
        stopOutsideClickMonitor()
        let mouse: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mouse, handler: { [weak self] _ in
            let point = NSEvent.mouseLocation
            Task { @MainActor in self?.dismissIfClickOutside(at: point) }
        }) {
            outsideMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mouse, handler: { [weak self] event in
            let point = event.window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
            Task { @MainActor in self?.dismissIfClickOutside(at: point) }
            return event
        }) {
            outsideMonitors.append(local)
        }
        if let escape = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            if event.keyCode == 53 {
                Task { @MainActor in self?.hidePanel() }
                return nil
            }
            return event
        }) {
            outsideMonitors.append(escape)
        }
    }

    private func stopOutsideClickMonitor() {
        for monitor in outsideMonitors {
            NSEvent.removeMonitor(monitor)
        }
        outsideMonitors.removeAll()
    }

    private func dismissIfClickOutside(at point: NSPoint) {
        guard let panel, panel.isVisible else { return }
        let statusItemFrame: NSRect?
        if let button = item?.button, let window = button.window {
            statusItemFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
        } else {
            statusItemFrame = nil
        }
        guard TrayPanelDismissal.shouldDismiss(
            at: point,
            panelFrame: panel.frame,
            statusItemFrame: statusItemFrame
        ) else { return }
        hidePanel()
    }

    private func updateStatusItemTint(from model: AppModel) {
        item?.button?.image = makeStatusItemImage(status: TrayDeviceStatus(devices: model.devices))
    }

    private func makeStatusItemImage(status: TrayDeviceStatus) -> NSImage? {
        let size = NSSize(width: 22, height: 22)
        guard let trayLogo else {
            guard let symbol = NSImage(systemSymbolName: "externaldrive.fill", accessibilityDescription: "Nigate") else {
                return nil
            }
            symbol.isTemplate = true
            return symbol
        }

        let image = NSImage(size: size)
        image.lockFocus()
        NSGraphicsContext.current?.shouldAntialias = true
        NSGraphicsContext.current?.imageInterpolation = .high

        let bounds = NSRect(origin: .zero, size: size)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.7)
        shadow.shadowBlurRadius = 1.2
        shadow.set()
        trayLogo.draw(in: bounds)
        NSShadow().set()
        drawStatusBadge(for: status)
        image.unlockFocus()

        image.isTemplate = false
        image.accessibilityDescription = "Nigate"
        return image
    }

    private func drawStatusBadge(for status: TrayDeviceStatus) {
        let badge = NSRect(x: 13.5, y: 0.5, width: 8, height: 8)
        let interior = badge.insetBy(dx: 1, dy: 1)
        NSColor.white.setFill()
        NSBezierPath(ovalIn: badge).fill()

        switch status {
        case .ready:
            NSColor.secondaryLabelColor.setFill()
            NSBezierPath(ovalIn: interior).fill()
        case .allReadWrite:
            NSColor.systemGreen.setFill()
            NSBezierPath(ovalIn: interior).fill()
        case .allReadOnly:
            NSColor.systemOrange.setFill()
            NSBezierPath(ovalIn: interior).fill()
        case .mixed:
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(ovalIn: interior).addClip()
            NSColor.systemGreen.setFill()
            NSBezierPath(rect: NSRect(x: interior.minX, y: interior.minY, width: interior.width / 2, height: interior.height)).fill()
            NSColor.systemOrange.setFill()
            NSBezierPath(rect: NSRect(x: interior.midX, y: interior.minY, width: interior.width / 2, height: interior.height)).fill()
            NSGraphicsContext.restoreGraphicsState()
        }
    }
}

/// 不激活应用也能成为 key，托盘按钮才能点。Dock 保持 accessory。
private final class TrayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// 底部拖高。mouseDragged 会跟着手势离开视图，SwiftUI 手势做不到。
/// 拖动过程只上报，高度用鼠标屏幕坐标算，不走 deltaY。
private final class TrayResizeStrip: NSView {
    var isEnabled: Bool = false {
        didSet {
            guard isEnabled != oldValue else { return }
            window?.invalidateCursorRects(for: self)
        }
    }
    var onBegin: (() -> Void)?
    var onTrack: (() -> Void)?
    var onEnd: (() -> Void)?

    override var isOpaque: Bool { false }
    override var mouseDownCanMoveWindow: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard isEnabled else { return nil }
        return super.hitTest(point)
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        onBegin?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled else { return }
        onTrack?()
    }

    override func mouseUp(with event: NSEvent) {
        onEnd?()
    }

    override func resetCursorRects() {
        if isEnabled {
            addCursorRect(bounds, cursor: .resizeUpDown)
        }
    }
}

/// 透明宿主。默认 NSHostingView 会垫一层窗口底，把菜单栏毛玻璃盖住。
private final class TrayHostingView: NSHostingView<TrayPopoverRoot> {
    override var isOpaque: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        clearBackground()
    }

    override func layout() {
        super.layout()
        clearBackground()
    }

    private func clearBackground() {
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = NSColor.clear.cgColor
    }
}
