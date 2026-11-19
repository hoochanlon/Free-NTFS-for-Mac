import Foundation
import DiskArbitration
import AppKit

final class DiskMonitor: @unchecked Sendable {
    /// 不能挂在 main 上。退出时若在 session 自己的队列里 SetDispatchQueue(nil)，主线程会死锁，进程就留在 Dock。
    private let sessionQueue = DispatchQueue(label: "io.hoochanlon.github.disk-monitor")
    private var session: DASession?
    private var onChange: (@Sendable () -> Void)?
    /// 物理消失：立刻回调 BSD 名，不等 debounce。猛拔时挂载表还在，全量扫描会拖几秒。
    private var onDisappeared: (@Sendable (_ bsdName: String) -> Void)?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var debounce: DispatchWorkItem?

    func start(
        onDisappeared: (@Sendable (_ bsdName: String) -> Void)? = nil,
        _ onChange: @escaping @Sendable () -> Void
    ) {
        stop()
        self.onChange = onChange
        self.onDisappeared = onDisappeared
        let session = DASessionCreate(kCFAllocatorDefault)
        self.session = session
        guard let session else { return }
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        DARegisterDiskAppearedCallback(session, nil, { _, ctx in
            DiskMonitor.ping(ctx)
        }, ctx)
        DARegisterDiskDisappearedCallback(session, nil, { disk, ctx in
            DiskMonitor.pingDisappeared(disk, ctx)
        }, ctx)
        DARegisterDiskDescriptionChangedCallback(session, nil, nil, { _, _, ctx in
            DiskMonitor.ping(ctx)
        }, ctx)
        DASessionSetDispatchQueue(session, sessionQueue)

        let center = NSWorkspace.shared.notificationCenter
        let names: [NSNotification.Name] = [
            NSWorkspace.didMountNotification,
            NSWorkspace.didUnmountNotification,
            NSWorkspace.didRenameVolumeNotification
        ]
        for name in names {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.emitChange()
            }
            workspaceObservers.append(token)
        }
    }

    func stop() {
        debounce?.cancel()
        debounce = nil
        onChange = nil
        onDisappeared = nil
        if let session {
            DASessionSetDispatchQueue(session, nil)
            self.session = nil
        }
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        workspaceObservers.removeAll()
    }

    private static func ping(_ ctx: UnsafeMutableRawPointer?) {
        guard let ctx else { return }
        Unmanaged<DiskMonitor>.fromOpaque(ctx).takeUnretainedValue().emitChange()
    }

    private static func pingDisappeared(_ disk: DADisk, _ ctx: UnsafeMutableRawPointer?) {
        guard let ctx else { return }
        let monitor = Unmanaged<DiskMonitor>.fromOpaque(ctx).takeUnretainedValue()
        if let bsd = bsdName(of: disk) {
            monitor.emitDisappeared(bsd)
        }
        monitor.emitChange()
    }

    private static func bsdName(of disk: DADisk) -> String? {
        guard let raw = DADiskCopyDescription(disk) else { return nil }
        let desc = raw as NSDictionary
        let key = kDADiskDescriptionMediaBSDNameKey as String
        guard let name = desc[key] as? String, !name.isEmpty else { return nil }
        return name
    }

    private func emitDisappeared(_ bsdName: String) {
        let callback = onDisappeared
        DispatchQueue.main.async {
            callback?(bsdName)
        }
    }

    private func emitChange() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.onChange?()
        }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }
}
