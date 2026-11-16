import Foundation
import AppKit
import ServiceManagement
import NigateFSKitCore

enum AppQuitPhase: Equatable {
    case idle
    case confirming
    case exiting
}

enum DockPresence {
    enum Action: Equatable {
        case show
        case hide
        case exit
        case leave
    }

    /// regular 只许和看得见的主窗口同时存在。
    /// 确认框还没挂上窗口时，禁止为了画确认框把 Dock 图标装回去。
    static func action(phase: AppQuitPhase, windowVisible: Bool, policyIsRegular: Bool) -> Action {
        switch phase {
        case .exiting:
            return .leave
        case .confirming:
            return windowVisible ? .leave : .exit
        case .idle:
            if windowVisible { return policyIsRegular ? .leave : .show }
            return policyIsRegular ? .hide : .leave
        }
    }
}

private struct CapacityProbe: Sendable {
    var devicePath: String
    var volume: String
    var previous: Capacity?
}

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: AppSettings
    @Published var devices: [NTFSDevice] = []
    @Published var dependencies = DependencyStatus()
    @Published var tab: AppTab
    @Published var statusText = ""
    @Published var protectLocked = false
    @Published var busyDisks: Set<String> = []
    @Published var passwordSheet: PasswordSheetState?
    @Published private(set) var passwordValidationInProgress = false
    @Published var alert: AppAlert?
    @Published var aboutOpen = false
    @Published var supportOpen = false
    @Published var quitConfirmOpen = false
    /// 删除密码、修复、格式化、推出。画在主窗口里，避免独立浮层被拖出窗口、也避免毛玻璃贴着底色失去对比。
    @Published var windowConfirm: WindowConfirm?
    /// 退出一旦离开 idle，就不能再收进菜单栏。确认前关窗口会被系统当成「留在后台」。
    private(set) var quitPhase: AppQuitPhase = .idle
    var openMainWindow: (@MainActor () -> Void)?
    @Published var renameDevice: NTFSDevice?
    @Published var toast: String?
    /// 同一句成功提示短时间内只出现一次。连续插盘时第二次挂载不会把底部再弹一遍。
    private var recentToasts: [String: Date] = [:]
    /// 长操作（格式化）期间停在窗口下方，不走 toast 的短时消失。
    @Published var progressHint: String?
    @Published private(set) var isScanningDevices = false
    @Published private(set) var didFinishDeviceScan = false
    @Published var languageStamp = 0
    /// 供 Settings / Dependencies 观察；MountBackendPolicy 同步持有同一快照。
    @Published private(set) var fsKitControlPlane = NigateFSKitControlPlaneState.unavailable

    let monitor = DiskMonitor()
    let sleepGuard = SleepGuard()
    private var attempted = Set<String>()
    private var cooldown: [String: Date] = [:]
    private var inProgress = Set<String>()
    private var passwordContinuation: CheckedContinuation<String, Error>?
    private var rescanRequested = false
    private var knownNTFSDevices: [String: NTFSDevice] = [:]
    /// 只读↔读写期间钉住卡片。DiskMonitor 在卸载瞬间会扫到空表，不能让列表跟着空。
    private var switchPins: [String: DeviceListPin.Pin] = [:]
    private var pinReleaseSeq: [String: UInt64] = [:]
    /// 占用不跟挂载事件走。拷文件时每秒读一次 statfs，数字没变就不发布。
    /// statfs 在后台线程做：FUSE 卡住时不能堵住主线程，否则退出关了窗口却走不到进程结束。
    private var capacityTimer: Timer?
    private var capacityRefreshInFlight = false
    /// 用于 persist 差分：避免每次切换休眠都 unregister 登录项 / 重建整棵 UI。
    private var lastPersistedSettings: AppSettings?
    /// 关窗口后的收起序号。退出或再次打开主窗口时，迟到的 accessory 切换必须作废。
    private var withdrawSeq: UInt64 = 0
    /// 确认框还没画出来就消失时，用序号丢掉过期的检查。
    private var quitWatchSeq: UInt64 = 0
    private var didHardExit = false

    init() {
        let loaded = SettingsStore.load()
        settings = loaded
        lastPersistedSettings = loaded
        tab = loaded.startupTab
        L10n.apply(loaded.language)
        statusText = L10n.t("status.checking")
    }

    func bootstrap() async {
        await refreshFSKitControlPlane()
        normalizeMountBackendIfNeeded()
        applyAppearance()
        // register/unregister 会同步卡住主线程。放在首帧之后，
        // 否则启动期间的退出点击和看门狗都进不了 run loop。
        scheduleLoginItemRegistration()
        sleepGuard.setMode(settings.sleepMode, disks: [])
        lastPersistedSettings = settings
        monitor.start { [weak self] in
            Task { @MainActor in
                await self?.refreshDevices()
            }
        }
        await refreshDependencies()
        await refreshDevices()
        startCapacityRefresh()
        TrayController.shared.attach(self)
    }

    /// 探测扩展安装/启用态，注入 MountBackendPolicy；Settings 与挂载路径共用此快照。
    func refreshFSKitControlPlane() async {
        let state = await FSKitControlPlaneService.probe()
        fsKitControlPlane = state
        MountBackendPolicy.updateControlPlaneState(state)
        normalizeMountBackendIfNeeded()
    }

    func shutdown() {
        if quitPhase != .exiting { quitPhase = .exiting }
        capacityTimer?.invalidate()
        capacityTimer = nil
        capacityRefreshInFlight = false
        monitor.stop()
        sleepGuard.stop()
        TrayController.shared.tearDown()
    }

    private func startCapacityRefresh() {
        capacityTimer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshLiveCapacity()
            }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        capacityTimer = timer
    }

    private func refreshLiveCapacity() {
        guard quitPhase == .idle, !capacityRefreshInFlight, !isScanningDevices else { return }
        let probes = devices.compactMap { device -> CapacityProbe? in
            guard device.isMounted, !device.isUnmounted, !device.volume.isEmpty else { return nil }
            return CapacityProbe(devicePath: device.devicePath, volume: device.volume, previous: device.capacity)
        }
        guard !probes.isEmpty else { return }
        capacityRefreshInFlight = true
        Task.detached { [weak self] in
            var samples: [String: Capacity] = [:]
            for probe in probes {
                if let capacity = VolumeStat.capacity(
                    volume: probe.volume,
                    devicePath: probe.devicePath,
                    previous: probe.previous
                ) {
                    samples[probe.devicePath] = capacity
                }
            }
            await self?.applyLiveCapacity(samples)
        }
    }

    private func applyLiveCapacity(_ samples: [String: Capacity]) {
        capacityRefreshInFlight = false
        guard quitPhase == .idle else { return }
        guard let next = CapacityRefresh.applying(devices, samples: samples) else { return }
        devices = next
        rememberNTFSDevices(next)
    }

    func persist() {
        let previous = lastPersistedSettings
        SettingsStore.save(settings)
        lastPersistedSettings = settings

        // 只在语言真正变化时重建整棵 UI；每次点防止休眠都 stamp++ 会打断交互。
        if previous?.language != settings.language {
            L10n.apply(settings.language)
            languageStamp += 1
            TrayController.shared.reload()
        }
        if previous?.themeIsLight != settings.themeIsLight {
            applyAppearance()
        }
        // SMAppService register/unregister 可能同步卡住主线程，禁止每次 persist 都打。
        if previous?.autoStart != settings.autoStart {
            applyLoginItem()
        }
        if previous?.sleepMode != settings.sleepMode {
            sleepGuard.setMode(settings.sleepMode, disks: mountedWholeDisks())
        }
    }

    func setTab(_ next: AppTab) {
        tab = next
    }

    func revealMainWindow() {
        guard quitPhase == .idle else {
            // 退出过程中再打开窗口，只会把已经摘掉的 Dock 图标装回来。
            if quitPhase == .confirming, Self.visibleMainWindow() == nil {
                quitImmediately()
            }
            return
        }
        withdrawSeq += 1
        let seq = withdrawSeq
        if let window = Self.visibleMainWindow() ?? Self.mainWindow() {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            if Self.visibleMainWindow() != nil {
                applyDockPresence()
                return
            }
        } else {
            openMainWindow?()
            NSApp.activate(ignoringOtherApps: true)
        }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.quitPhase == .idle, self.withdrawSeq == seq else { return }
            (Self.visibleMainWindow() ?? Self.mainWindow())?.makeKeyAndOrderFront(nil)
            self.promoteDock(seq, attempt: 0)
        }
    }

    /// 主窗口真正出现之后才升为 regular。启动阶段提前占 Dock，慢启动会停在「正在后台运行」。
    func noteMainWindowOnScreen() {
        guard quitPhase == .idle else { return }
        promoteDock(withdrawSeq, attempt: 0)
    }

    func bindOpenMainWindow(_ opener: @escaping @MainActor () -> Void) {
        openMainWindow = opener
    }

    /// 关红灯应收进菜单栏。退出确认或正在退出时不要切 accessory，否则 Dock 会留下「正在后台运行」。
    var suppressesTrayWithdraw: Bool { quitPhase != .idle }

    /// 标题栏、托盘、Cmd+Q 都走这里。确认之前不调用 terminate：
    /// 一旦取消，SwiftUI 会关掉窗口，之后每次退出都还是取消，进程就留在 Dock。
    /// 没有可见主窗口时直接结束。为了确认框去打开窗口，会把 Dock 图标重新装上。
    func requestQuit() {
        if quitPhase == .exiting || didHardExit {
            quitImmediately()
            return
        }
        guard Self.visibleMainWindow() != nil else {
            quitImmediately()
            return
        }
        presentQuitConfirm()
    }

    /// 退出确认只画在已经可见的主窗口里。窗口不在就结束，不再把激活策略升回 regular。
    func presentQuitConfirm() {
        guard quitPhase != .exiting, !didHardExit else { return }
        guard Self.visibleMainWindow() != nil else {
            quitImmediately()
            return
        }
        quitPhase = .confirming
        aboutOpen = false
        supportOpen = false
        passwordSheet = nil
        renameDevice = nil
        alert = nil
        windowConfirm = nil
        quitConfirmOpen = true
        quitWatchSeq += 1
        let watch = quitWatchSeq
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self, self.quitPhase == .confirming, self.quitWatchSeq == watch else { return }
            if Self.visibleMainWindow() == nil || !self.quitConfirmOpen {
                self.quitImmediately()
            }
        }
    }

    func presentWindowConfirm(
        title: String,
        message: String = "",
        symbol: String,
        critical: Bool = false,
        confirmTitle: String,
        action: @escaping @MainActor () -> Void
    ) {
        guard quitPhase == .idle else { return }
        aboutOpen = false
        supportOpen = false
        passwordSheet = nil
        renameDevice = nil
        alert = nil
        revealMainWindow()
        windowConfirm = WindowConfirm(
            title: title,
            message: message,
            symbol: symbol,
            critical: critical,
            confirmTitle: confirmTitle,
            action: action
        )
    }

    func cancelWindowConfirm() {
        windowConfirm = nil
    }

    func acceptWindowConfirm() {
        let action = windowConfirm?.action
        windowConfirm = nil
        action?()
    }

    func cancelQuit() {
        guard quitPhase != .exiting else { return }
        quitConfirmOpen = false
        quitPhase = .idle
    }

    func confirmQuit() {
        quitConfirmOpen = false
        quitImmediately()
    }

    /// 不走 NSApp.terminate，也不走 exit()。atexit 里若还有 iostat / 窗口回调，系统会把进程收成「正在后台运行」。
    func quitImmediately() {
        if didHardExit { return }
        didHardExit = true
        quitPhase = .exiting
        quitConfirmOpen = false
        shutdown()
        if NSApp.modalWindow != nil { NSApp.stopModal() }
        Darwin._exit(0)
    }

    func withdrawToTray() {
        guard quitPhase == .idle else { return }
        withdrawSeq += 1
        let seq = withdrawSeq
        DispatchQueue.main.async { [weak self] in
            self?.finishWithdraw(seq, attempt: 0)
        }
    }

    /// 等主窗口真正离开屏幕再改激活策略。窗口还在关闭时切 accessory，Dock 不会拿掉图标，只会写成「正在后台运行」。
    /// 慢启动时窗口可能超过 1 秒还不走。不能就此放弃，否则策略停在 regular，Dock 只剩后台项。
    private func finishWithdraw(_ seq: UInt64, attempt: Int) {
        guard quitPhase == .idle, withdrawSeq == seq else { return }
        let visible = Self.mainWindows().filter(\.isVisible)
        if !visible.isEmpty {
            if attempt == 20 || attempt >= 40 {
                visible.forEach { $0.orderOut(nil) }
            }
            let delay: TimeInterval = attempt < 40 ? 0.05 : 0.5
            let next = attempt < 40 ? attempt + 1 : attempt
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.finishWithdraw(seq, attempt: next)
            }
            return
        }
        if NSApp.activationPolicy() != .accessory {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func promoteDock(_ seq: UInt64, attempt: Int) {
        guard quitPhase == .idle, withdrawSeq == seq else { return }
        if Self.visibleMainWindow() != nil {
            let shouldActivate = NSApp.activationPolicy() != .regular
            applyDockPresence()
            if shouldActivate {
                NSApp.activate(ignoringOtherApps: true)
                Self.visibleMainWindow()?.makeKeyAndOrderFront(nil)
            }
            return
        }
        // 慢启动时窗口可能晚好几秒才变成可见主窗口。在那之前保持菜单栏代理，不要抢先占 Dock。
        let delay: TimeInterval = attempt < 30 ? 0.05 : 0.5
        let next = attempt < 30 ? attempt + 1 : attempt
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.promoteDock(seq, attempt: next)
        }
    }

    private func applyDockPresence() {
        switch DockPresence.action(
            phase: quitPhase,
            windowVisible: Self.visibleMainWindow() != nil,
            policyIsRegular: NSApp.activationPolicy() == .regular
        ) {
        case .show:
            NSApp.setActivationPolicy(.regular)
        case .hide:
            NSApp.setActivationPolicy(.accessory)
        case .exit:
            quitImmediately()
        case .leave:
            break
        }
    }

    private static func isMainWindow(_ window: NSWindow) -> Bool {
        if window is NSPanel { return false }
        if window.title == "Nigate" || window.identifier?.rawValue == "main" { return true }
        // SwiftUI 写上 title / identifier 之前的那一帧。漏判会让 Dock 图标一直不出现。
        return window.level == .normal && window.frame.width > 200 && window.frame.height > 200
    }

    private static func visibleMainWindow() -> NSWindow? {
        NSApp.windows.first { window in
            isMainWindow(window)
                && window.isVisible
                && !window.isMiniaturized
                && window.frame.width > 200
                && window.frame.height > 200
        }
    }

    private static func mainWindows() -> [NSWindow] {
        NSApp.windows.filter(isMainWindow)
    }

    private static func mainWindow() -> NSWindow? {
        visibleMainWindow() ?? mainWindows().first
    }

    func cycleSleep() {
        guard !protectLocked else { return }
        let next: SleepMode
        switch settings.sleepMode {
        case .off: next = .always
        case .always: next = .smart
        case .smart: next = .off
        }
        settings.applySleepMode(next)
        // 休眠切换高频：只落盘 + 更新 guard，避免走完整 persist 差分之外的副作用路径。
        SettingsStore.save(settings)
        lastPersistedSettings = settings
        sleepGuard.setMode(next, disks: mountedWholeDisks())
    }

    func toggleProtect() {
        protectLocked.toggle()
        showToast(protectLocked ? L10n.t("app.protectLocked") : L10n.t("app.protectUnlocked"))
    }

    func toggleTheme() {
        settings.themeIsLight.toggle()
        persist()
    }

    func refreshDependencies() async {
        statusText = L10n.t("status.checking")
        // 先刷新控制面，再汇总依赖状态，避免 UI 读到过期的 FSKit 可用性。
        await refreshFSKitControlPlane()
        dependencies = await DependencyService.check()
        updateStatus()
    }

    func refreshDevices(applyAutoMount: Bool = true) async {
        guard quitPhase == .idle else { return }
        if isScanningDevices {
            rescanRequested = true
            return
        }
        await scanDevicesLocked()
        guard quitPhase == .idle else { return }
        // autoMount 必须在 scanning 锁外：其内部 run → refreshDevicesAfterAction 还会再等 scanning。
        if applyAutoMount, busyDisks.isEmpty, switchPins.isEmpty {
            await self.applyAutoMount(explicit: false)
        }
    }

    /// 只做挂载表扫描；调用方保证不在 autoMount / run 的嵌套路径里重入。
    private func scanDevicesLocked() async {
        isScanningDevices = true
        updateStatus()
        TrayController.shared.reload()
        defer {
            isScanningDevices = false
            didFinishDeviceScan = true
            updateStatus()
            TrayController.shared.reload()
        }
        repeat {
            guard quitPhase == .idle else { return }
            rescanRequested = false
            let knownDevices = Array(knownNTFSDevices.values) + devices
            let scanned = await DeviceScanner.scan(knownDevices: knownDevices)
            // 退出后这次扫描才回来：不能再拉起防休眠，也不能把刚拆掉的状态栏装回去。
            guard quitPhase == .idle else { return }
            devices = pinnedDuringTransition(scanned)
            rememberNTFSDevices(devices)
            sleepGuard.setMode(settings.sleepMode, disks: mountedWholeDisks())
            updateStatus()
            TrayController.shared.reload()
        } while rescanRequested && quitPhase == .idle
    }

    func perform(_ action: DeviceAction, on device: NTFSDevice, extra: String? = nil) {
        Task { await run(action, device, extra: extra) }
    }

    func runBatch(_ action: DeviceAction) {
        Task {
            let targets: [NTFSDevice]
            switch action {
            case .mount: targets = devices.filter { $0.isReadOnly || $0.needsMount }
            case .restore: targets = devices.filter { $0.isReadWrite }
            case .unmount: targets = devices.filter { !$0.needsMount }
            case .eject: targets = devices
            default: targets = []
            }
            for device in targets { await run(action, device) }
        }
    }

    func submitPassword(_ value: String, save: Bool) {
        guard passwordContinuation != nil, !passwordValidationInProgress else { return }
        settings.savePassword = save
        persist()
        passwordValidationInProgress = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { passwordValidationInProgress = false }
            do {
                if value.isEmpty { throw AppError.emptyPassword }
                _ = try? await Shell.run("/usr/bin/sudo", ["-K"], timeout: 3)
                _ = try await Privilege.sudo(["-v"], password: value, timeout: 8)
                if save { try? KeychainStore.save(value) }
                finishPassword(.success(value))
            } catch AppError.incorrectPassword {
                KeychainStore.delete()
                finishPassword(.failure(AppError.incorrectPassword))
            } catch {
                finishPassword(.failure(error))
            }
        }
    }

    func cancelPassword() {
        guard !passwordValidationInProgress else { return }
        guard passwordContinuation != nil else {
            passwordSheet = nil
            return
        }
        finishPassword(.failure(AppError.cancelled))
    }

    func deleteSavedPassword() {
        KeychainStore.delete()
        showToast(L10n.t("settings.deletePasswordSuccess"))
    }

    func openInstaller() {
        do {
            try Installer.openTerminal(language: settings.language)
            showToast(L10n.t("dependencies.autoInstallOpened"))
        } catch {
            alert = AppAlert(title: L10n.t("dialog.error"), message: L10n.t("dependencies.autoInstallFailed", ["error": error.localizedDescription]), kind: .error)
        }
    }

    func checkUpdates() async {
        showToast(L10n.t("about.checkingUpdates"))
        guard let url = URL(string: "https://api.github.com/repos/hoochanlon/Free-NTFS-for-Mac/releases/latest") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let tag = (json?["tag_name"] as? String)?.trimmingCharacters(in: CharacterSet(charactersIn: "v")) ?? ""
            if tag.isEmpty {
                showToast(L10n.t("about.invalidRelease"))
            } else if tag == appVersion {
                showToast(L10n.t("about.upToDate", ["version": appVersion]))
            } else {
                showToast(L10n.t("about.updateAvailable", ["version": tag]))
                if let page = URL(string: githubReleases) { NSWorkspace.shared.open(page) }
            }
        } catch {
            showToast(L10n.t("about.checkFailed"))
        }
    }

    private func run(_ action: DeviceAction, _ device: NTFSDevice, extra: String? = nil) async {
        let diskKey = device.parentDisk
        guard !busyDisks.contains(diskKey) else { return }
        // 赋值新 Set，保证 @Published 一定发通知（in-place mutate 在部分路径上 UI 不刷新）。
        markBusy(diskKey)
        pinSwitch(device, action)
        var busyReleased = false
        defer {
            // 兜底：任意提前退出都不会把整卡锁死在灰色。
            if !busyReleased { clearBusy(diskKey) }
            progressHint = nil
            // 钉不能在动作结束瞬间摘掉：迟到的卸载通知还会再扫一次空表。
            if switchPins[diskKey] != nil {
                schedulePinRelease(diskKey)
            }
        }
        let service = MountService(backend: resolvedMountBackend()) { [weak self] key, params in
            guard let self else { throw AppError.cancelled }
            return try await self.askPassword(key, params)
        }
        // 实际磁盘操作结束后立刻解锁按钮；回读挂载表不再占用 busy（避免卡灰）。
        do {
            switch action {
            case .mount:
                AutoMount.clearManualReadOnly(device, settings: &settings)
                persist()
                showToast(try await service.mount(device))
            case .unmount:
                showToast(try await service.unmount(device))
            case .restore:
                AutoMount.markManualReadOnly(device, settings: &settings)
                cooldown[device.identity] = Date().addingTimeInterval(90)
                cooldown[device.disk] = Date().addingTimeInterval(90)
                persist()
                showToast(try await service.restore(device))
            case .reset:
                AutoMount.markManualReadOnly(device, settings: &settings)
                cooldown[device.identity] = Date().addingTimeInterval(90)
                cooldown[device.disk] = Date().addingTimeInterval(90)
                persist()
                showToast(try await service.reset(device))
            case .repair:
                showToast(try await service.repair(device))
            case .rename:
                showToast(try await service.rename(device, to: extra ?? device.volumeName))
            case .format:
                progressHint = L10n.t("messages.formattingHint", ["name": device.volumeName])
                let result = try await service.format(device)
                progressHint = nil
                showToast(result)
            case .eject:
                showToast(try await service.eject(device))
            }
            clearBusy(diskKey)
            busyReleased = true
            // 先乐观改本地列表 + 托盘，避免等 mount 表收敛前托盘仍显示旧橙/绿。
            applyOptimisticDeviceState(action, device, renamedTo: action == .rename ? extra : nil)
            // 还原/重置只读后禁止立刻 autoMount，否则会把刚挂上的只读又改成读写
            let skipAuto = action == .restore || action == .reset
            await refreshDevicesAfterAction(action, device: device, applyAutoMount: !skipAuto)
        } catch AppError.cancelled {
            clearBusy(diskKey)
            busyReleased = true
            dropSwitchPin(diskKey)
            showToast(L10n.t("messages.cancelled"))
            await refreshDevices(applyAutoMount: false)
        } catch {
            clearBusy(diskKey)
            busyReleased = true
            dropSwitchPin(diskKey)
            alert = AppAlert(title: L10n.t("dialog.error"), message: mapError(error, action: action, device: device), kind: .error)
            await refreshDevices(applyAutoMount: false)
        }
    }

    private func rememberNTFSDevices(_ devices: [NTFSDevice]) {
        for var device in devices {
            if device.volumeUuid?.isEmpty != false,
               let knownUUID = knownNTFSDevices[device.devicePath]?.volumeUuid {
                device.volumeUuid = knownUUID
            }
            if device.partitionUuid?.isEmpty != false,
               let knownUUID = knownNTFSDevices[device.devicePath]?.partitionUuid {
                device.partitionUuid = knownUUID
            }
            knownNTFSDevices[device.devicePath] = device
        }
    }

    private func markBusy(_ diskKey: String) {
        var next = busyDisks
        next.insert(diskKey)
        busyDisks = next
    }

    private func pinSwitch(_ device: NTFSDevice, _ action: DeviceAction) {
        let key = device.parentDisk
        pinReleaseSeq[key, default: 0] += 1
        switch action {
        case .eject, .format:
            switchPins.removeValue(forKey: key)
        default:
            switchPins[key] = DeviceListPin.Pin(
                devicePath: device.devicePath,
                parentDisk: key,
                action: action
            )
        }
    }

    private func dropSwitchPin(_ diskKey: String) {
        pinReleaseSeq[diskKey, default: 0] += 1
        switchPins.removeValue(forKey: diskKey)
    }

    /// 动作已经结束，再留一小段钉，挡住 DiskMonitor 排队过来的卸载空扫描。
    private func schedulePinRelease(_ diskKey: String, after seconds: Double = 3) {
        let seq = (pinReleaseSeq[diskKey] ?? 0) + 1
        pinReleaseSeq[diskKey] = seq
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard pinReleaseSeq[diskKey] == seq else { return }
            switchPins.removeValue(forKey: diskKey)
        }
    }

    private func clearBusy(_ diskKey: String) {
        var next = busyDisks
        next.remove(diskKey)
        busyDisks = next
    }

    /// 操作成功后立刻改 devices，托盘图标无需等 diskutil/mount 回读。
    private func applyOptimisticDeviceState(_ action: DeviceAction, _ device: NTFSDevice, renamedTo: String? = nil) {
        let match: (NTFSDevice) -> Bool = {
            $0.identity == device.identity || $0.disk == device.disk || $0.devicePath == device.devicePath
        }
        switch action {
        case .mount:
            if let idx = devices.firstIndex(where: match) {
                devices[idx].isReadOnly = false
                devices[idx].isMounted = true
                devices[idx].isUnmounted = false
            }
        case .restore, .reset:
            if let idx = devices.firstIndex(where: match) {
                devices[idx].isReadOnly = true
                devices[idx].isMounted = true
                devices[idx].isUnmounted = false
            }
        case .unmount:
            if let idx = devices.firstIndex(where: match) {
                devices[idx].isMounted = false
                devices[idx].isUnmounted = true
                devices[idx].isReadOnly = true
                devices[idx].volume = ""
                knownNTFSDevices[devices[idx].devicePath] = devices[idx]
            }
        case .eject, .format:
            dropSwitchPin(device.parentDisk)
            devices.removeAll(where: match)
            knownNTFSDevices.removeValue(forKey: device.devicePath)
        case .rename:
            let trimmed = renamedTo?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmed.isEmpty, trimmed != device.volumeName,
                  let idx = devices.firstIndex(where: match) else { break }
            devices[idx].volumeName = trimmed
            if devices[idx].volume.hasPrefix("/Volumes/") {
                devices[idx].volume = "/Volumes/\(trimmed)"
            }
            knownNTFSDevices[devices[idx].devicePath] = devices[idx]
            if var pin = switchPins[device.parentDisk], pin.devicePath == device.devicePath {
                pin.expectedVolumeName = trimmed
                switchPins[device.parentDisk] = pin
            }
        case .repair:
            break
        }
        rememberNTFSDevices(devices)
        updateStatus()
        TrayController.shared.syncAfterAction()
    }

    /// 卸载/重挂瞬间扫描常会漏掉分区或扫到未挂载态；未收敛前钉住当前卡片。
    private func pinnedDuringTransition(_ scanned: [NTFSDevice]) -> [NTFSDevice] {
        DeviceListPin.merge(scanned: scanned, held: devices, pins: Array(switchPins.values))
    }

    /// 挂载表偶发滞后：短重试直到状态与操作预期一致，再交给常规刷新。
    private func refreshDevicesAfterAction(
        _ action: DeviceAction,
        device: NTFSDevice,
        applyAutoMount shouldAutoMount: Bool
    ) async {
        let volumeUuid = device.volumeUuid
        let partitionUuid = device.partitionUuid
        let disk = device.disk
        let path = device.devicePath

        func matches(_ list: [NTFSDevice]) -> Bool {
            let found = list.first { $0.devicePath == path }
            if action == .eject || action == .format { return found == nil }
            guard let found, found.disk == disk else { return false }
            if let volumeUuid, !volumeUuid.isEmpty,
               let foundUUID = found.volumeUuid, foundUUID != volumeUuid { return false }
            if let partitionUuid, !partitionUuid.isEmpty,
               let foundUUID = found.partitionUuid, foundUUID != partitionUuid { return false }
            switch action {
            case .mount:
                return found.isReadWrite
            case .restore, .reset:
                return found.isMounted && found.isReadOnly
            case .unmount:
                return found.isUnmounted || !found.isMounted
            case .rename:
                guard found.isMounted, !found.isUnmounted else { return false }
                guard let expected = switchPins[device.parentDisk]?.expectedVolumeName, !expected.isEmpty else {
                    return true
                }
                return found.volumeName == expected
            default:
                return true
            }
        }

        // repair 没有可对照的瞬时目标。rename 的目标卷标已经写进乐观态，
        // 扫描对上之前不能把旧挂载表盖回去。
        switch action {
        case .mount, .restore, .reset, .unmount, .eject, .format, .rename:
            break
        default:
            await refreshDevices(applyAutoMount: shouldAutoMount)
            return
        }

        // 占用 scanning，合并期间 DiskMonitor 触发的刷新，避免旧结果盖住乐观态。
        // 等既有扫描结束；若对方卡在旧死锁路径，最多等 ~2s 后抢锁，避免按钮永久灰。
        var waited = 0
        while isScanningDevices, waited < 40 {
            rescanRequested = true
            try? await Task.sleep(nanoseconds: 50_000_000)
            waited += 1
        }
        isScanningDevices = true
        var pendingRescan = false

        // 最多约 1.5s。未收敛前不覆盖乐观状态，避免托盘绿/橙来回跳。
        for attempt in 0..<10 {
            let knownDevices = Array(knownNTFSDevices.values) + devices
            let scanned = await DeviceScanner.scan(knownDevices: knownDevices)
            if quitPhase != .idle { break }
            let merged = pinnedDuringTransition(scanned)
            if matches(scanned) || attempt == 9 {
                devices = merged
                rememberNTFSDevices(merged)
                sleepGuard.setMode(settings.sleepMode, disks: mountedWholeDisks())
                updateStatus()
                TrayController.shared.syncAfterAction()
                break
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }

        pendingRescan = rescanRequested
        rescanRequested = false
        isScanningDevices = false
        guard quitPhase == .idle else { return }

        // autoMount / 追加 refresh 必须在释放 scanning 之后，否则嵌套 run 会再等 scanning → 死锁。
        if pendingRescan {
            await refreshDevices(applyAutoMount: false)
        } else if shouldAutoMount {
            await applyAutoMount(explicit: false)
        }
    }

    private func applyAutoMount(explicit: Bool) async {
        guard quitPhase == .idle else { return }
        let targets = AutoMount.targets(
            devices: devices,
            settings: settings,
            attempted: attempted,
            cooldown: cooldown,
            inProgress: inProgress,
            explicit: explicit
        )
        for device in targets {
            let keys = Set(
                devices
                    .filter { $0.sameMount(as: device) }
                    .flatMap(AutoMount.recordKeys)
                    + AutoMount.recordKeys(device)
            )
            if !explicit && keys.contains(where: { attempted.contains($0) || inProgress.contains($0) }) {
                continue
            }
            for key in keys {
                attempted.insert(key)
                inProgress.insert(key)
            }
            defer {
                for key in keys { inProgress.remove(key) }
            }
            guard quitPhase == .idle else { return }
            await run(.mount, device)
        }
    }

    private func showToast(_ message: String, now: Date = Date()) {
        guard ToastDedup.shouldPresent(message, recent: recentToasts, now: now) else { return }
        recentToasts[message] = now
        toast = message
    }

    private func askPassword(_ key: String, _ params: [String: String]) async throws -> String {
        if settings.savePassword, let saved = KeychainStore.read(), !saved.isEmpty {
            return saved
        }
        guard passwordContinuation == nil else {
            throw AppError.passwordRequestInProgress
        }
        return try await withCheckedThrowingContinuation { continuation in
            passwordContinuation = continuation
            passwordSheet = PasswordSheetState(
                title: L10n.t(key, params),
                savePassword: settings.savePassword
            )
        }
    }

    private func finishPassword(_ result: Result<String, Error>) {
        let continuation = passwordContinuation
        passwordContinuation = nil
        passwordSheet = nil
        switch result {
        case .success(let value): continuation?.resume(returning: value)
        case .failure(let error): continuation?.resume(throwing: error)
        }
    }

    private func resolvedMountBackend() -> NigateMountBackend {
        let resolved = MountBackendPolicy.sanitize(settings.mountBackend)
        if resolved != settings.mountBackend {
            settings.mountBackend = resolved
            persist()
        }
        return resolved
    }

    /// 启动时纠正不可用的 FSKit 选择（扩展开关开着 ≠ 控制面可挂载）。
    private func normalizeMountBackendIfNeeded() {
        let resolved = MountBackendPolicy.sanitize(settings.mountBackend)
        guard resolved != settings.mountBackend else { return }
        settings.mountBackend = resolved
        persist()
    }

    private func updateStatus() {
        if dependencies.missingCore {
            statusText = L10n.t("status.missingDeps")
            return
        }
        if isScanningDevices || !didFinishDeviceScan {
            statusText = L10n.t("status.scanningDevices")
            return
        }
        if devices.isEmpty {
            statusText = L10n.t("status.waitingDevices")
            return
        }
        let readOnly = devices.filter(\.isReadOnly).count
        if readOnly == 0 {
            statusText = L10n.t("status.devicesReady", ["count": "\(devices.count)"])
        } else {
            statusText = L10n.t("status.devicesReadOnly", ["count": "\(readOnly)"])
        }
    }

    private func mountedWholeDisks() -> [String] {
        Array(Set(devices.filter { $0.isMounted && !$0.isUnmounted }.map(\.parentDisk))).sorted()
    }

    private func applyAppearance() {
        NSApp.appearance = NSAppearance(named: settings.themeIsLight ? .aqua : .darkAqua)
    }

    private func scheduleLoginItemRegistration() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard quitPhase != .exiting else { return }
            applyLoginItem()
        }
    }

    private func applyLoginItem() {
        if #available(macOS 13.0, *) {
            do {
                if settings.autoStart {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {}
        }
    }

    private func mapError(_ error: Error, action: DeviceAction, device: NTFSDevice) -> String {
        if let app = error as? AppError, let code = app.code {
            if code.hasPrefix("REPAIR_UNMOUNT_FAILED:") {
                return L10n.t("messages.repairUnmountFailed", ["error": String(code.dropFirst("REPAIR_UNMOUNT_FAILED:".count))])
            }
            if code.hasPrefix("REPAIR_FILESYSTEM_FAILED:") {
                return L10n.t("messages.repairFilesystemFailed", ["error": String(code.dropFirst("REPAIR_FILESYSTEM_FAILED:".count))])
            }
            if code.hasPrefix("REPAIR_REMOUNT_FAILED:") {
                return L10n.t("messages.repairRemountFailed", ["error": String(code.dropFirst("REPAIR_REMOUNT_FAILED:".count))])
            }
            if code == "RENAME_INVALID_NAME" { return L10n.t("messages.renameInvalidName") }
            if code == "RENAME_TOOL_MISSING" { return L10n.t("messages.renameToolMissing") }
            if code.hasPrefix("RENAME_UNMOUNT_FAILED:") {
                return L10n.t("messages.renameUnmountFailed", ["error": String(code.dropFirst("RENAME_UNMOUNT_FAILED:".count))])
            }
            if code.hasPrefix("RENAME_LABEL_FAILED:") {
                // 脏卷/校验标记导致写标失败：引导 Windows chkdsk，避免把 ntfslabel 英文原文甩给用户。
                return L10n.t("messages.renameFailedNeedChkdsk")
            }
            if code.hasPrefix("RENAME_REMOUNT_FAILED:") {
                return L10n.t("messages.renameRemountFailed", ["error": String(code.dropFirst("RENAME_REMOUNT_FAILED:".count))])
            }
            if code == "FORMAT_NOT_ALLOWED" { return L10n.t("messages.formatNotAllowed") }
            if code == "FORMAT_TOOL_MISSING" { return L10n.t("messages.formatToolMissing") }
            return code
        }
        return error.localizedDescription
    }
}

struct PasswordSheetState: Identifiable {
    let id = UUID()
    var title: String
    var savePassword: Bool
}

enum ToastDedup {
    /// 一次挂载要几秒。窗口盖住「挂完一条又挂同一卷」的第二声，不盖住下一次真正的插拔。
    static let window: TimeInterval = 15

    static func shouldPresent(_ message: String, recent: [String: Date], now: Date) -> Bool {
        guard let seen = recent[message] else { return true }
        return now.timeIntervalSince(seen) >= window
    }
}
