import AppKit

@MainActor
final class TrayController {
    static let shared = TrayController()
    private var item: NSStatusItem?
    private weak var model: AppModel?

    func attach(_ model: AppModel) {
        self.model = model
        reload()
    }

    func tearDown() {
        if let item { NSStatusBar.system.removeStatusItem(item) }
        item = nil
    }

    func reload() {
        guard let model else { return }
        if !model.settings.trayMode {
            tearDown()
            return
        }
        if item == nil {
            let created = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            created.button?.image = NSImage(systemSymbolName: "externaldrive.fill", accessibilityDescription: "Nigate")
            created.button?.image?.isTemplate = true
            item = created
        }
        item?.menu = buildMenu(model)
        item?.button?.toolTip = L10n.t("tray.tooltip")
    }

    private func buildMenu(_ model: AppModel) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(action(L10n.t("tray.showMainWindow")) {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        })
        menu.addItem(.separator())
        if model.devices.isEmpty {
            let empty = NSMenuItem(title: L10n.t("devices.emptyState"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for device in model.devices {
                let item = NSMenuItem(title: "\(device.volumeName)  ·  \(device.isReadWrite ? L10n.t("devices.readWrite") : L10n.t("devices.readOnly"))", action: nil, keyEquivalent: "")
                let sub = NSMenu()
                sub.addItem(action(L10n.t("devices.mount")) { model.perform(.mount, on: device) })
                sub.addItem(action(L10n.t("devices.restoreReadOnly")) { model.perform(.restore, on: device) })
                sub.addItem(action(L10n.t("devices.unmount")) { model.perform(.unmount, on: device) })
                sub.addItem(action(L10n.t("devices.eject")) { model.perform(.eject, on: device) })
                item.submenu = sub
                menu.addItem(item)
            }
        }
        menu.addItem(.separator())
        menu.addItem(action(L10n.t("devices.mountAll")) { model.runBatch(.mount) })
        menu.addItem(action(L10n.t("devices.restoreAllReadOnly")) { model.runBatch(.restore) })
        menu.addItem(action(L10n.t("devices.ejectAll")) { model.runBatch(.eject) })
        menu.addItem(.separator())
        menu.addItem(action(L10n.t("tray.quit")) { NSApp.terminate(nil) })
        return menu
    }

    private func action(_ title: String, _ handler: @escaping () -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(TrayActionProxy.run), keyEquivalent: "")
        let proxy = TrayActionProxy(handler)
        item.target = proxy
        objc_setAssociatedObject(item, &trayProxyKey, proxy, .OBJC_ASSOCIATION_RETAIN)
        return item
    }
}

@MainActor
private var trayProxyKey: UInt8 = 0

private final class TrayActionProxy: NSObject {
    let handler: () -> Void
    init(_ handler: @escaping () -> Void) { self.handler = handler }
    @objc func run() { handler() }
}
