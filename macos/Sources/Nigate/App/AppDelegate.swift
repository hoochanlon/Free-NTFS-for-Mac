import AppKit
import Darwin
import SwiftUI

extension Notification.Name {
    static let nigateReveal = Notification.Name("io.hoochanlon.github.reveal")
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // 第二次双击不能再留一个无窗口进程。锁失败就唤醒已有实例然后立刻结束。
        guard InstanceLock.acquire() else {
            let bundleID = Bundle.main.bundleIdentifier ?? "io.hoochanlon.github"
            NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .first { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }?
                .activate(options: [.activateAllWindows])
            DistributedNotificationCenter.default().postNotificationName(
                .nigateReveal,
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
            Darwin._exit(0)
        }
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(revealFromSecondLaunch),
            name: .nigateReveal,
            object: nil
        )
        // 保持 Info.plist 的菜单栏代理。窗口还没出现就升成 regular，
        // 慢启动时 Dock 会先写出「正在后台运行」，退出也摘不掉。
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        // 退出过程中如果还返回 false，进程会以无窗口的 regular 应用留在 Dock，文案就是「正在后台运行」。
        guard let model else {
            Darwin._exit(0)
        }
        if model.quitPhase != .idle {
            model.quitImmediately()
            return true
        }
        model.withdrawToTray()
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // 不能取消。取消一次后，系统后续退出不再回调，Dock 只剩「正在后台运行」。
        if let model {
            model.quitImmediately()
        }
        Darwin._exit(0)
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
        if model.quitPhase != .idle {
            // 确认框依附主窗口。窗口没了还去拉起，只会把 Dock 图标带回来，进程继续活着。
            let closing = window
            DispatchQueue.main.async {
                let stillVisible = NSApp.windows.contains {
                    $0 !== closing && $0.isVisible && ($0.title == "Nigate" || $0.identifier?.rawValue == "main")
                }
                if !stillVisible {
                    model.quitImmediately()
                }
            }
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

    @objc private func revealFromSecondLaunch() {
        model?.revealMainWindow()
    }
}

/// 同一用户只能留一个 Nigate。文件锁随进程结束释放，不依赖窗口或 Dock 状态。
@MainActor
enum InstanceLock {
    private static var fd: Int32 = -1

    static func acquire() -> Bool {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let directory = (root ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("Nigate", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent("instance.lock").path
        let opened = open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard opened >= 0 else { return true }
        if flock(opened, LOCK_EX | LOCK_NB) != 0 {
            close(opened)
            return false
        }
        fd = opened
        return true
    }
}
