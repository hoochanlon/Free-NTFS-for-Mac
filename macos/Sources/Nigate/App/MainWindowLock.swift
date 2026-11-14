import AppKit
import SwiftUI

enum WindowLayout {
    static let width: CGFloat = 900
    static let minHeight: CGFloat = 680
}

extension View {
    @ViewBuilder
    func nigateDisableFullScreen() -> some View {
        if #available(macOS 15.0, *) {
            windowFullScreenBehavior(.disabled)
        } else {
            self
        }
    }
}

/// 照搬系统设置：绿钮是缩放（+），禁止全屏/分屏磁贴；宽度锁死，高度可拖到当前桌面可见区域。
struct MainWindowLock: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowLockView {
        WindowLockView()
    }

    func updateNSView(_ nsView: WindowLockView, context: Context) {
        nsView.applyLock()
    }
}

final class WindowLockView: NSView {
    private let lockDelegate = WindowLockDelegate()
    /// sheet 开关期间不要重装 window.delegate / setFrame，否则关闭「关于」会卡死。
    private var sheetPresented = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewWillMove(toWindow window: NSWindow?) {
        if window == nil, let current = self.window {
            lockDelegate.uninstall(from: current)
        }
        super.viewWillMove(toWindow: window)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self)
        guard let window else { return }
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didChangeScreenNotification,
            NSWindow.didEndLiveResizeNotification,
            NSWindow.didDeminiaturizeNotification,
            NSWindow.didExitFullScreenNotification,
            NSWindow.willEnterFullScreenNotification,
            NSWindow.willBeginSheetNotification,
            NSWindow.didEndSheetNotification
        ]
        for name in names {
            center.addObserver(
                self,
                selector: #selector(handleWindowChange),
                name: name,
                object: window
            )
        }
        applyLock()
        DispatchQueue.main.async { [weak self] in self?.applyLock() }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func applyLock() {
        if sheetPresented { return }
        guard window?.attachedSheet == nil else { return }
        lockDelegate.install(on: window)
    }

    @objc private func handleWindowChange(_ notification: Notification) {
        switch notification.name {
        case NSWindow.willBeginSheetNotification:
            sheetPresented = true
            return
        case NSWindow.didEndSheetNotification:
            sheetPresented = false
            DispatchQueue.main.async { [weak self] in self?.applyLock() }
            return
        case NSWindow.willEnterFullScreenNotification:
            if let window = notification.object as? NSWindow {
                WindowLock.denyFullScreen(window)
            }
        default:
            break
        }
        applyLock()
    }
}

@MainActor
enum WindowLock {
    static func denyFullScreen(_ window: NSWindow) {
        applyCollectionBehavior(window)
        if let button = window.standardWindowButton(.zoomButton) {
            button.action = #selector(NSWindow.zoom(_:))
            button.target = window
        }
        if window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
    }

    static func applyCollectionBehavior(_ window: NSWindow) {
        var behavior = window.collectionBehavior
        behavior.remove(.fullScreenPrimary)
        behavior.remove(.fullScreenAuxiliary)
        behavior.remove(.fullScreenAllowsTiling)
        behavior.insert(.fullScreenNone)
        behavior.insert(.fullScreenDisallowsTiling)
        if window.collectionBehavior != behavior {
            window.collectionBehavior = behavior
        }
    }
}

/// 转发 SwiftUI 原有 delegate，只拦截拖拽宽度和绿钮缩放。
@MainActor
final class WindowLockDelegate: NSObject, NSWindowDelegate {
    nonisolated(unsafe) weak var forwarding: NSWindowDelegate?

    func install(on window: NSWindow?) {
        guard let window, window.attachedSheet == nil else { return }
        if window.delegate === self {
            constrain(window)
            return
        }
        if let existing = window.delegate as? WindowLockDelegate, existing !== self {
            // 切语言会重建 lock view。若把旧 lock 链进 forwarding，旧对象释放后
            // SwiftUI 原 delegate 丢失，关闭「关于」等 sheet 会卡死。
            forwarding = existing.forwarding ?? forwarding
            existing.forwarding = nil
        } else if forwarding == nil, let current = window.delegate {
            forwarding = current
        }
        window.delegate = self
        constrain(window)
    }

    func uninstall(from window: NSWindow) {
        guard window.delegate === self else { return }
        window.delegate = forwarding
    }

    func constrain(_ window: NSWindow) {
        guard window.attachedSheet == nil else { return }
        WindowLock.applyCollectionBehavior(window)

        if !window.styleMask.contains(.resizable) {
            window.styleMask.insert(.resizable)
        }

        if let button = window.standardWindowButton(.zoomButton) {
            button.action = #selector(NSWindow.zoom(_:))
            button.target = window
        }

        if window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
            return
        }

        let limits = sizeLimits(for: window)
        if window.minSize != limits.min { window.minSize = limits.min }
        if window.maxSize != limits.max { window.maxSize = limits.max }

        guard !window.inLiveResize else { return }
        let locked = lockedFrame(window.frame, on: window)
        if abs(window.frame.width - locked.width) > 0.5
            || abs(window.frame.height - locked.height) > 0.5 {
            window.setFrame(locked, display: true)
        }
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        let proposed = forwarding?.windowWillResize?(sender, to: frameSize) ?? frameSize
        let limits = sizeLimits(for: sender)
        return NSSize(
            width: WindowLayout.width,
            height: min(max(proposed.height, limits.min.height), limits.max.height)
        )
    }

    /// 系统设置的绿钮缩放：铺满当前桌面可见高度，宽度不变，不进全屏空间。
    func windowWillUseStandardFrame(_ window: NSWindow, defaultFrame newFrame: NSRect) -> NSRect {
        let visible = window.screen?.visibleFrame ?? newFrame
        var frame = window.frame
        frame.size.width = WindowLayout.width
        frame.size.height = visible.height
        frame.origin.y = visible.origin.y
        frame.origin.x = min(
            max(frame.origin.x, visible.minX),
            visible.maxX - frame.size.width
        )
        return frame
    }

    func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
        forwarding?.windowShouldZoom?(window, toFrame: newFrame) ?? true
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        forwarding
    }

    override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || ((forwarding as AnyObject?)?.responds(to: aSelector) ?? false)
    }

    private func sizeLimits(for window: NSWindow) -> (min: NSSize, max: NSSize) {
        let maxHeight = max(
            WindowLayout.minHeight,
            window.screen?.visibleFrame.height ?? WindowLayout.minHeight
        )
        return (
            NSSize(width: WindowLayout.width, height: WindowLayout.minHeight),
            NSSize(width: WindowLayout.width, height: maxHeight)
        )
    }

    private func lockedFrame(_ frame: NSRect, on window: NSWindow) -> NSRect {
        let limits = sizeLimits(for: window)
        var next = frame
        if abs(next.width - WindowLayout.width) > 0.5 {
            next.origin.x += (next.width - WindowLayout.width) / 2
            next.size.width = WindowLayout.width
        }
        if next.height < limits.min.height {
            next.origin.y -= limits.min.height - next.height
            next.size.height = limits.min.height
        } else if next.height > limits.max.height + 0.5 {
            next.size.height = limits.max.height
        }
        return next
    }
}
