import Foundation

@MainActor
final class SleepGuard {
    private var process: Process?
    private var iostat: Process?
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
    }

    private func startCaffeinate() {
        if process?.isRunning == true { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        proc.arguments = ["-i", "-m"]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        process = proc
    }

    private func stopCaffeinate() {
        process?.terminate()
        process = nil
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
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in
                self?.ingest(text)
            }
        }
        try? proc.run()
        iostat = proc
    }

    private func stopIostat() {
        iostat?.terminate()
        iostat?.standardOutput = nil
        iostat = nil
    }

    private func ingest(_ text: String) {
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
                    self?.stopCaffeinate()
                }
            }
        }
    }
}
