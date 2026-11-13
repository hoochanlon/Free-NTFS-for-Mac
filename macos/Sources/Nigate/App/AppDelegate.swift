import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        // Dock / Finder 走 Info.plist 的 CFBundleIconFile。
        // 运行时改 applicationIconImage 会跳过系统对 App 图标的遮罩和网格留白，
        // Dock 里会显得比 Chrome / VS Code 更大，也和 Finder 里的 .app 图标对不上。
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        model?.withdrawToTray()
        return false
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
        if !flag {
            model?.revealMainWindow()
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.shutdown()
    }
}
