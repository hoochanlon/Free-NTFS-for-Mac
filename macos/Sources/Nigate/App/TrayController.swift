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
    private var hostingView: NSHostingView<TrayPopoverRoot>?
    private var outsideMonitors: [Any] = []
    private var lastSize: CGSize = NSSize(width: TrayLayout.width, height: 200)
    private lazy var trayLogo: NSImage? = {
        guard let url = Bundle.module.url(forResource: "AppIcon-white", withExtension: "icns") else { return nil }
        return NSImage(contentsOf: url)
    }()

    func attach(_ model: AppModel) {
        guard !tornDown else { return }
        self.model = model
        reload()
    }

    func tearDown() {
        tornDown = true
        hidePanel()
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
        hostingView = nil
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
        panel?.appearance = appearance
        if panel?.isVisible == true {
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
        created.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item = created
    }

    private func showPanel() {
        guard let model else { return }
        ensurePanel(model)
        lastSize = CGSize(
            width: TrayLayout.width,
            height: TrayLayout.estimatedHeight(
                deviceCount: model.devices.count,
                hasHint: model.progressHint != nil
            )
        )
        applyFrame(lastSize)
        panel?.makeKeyAndOrderFront(nil)
        startOutsideClickMonitor()
    }

    private func hidePanel() {
        stopOutsideClickMonitor()
        panel?.orderOut(nil)
        if !tornDown, model?.quitPhase == .confirming {
            model?.cancelQuit()
        }
    }

    private func ensurePanel(_ model: AppModel) {
        if panel != nil, hostingView != nil { return }
        let root = TrayPopoverRoot(model: model) { [weak self] size in
            Task { @MainActor in self?.handleSize(size) }
        }
        let hosted = NSHostingView(rootView: root)
        hosted.sizingOptions = .intrinsicContentSize
        hosted.wantsLayer = true
        hosted.layer?.cornerRadius = 16
        hosted.layer?.masksToBounds = true
        hosted.appearance = NSApp.appearance

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
        panel.contentView = hosted
        self.hostingView = hosted
        self.panel = panel
    }

    private func handleSize(_ size: CGSize) {
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
        hostingView?.frame = NSRect(origin: .zero, size: fitted)
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
            Task { @MainActor in self?.dismissIfClickOutside() }
        }) {
            outsideMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mouse, handler: { [weak self] event in
            Task { @MainActor in self?.dismissIfClickOutside() }
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

    private func dismissIfClickOutside() {
        guard let panel, panel.isVisible else { return }
        let mouse = NSEvent.mouseLocation
        if panel.frame.contains(mouse) { return }
        if let button = item?.button, let window = button.window {
            let buttonScreen = window.convertToScreen(button.convert(button.bounds, to: nil))
            if buttonScreen.contains(mouse) { return }
        }
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
