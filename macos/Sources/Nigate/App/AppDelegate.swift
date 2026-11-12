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
        let confirmed = ConfirmAlert.run(
            .init(
                title: L10n.t("tray.quitConfirmTitle"),
                message: L10n.t("tray.quitConfirmMessage"),
                symbolName: "power.circle",
                style: .warning,
                continueTitle: L10n.t("tray.quit"),
                cancelTitle: L10n.t("dialog.cancel"),
                minContentWidth: 420
            )
        )
        return confirmed ? .terminateNow : .terminateCancel
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
