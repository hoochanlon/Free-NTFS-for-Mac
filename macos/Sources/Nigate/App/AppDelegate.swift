import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let appIcon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = appIcon
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !(model?.settings.trayMode ?? false)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.t("tray.quitConfirmTitle")
        alert.informativeText = L10n.t("tray.quitConfirmMessage")
        alert.icon = NSApp.applicationIconImage
        alert.addButton(withTitle: L10n.t("tray.quit"))
        alert.addButton(withTitle: L10n.t("dialog.cancel"))

        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if model?.settings.trayMode == true { return false }
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.shutdown()
    }
}
