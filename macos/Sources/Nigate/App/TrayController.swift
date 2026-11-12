import AppKit

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

@MainActor
final class TrayController: NSObject, NSMenuDelegate {
    static let shared = TrayController()
    private var item: NSStatusItem?
    private weak var model: AppModel?
    private let menu = NSMenu()
    private lazy var trayLogo: NSImage? = {
        guard let url = Bundle.module.url(forResource: "AppIcon-white", withExtension: "icns") else { return nil }
        return NSImage(contentsOf: url)
    }()
    /// 菜单打开期间禁止 removeAllItems：否则移入子菜单会被拆掉。
    private var menuIsOpen = false

    override init() {
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
    }

    func attach(_ model: AppModel) {
        self.model = model
        reload()
    }

    func tearDown() {
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
        menuIsOpen = false
        menu.removeAllItems()
    }

    /// 设备列表 / 读写态变化后调用。
    /// - 状态栏图标：始终更新
    /// - 菜单结构：仅在关闭时 rebuild；打开时只改已有行的颜色，避免子菜单消失
    func reload() {
        guard let model else { return }
        if !model.settings.trayMode {
            tearDown()
            return
        }
        ensureStatusItem()
        item?.button?.toolTip = L10n.t("tray.tooltip")
        // 图标始终跟 model，不依赖是否打开主窗口。
        updateStatusItemTint(from: model)

        if menuIsOpen {
            updateOpenMenuDeviceRows(from: model)
        } else {
            rebuildMenu(from: model)
        }
    }

    /// 托盘动作已点下：菜单即将关闭。清掉 open 标记，让后续异步结果能立刻 sync。
    func prepareForAction() {
        menuIsOpen = false
    }

    /// 挂载等异步操作结束后强制与 model 对齐（不依赖主窗口激活）。
    func syncAfterAction() {
        menuIsOpen = false
        reload()
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === self.menu else { return }
        menuIsOpen = true
        if let model {
            // 打开瞬间用最新 model 建树；打开后只允许改色，不再拆树。
            rebuildMenu(from: model)
            updateStatusItemTint(from: model)
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        guard menu === self.menu else { return }
        menuIsOpen = false
        // 关闭后再全量 sync 一次，吃掉打开期间积压的设备变化。
        reload()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {}

    private func ensureStatusItem() {
        guard item == nil else { return }
        let created = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        created.button?.image = makeStatusItemImage(status: .ready)
        created.button?.image?.accessibilityDescription = "Nigate"
        created.menu = menu
        item = created
    }

    private func rebuildMenu(from model: AppModel) {
        menu.removeAllItems()
        menu.addItem(action(L10n.t("tray.showMainWindow")) {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
            // 点主界面时也拉一次设备，避免托盘与主界面长期分叉。
            Task { await model.refreshDevices(applyAutoMount: false) }
        })
        menu.addItem(.separator())
        if model.devices.isEmpty {
            let empty = NSMenuItem(title: L10n.t("devices.emptyState"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for device in model.devices {
                menu.addItem(deviceRow(device, model: model))
            }
        }
        menu.addItem(.separator())
        menu.addItem(action(L10n.t("devices.mountAll")) { model.runBatch(.mount) })
        menu.addItem(action(L10n.t("devices.restoreAllReadOnly")) { model.runBatch(.restore) })
        menu.addItem(action(L10n.t("devices.ejectAll")) { model.runBatch(.eject) })
        menu.addItem(.separator())
        menu.addItem(action(L10n.t("tray.quit")) { NSApp.terminate(nil) })
    }

    private func deviceRow(_ device: NTFSDevice, model: AppModel) -> NSMenuItem {
        let status = device.isReadWrite ? L10n.t("devices.readWrite") : L10n.t("devices.readOnly")
        let row = NSMenuItem(title: device.volumeName, action: nil, keyEquivalent: "")
        row.representedObject = DeviceMenuRef(identity: device.identity, disk: device.disk)
        row.image = statusImage(for: device, accessibilityDescription: status)
        row.setAccessibilityLabel("\(device.volumeName), \(status)")
        row.isEnabled = true

        let sub = NSMenu()
        sub.autoenablesItems = false
        let identity = device.identity
        let disk = device.disk
        sub.addItem(action(L10n.t("devices.mount")) {
            TrayController.shared.prepareForAction()
            guard let latest = Self.device(in: model, identity: identity, disk: disk) else { return }
            model.perform(.mount, on: latest)
        })
        sub.addItem(action(L10n.t("devices.restoreReadOnly")) {
            TrayController.shared.prepareForAction()
            guard let latest = Self.device(in: model, identity: identity, disk: disk) else { return }
            model.perform(.restore, on: latest)
        })
        sub.addItem(action(L10n.t("devices.unmount")) {
            TrayController.shared.prepareForAction()
            guard let latest = Self.device(in: model, identity: identity, disk: disk) else { return }
            model.perform(.unmount, on: latest)
        })
        sub.addItem(action(L10n.t("devices.eject")) {
            TrayController.shared.prepareForAction()
            guard let latest = Self.device(in: model, identity: identity, disk: disk) else { return }
            model.perform(.eject, on: latest)
        })
        row.submenu = sub
        return row
    }

    /// 不拆菜单树，只刷新设备行标题旁的橙/绿图标。
    private func updateOpenMenuDeviceRows(from model: AppModel) {
        for item in menu.items {
            guard let ref = item.representedObject as? DeviceMenuRef else { continue }
            guard let device = Self.device(in: model, identity: ref.identity, disk: ref.disk) else { continue }
            let status = device.isReadWrite ? L10n.t("devices.readWrite") : L10n.t("devices.readOnly")
            item.title = device.volumeName
            item.image = statusImage(for: device, accessibilityDescription: status)
            item.setAccessibilityLabel("\(device.volumeName), \(status)")
        }
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

    private static func device(in model: AppModel, identity: String, disk: String) -> NTFSDevice? {
        model.devices.first { $0.identity == identity || $0.disk == disk || $0.devicePath.hasSuffix(disk) }
    }

    private func statusImage(for device: NTFSDevice, accessibilityDescription: String) -> NSImage? {
        guard let image = NSImage(systemSymbolName: "externaldrive.fill", accessibilityDescription: accessibilityDescription) else {
            return nil
        }
        let color: NSColor = device.isReadWrite ? .systemGreen : .systemOrange
        let configured = image.withSymbolConfiguration(.init(paletteColors: [color])) ?? image
        configured.isTemplate = false
        return configured
    }

    private func action(_ title: String, _ handler: @escaping @MainActor () -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(TrayActionProxy.run), keyEquivalent: "")
        item.isEnabled = true
        let proxy = TrayActionProxy(handler)
        item.target = proxy
        objc_setAssociatedObject(item, &trayProxyKey, proxy, .OBJC_ASSOCIATION_RETAIN)
        return item
    }
}

/// 菜单行与设备的稳定关联（不用 title 匹配，避免改名后丢刷新）。
private final class DeviceMenuRef: NSObject {
    let identity: String
    let disk: String
    init(identity: String, disk: String) {
        self.identity = identity
        self.disk = disk
        super.init()
    }
}

@MainActor
private var trayProxyKey: UInt8 = 0

private final class TrayActionProxy: NSObject, @unchecked Sendable {
    private let handler: @MainActor () -> Void
    init(_ handler: @escaping @MainActor () -> Void) { self.handler = handler }

    @objc func run() {
        Task { @MainActor in
            TrayController.shared.prepareForAction()
            handler()
        }
    }
}
