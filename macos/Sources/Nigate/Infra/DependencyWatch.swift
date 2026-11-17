import AppKit
import Darwin
import Foundation

/// 盯 MacFUSE / ntfs-3g 所在的稳定目录，不轮询。
///
/// kqueue + `O_EVTONLY`：每个目录一只只读 fd，空闲时内核不叫醒进程。
/// 盯目录不盯文件：卸载会把文件删掉，文件 source 会跟着死。
/// 卸载脚本会连打写/删，收尾防抖后再跑 `DependencyService`。
/// 前台回来再补一枪，挡住个别安装器不碰这些目录的情况。
final class DependencyWatch: @unchecked Sendable {
    static let defaultRoots = [
        "/Library/Filesystems",
        "/usr/local/lib",
        "/usr/local/bin",
        "/usr/local/sbin",
        "/opt/homebrew/lib",
        "/opt/homebrew/bin",
        "/opt/homebrew/sbin"
    ]

    private let queue: DispatchQueue
    private let roots: [String]
    private let debounceInterval: TimeInterval
    private var sources: [String: DispatchSourceFileSystemObject] = [:]
    private var extraFiles: [String] = []
    private var running = false
    private var onChange: (@Sendable () -> Void)?
    private var debounce: DispatchWorkItem?
    private var becomeActiveToken: NSObjectProtocol?

    init(
        roots: [String] = DependencyWatch.defaultRoots,
        debounce: TimeInterval = 0.4
    ) {
        self.roots = roots
        self.debounceInterval = debounce
        self.queue = DispatchQueue(label: "io.hoochanlon.github.dep-watch")
    }

    /// 目录集合：固定安装位置 + 已解析二进制的父目录（Cellar 版本目录）。
    static func directories(extraFiles: [String] = [], roots: [String] = defaultRoots) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        func add(_ path: String) {
            guard path != "/", !path.isEmpty, seen.insert(path).inserted else { return }
            result.append(path)
        }
        for root in roots { add(root) }
        for file in extraFiles {
            guard !file.isEmpty else { continue }
            add(URL(fileURLWithPath: file).deletingLastPathComponent().path)
        }
        return result
    }

    func start(_ onChange: @escaping @Sendable () -> Void) {
        stop()
        self.onChange = onChange
        queue.async { [weak self] in
            guard let self else { return }
            self.running = true
            self.armLocked()
        }
        becomeActiveToken = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.emit()
        }
    }

    func stop() {
        debounce?.cancel()
        debounce = nil
        onChange = nil
        if let becomeActiveToken {
            NotificationCenter.default.removeObserver(becomeActiveToken)
            self.becomeActiveToken = nil
        }
        queue.sync {
            running = false
            extraFiles = []
            cancelAllLocked()
        }
    }

    func sync(extraFiles: [String]) {
        queue.async { [weak self] in
            guard let self, self.running else { return }
            self.extraFiles = extraFiles
            self.armLocked()
        }
    }

    private func armLocked() {
        guard running else { return }
        let desired = Set(
            Self.directories(extraFiles: extraFiles, roots: roots).filter {
                FileManager.default.fileExists(atPath: $0)
            }
        )
        for path in Array(sources.keys) where !desired.contains(path) {
            dropSourceLocked(path)
        }
        for path in desired where sources[path] == nil {
            if let source = makeSource(path: path) {
                sources[path] = source
            }
        }
    }

    private func makeSource(path: String) -> DispatchSourceFileSystemObject? {
        let fd = path.withCString { Darwin.open($0, O_EVTONLY | O_DIRECTORY) }
        guard fd >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.delete, .rename, .write, .extend, .link, .revoke],
            queue: queue
        )
        source.setEventHandler { [weak self, weak source] in
            guard let self else { return }
            let flags = source?.data ?? []
            if flags.contains(.delete) || flags.contains(.revoke) || flags.contains(.rename) {
                self.dropSourceLocked(path)
            }
            self.emit()
        }
        source.setCancelHandler {
            Darwin.close(fd)
        }
        source.resume()
        return source
    }

    private func dropSourceLocked(_ path: String) {
        sources[path]?.cancel()
        sources[path] = nil
    }

    private func cancelAllLocked() {
        for path in Array(sources.keys) {
            dropSourceLocked(path)
        }
    }

    private func emit() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.debounce?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.onChange?()
            }
            self.debounce = work
            DispatchQueue.main.asyncAfter(deadline: .now() + self.debounceInterval, execute: work)
        }
    }
}
