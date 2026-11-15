import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mainWindowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
        // Dock / Finder 走 Info.plist 的 CFBundleIconFile。
        // 运行时改 applicationIconImage 会跳过系统对 App 图标的遮罩和网格留白，
        // Dock 里会显得比 Chrome / VS Code 更大，也和 Finder 里的 .app 图标对不上。
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 状态栏窗口还在时，系统不会把这次关闭当成「最后一个窗口」，所以这里经常进不来。
        // 真正收进菜单栏的逻辑在 mainWindowWillClose。
        guard let model, !model.suppressesTrayWithdraw else { return false }
        model.withdrawToTray()
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model else { return .terminateNow }
        if model.quitPhase == .exiting {
            for window in NSApp.windows {
                if let sheet = window.attachedSheet {
                    window.endSheet(sheet)
                }
            }
            if NSApp.modalWindow != nil { NSApp.stopModal() }
            model.shutdown()
            return .terminateNow
        }
        // Dock「退出」仍会直接 terminate。先进入确认，再取消这次终止。
        // 取消前若已切到 accessory，SwiftUI 关掉窗口后 Dock 会留下「停止在后台运行」。
        model.armQuitConfirm()
        model.revealMainWindow()
        DispatchQueue.main.async {
            model.presentQuitConfirm()
        }
        return .terminateCancel
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

    @objc private func mainWindowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        let isMain = window.title == "Nigate" || window.identifier?.rawValue == "main"
        guard isMain else { return }
        guard let model else { return }
        if model.quitPhase == .confirming {
            // 终止被取消时 SwiftUI 仍可能关掉主窗口。拉回来，否则进程会以「后台运行」留在 Dock。
            DispatchQueue.main.async { model.presentQuitConfirm() }
            return
        }
        guard !model.suppressesTrayWithdraw else { return }
        let mainStillVisible = NSApp.windows.contains {
            $0 !== window && $0.isVisible && ($0.title == "Nigate" || $0.identifier?.rawValue == "main")
        }
        if !mainStillVisible {
            model.withdrawToTray()
        }
    }
}
