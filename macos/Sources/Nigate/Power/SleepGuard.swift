import AppKit
import Foundation
import IOKit.pwr_mgt

/// iostat 设备行：每盘三个数 KB/t、tps、MB/s。
enum SleepIOStats {
    /// 真实传输门槛：避开 Spotlight / diskutil / FUSE 心跳的零星 I/O。
    static let busyTPS = 8.0
    static let busyMBs = 0.1

    static func numericRows(in text: String) -> [[Double]] {
        text.split(whereSeparator: \.isNewline).compactMap { line in
            let nums = line.split(whereSeparator: \.isWhitespace).compactMap { Double($0) }
            guard nums.count >= 3, nums.count % 3 == 0 else { return nil }
            return Array(nums)
        }
    }

    static func isBusy(_ row: [Double]) -> Bool {
        var i = 0
        while i + 2 < row.count {
            if row[i + 1] >= busyTPS || row[i + 2] >= busyMBs { return true }
            i += 3
        }
        return false
    }
}

@MainActor
final class SleepGuard {
    private var displayAssertion = IOPMAssertionID(0)
    private var systemAssertion = IOPMAssertionID(0)
    private var hasDisplayAssertion = false
    private var hasSystemAssertion = false
    private var activity: NSObjectProtocol?
    private var caffeinate: Process?
    private var iostat: Process?
    private var iostatOutput: FileHandle?
    private var mode: SleepMode = .off
    private var disks: [String] = []
    private var idleTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var screenSleepObserver: NSObjectProtocol?
    private var wantHold = false
    private var skipBootstrapSample = true
    private var busyStreak = 0
    private var stoppingIostat = false
    private let idleHold: TimeInterval = 20
    private let assertionName = "Nigate Prevent Sleep" as CFString

    init() {
        let center = NSWorkspace.shared.notificationCenter
        wakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reacquireIfAlways()
            }
        }
        screenSleepObserver = center.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reacquireIfAlways()
            }
        }
    }

    var isActive: Bool { wantHold && (hasDisplayAssertion || hasSystemAssertion || caffeinate?.isRunning == true) }

    func setMode(_ mode: SleepMode, disks: [String]) {
        let previous = self.mode
        let previousDisks = self.disks
        self.mode = mode
        self.disks = disks
        switch mode {
        case .off:
            resetSmartTracking()
            stopIostat()
            holdIdle(false)
        case .always:
            resetSmartTracking()
            stopIostat()
            holdIdle(true)
        case .smart:
            if disks.isEmpty {
                resetSmartTracking()
                stopIostat()
                holdIdle(false)
            } else {
                if previous != .smart {
                    resetSmartTracking()
                    holdIdle(false)
                }
                let iostatRunning = iostat?.isRunning == true
                if previous != .smart || previousDisks != disks || !iostatRunning {
                    startIostat()
                }
            }
        }
    }

    func stop() {
        mode = .off
        holdIdle(false)
        stopIostat()
        resetSmartTracking()
        let center = NSWorkspace.shared.notificationCenter
        if let wakeObserver { center.removeObserver(wakeObserver) }
        if let screenSleepObserver { center.removeObserver(screenSleepObserver) }
        wakeObserver = nil
        screenSleepObserver = nil
    }

    private func resetSmartTracking() {
        idleTimer?.invalidate()
        idleTimer = nil
        skipBootstrapSample = true
        busyStreak = 0
    }

    private func holdIdle(_ on: Bool) {
        wantHold = on
        if on {
            acquire()
        } else {
            release()
        }
    }

    private func reacquireIfAlways() {
        guard mode == .always, wantHold else { return }
        releaseAssertionsAndFallback()
        acquire()
    }

    private func acquire() {
        let displayOK = ensureAssertion(
            type: kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            id: &displayAssertion,
            held: &hasDisplayAssertion
        )
        let systemOK = ensureAssertion(
            type: kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            id: &systemAssertion,
            held: &hasSystemAssertion
        )
        ensureActivity()
        if displayOK {
            if systemOK { stopCaffeinate() }
            return
        }
        startCaffeinate()
    }

    private func release() {
        releaseAssertionsAndFallback()
        endActivity()
    }

    private func releaseAssertionsAndFallback() {
        if hasDisplayAssertion {
            IOPMAssertionRelease(displayAssertion)
            hasDisplayAssertion = false
            displayAssertion = 0
        }
        if hasSystemAssertion {
            IOPMAssertionRelease(systemAssertion)
            hasSystemAssertion = false
            systemAssertion = 0
        }
        stopCaffeinate()
    }

    private func ensureAssertion(
        type: CFString,
        id: inout IOPMAssertionID,
        held: inout Bool
    ) -> Bool {
        if held { return true }
        var newID = IOPMAssertionID(0)
        let status = IOPMAssertionCreateWithName(
            type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            assertionName,
            &newID
        )
        guard status == kIOReturnSuccess else { return false }
        id = newID
        held = true
        return true
    }

    private func ensureActivity() {
        if activity != nil { return }
        activity = ProcessInfo.processInfo.beginActivity(
            options: [
                .idleDisplaySleepDisabled,
                .idleSystemSleepDisabled,
                .suddenTerminationDisabled,
                .automaticTerminationDisabled,
                .userInitiated
            ],
            reason: "Nigate prevent sleep"
        )
    }

    private func endActivity() {
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
    }

    private func startCaffeinate() {
        if caffeinate?.isRunning == true { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        proc.arguments = ["-d", "-i", "-m"]
        proc.standardInput = FileHandle.nullDevice
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        proc.qualityOfService = .userInitiated
        proc.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.caffeinate = nil
                guard self.wantHold, !self.hasDisplayAssertion else { return }
                self.startCaffeinate()
            }
        }
        do {
            try proc.run()
            caffeinate = proc
        } catch {
            caffeinate = nil
        }
    }

    private func stopCaffeinate() {
        guard let proc = caffeinate else { return }
        caffeinate = nil
        proc.terminationHandler = nil
        if proc.isRunning {
            proc.terminate()
        }
    }

    private func startIostat() {
        stopIostat()
        guard !disks.isEmpty else { return }
        skipBootstrapSample = true
        busyStreak = 0
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/iostat")
        proc.arguments = ["-d", "-w", "1", "-n", "\(disks.count)"] + disks
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { [weak self] file in
            let data = file.availableData
            guard !data.isEmpty else {
                file.readabilityHandler = nil
                return
            }
            guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return }
            Task { @MainActor [weak self] in
                self?.ingest(text)
            }
        }
        proc.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.stoppingIostat, self.mode == .smart, !self.disks.isEmpty else { return }
                self.iostat = nil
                self.iostatOutput = nil
                self.startIostat()
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
        stoppingIostat = true
        let handle = iostatOutput
        let proc = iostat
        iostatOutput = nil
        iostat = nil
        handle?.readabilityHandler = nil
        proc?.terminationHandler = nil
        if let proc, proc.isRunning {
            proc.terminate()
        }
        stoppingIostat = false
    }

    private func ingest(_ text: String) {
        guard mode == .smart else { return }
        var rows = SleepIOStats.numericRows(in: text)
        guard !rows.isEmpty else { return }
        if skipBootstrapSample {
            // 首行是开机至今的平均值，不是这一秒的传输。
            rows.removeFirst()
            skipBootstrapSample = false
            if rows.isEmpty { return }
        }
        if rows.contains(where: SleepIOStats.isBusy) {
            busyStreak += 1
            if busyStreak >= 2 {
                holdIdle(true)
            }
            scheduleIdleRelease()
        } else {
            busyStreak = 0
            if wantHold {
                scheduleIdleReleaseIfNeeded()
            }
        }
    }

    private func scheduleIdleRelease() {
        idleTimer?.invalidate()
        let timer = Timer(timeInterval: idleHold, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.mode == .smart else { return }
                self.idleTimer = nil
                self.holdIdle(false)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        idleTimer = timer
    }

    private func scheduleIdleReleaseIfNeeded() {
        if idleTimer == nil {
            scheduleIdleRelease()
        }
    }
}
