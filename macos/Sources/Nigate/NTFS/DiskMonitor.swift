import Foundation
import DiskArbitration
import AppKit

final class DiskMonitor: @unchecked Sendable {
    private var session: DASession?
    private var onChange: (@Sendable () -> Void)?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var debounce: DispatchWorkItem?

    func start(_ onChange: @escaping @Sendable () -> Void) {
        stop()
        self.onChange = onChange
        let session = DASessionCreate(kCFAllocatorDefault)
        self.session = session
        guard let session else { return }
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        DARegisterDiskAppearedCallback(session, nil, { _, ctx in
            DiskMonitor.ping(ctx)
        }, ctx)
        DARegisterDiskDisappearedCallback(session, nil, { _, ctx in
            DiskMonitor.ping(ctx)
        }, ctx)
        DARegisterDiskDescriptionChangedCallback(session, nil, nil, { _, _, ctx in
            DiskMonitor.ping(ctx)
        }, ctx)
        DASessionSetDispatchQueue(session, DispatchQueue.main)

        let center = NSWorkspace.shared.notificationCenter
        let names: [NSNotification.Name] = [
            NSWorkspace.didMountNotification,
            NSWorkspace.didUnmountNotification,
            NSWorkspace.didRenameVolumeNotification
        ]
        for name in names {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.emit()
            }
            workspaceObservers.append(token)
        }
    }

    func stop() {
        session = nil
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        workspaceObservers.removeAll()
        debounce?.cancel()
        onChange = nil
    }

    private static func ping(_ ctx: UnsafeMutableRawPointer?) {
        guard let ctx else { return }
        Unmanaged<DiskMonitor>.fromOpaque(ctx).takeUnretainedValue().emit()
    }

    private func emit() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.onChange?()
        }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }
}
