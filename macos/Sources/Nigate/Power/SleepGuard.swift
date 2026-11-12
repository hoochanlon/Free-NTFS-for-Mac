import Foundation

@MainActor
final class SleepGuard {
    private var process: Process?
    private var iostat: Process?
    private var iostatOutput: FileHandle?
    private var mode: SleepMode = .off
    private var disks: [String] = []
    private var lastActive = Date.distantPast
    private var idleTimer: Timer?
    private let idleHold: TimeInterval = 20

    var isActive: Bool { process?.isRunning == true }

    func setMode(_ mode: SleepMode, disks: [String]) {
        self.mode = mode
        self.disks = disks
        idleTimer?.invalidate()
        idleTimer = nil
        switch mode {
        case .off:
            stopCaffeinate()
            stopIostat()
        case .always:
            stopIostat()
            startCaffeinate()
        case .smart:
            if disks.isEmpty {
                stopCaffeinate()
                stopIostat()
            } else {
                startIostat()
            }
        }
    }

    func stop() {
        mode = .off
        stopCaffeinate()
        stopIostat()
        idleTimer?.invalidate()
        idleTimer = nil
    }

    private func startCaffeinate() {
        if process?.isRunning == true { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        proc.arguments = ["-i", "-m"]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            process = proc
        } catch {
            process = nil
        }
    }

    private func stopCaffeinate() {
        guard let proc = process else { return }
        process = nil
        if proc.isRunning {
            proc.terminate()
        }
    }

    private func startIostat() {
        stopIostat()
        guard !disks.isEmpty else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/iostat")
        proc.arguments = ["-d", "-w", "1"] + disks
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { [weak self] file in
            let data = file.availableData
            // EOF / 空包：卸掉 handler，避免主线程被空回调刷死。
            guard !data.isEmpty else {
                file.readabilityHandler = nil
                return
            }
            guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return }
            Task { @MainActor [weak self] in
                self?.ingest(text)
            }
        }
        do {
            try proc.run()
            iostat = proc
            iostatOutput = handle
        } catch {
            handle.readabilityHandler = nil
            iostat = nil
            iostatOutput = nil
        }
    }

    private func stopIostat() {
        let handle = iostatOutput
        let proc = iostat
        iostatOutput = nil
        iostat = nil
        // 先摘 handler，再 terminate，避免 EOF 风暴打到 MainActor。
        handle?.readabilityHandler = nil
        if let proc, proc.isRunning {
            proc.terminate()
        }
    }

    private func ingest(_ text: String) {
        guard mode == .smart else { return }
        let active = text.split(whereSeparator: \.isNewline).contains { line in
            let nums = line.split(whereSeparator: \.isWhitespace).compactMap { Double($0) }
            guard nums.count >= 3 else { return false }
            var i = 0
            while i + 2 < nums.count {
                if nums[i + 1] >= 1 || nums[i + 2] >= 0.01 { return true }
                i += 3
            }
            return false
        }
        if active {
            lastActive = Date()
            startCaffeinate()
            idleTimer?.invalidate()
            idleTimer = Timer.scheduledTimer(withTimeInterval: idleHold, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.mode == .smart else { return }
                    self.stopCaffeinate()
                }
            }
        }
    }
}
