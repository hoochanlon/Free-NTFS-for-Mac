import Foundation
import AppKit
import ServiceManagement
import NigateFSKitCore

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
    @Published var renameDevice: NTFSDevice?
    @Published var toast: String?
    /// 长操作（格式化）期间停在窗口下方，不走 toast 的短时消失。
    @Published var progressHint: String?
    @Published var languageStamp = 0
    /// 供 Settings / Dependencies 观察；MountBackendPolicy 同步持有同一快照。
    @Published private(set) var fsKitControlPlane = NigateFSKitControlPlaneState.unavailable

    let monitor = DiskMonitor()
    let sleepGuard = SleepGuard()
    private var attempted = Set<String>()
    private var cooldown: [String: Date] = [:]
    private var inProgress = Set<String>()
    private var passwordContinuation: CheckedContinuation<String, Error>?
    private var scanning = false
    private var rescanRequested = false
    private var knownNTFSDevices: [String: NTFSDevice] = [:]
    /// 用于 persist 差分：避免每次切换休眠都 unregister 登录项 / 重建整棵 UI。
    private var lastPersistedSettings: AppSettings?

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
        applyLoginItem()
        sleepGuard.setMode(settings.sleepMode, disks: [])
        lastPersistedSettings = settings
        monitor.start { [weak self] in
            Task { @MainActor in
                await self?.refreshDevices()
            }
        }
        await refreshDependencies()
        await refreshDevices()
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
        monitor.stop()
        sleepGuard.stop()
        TrayController.shared.tearDown()
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
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }

    func withdrawToTray() {
        NSApp.setActivationPolicy(.accessory)
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
        toast = protectLocked ? L10n.t("app.protectLocked") : L10n.t("app.protectUnlocked")
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
        if scanning {
            rescanRequested = true
            return
        }
        await scanDevicesLocked()
        // autoMount 必须在 scanning 锁外：其内部 run → refreshDevicesAfterAction 还会再等 scanning。
        if applyAutoMount {
            await self.applyAutoMount(explicit: false)
        }
    }

    /// 只做挂载表扫描；调用方保证不在 autoMount / run 的嵌套路径里重入。
    private func scanDevicesLocked() async {
        scanning = true
        defer { scanning = false }
        repeat {
            rescanRequested = false
            let knownDevices = Array(knownNTFSDevices.values) + devices
            devices = await DeviceScanner.scan(knownDevices: knownDevices)
            rememberNTFSDevices(devices)
            sleepGuard.setMode(settings.sleepMode, disks: mountedWholeDisks())
            updateStatus()
            TrayController.shared.reload()
        } while rescanRequested
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
        toast = L10n.t("settings.deletePasswordSuccess")
    }

    func openInstaller() {
        do {
            try Installer.openTerminal(language: settings.language)
            toast = L10n.t("dependencies.autoInstallOpened")
        } catch {
            alert = AppAlert(title: L10n.t("dialog.error"), message: L10n.t("dependencies.autoInstallFailed", ["error": error.localizedDescription]), kind: .error)
        }
    }

    func checkUpdates() async {
        toast = L10n.t("about.checkingUpdates")
        guard let url = URL(string: "https://api.github.com/repos/hoochanlon/Free-NTFS-for-Mac/releases/latest") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let tag = (json?["tag_name"] as? String)?.trimmingCharacters(in: CharacterSet(charactersIn: "v")) ?? ""
            if tag.isEmpty {
                toast = L10n.t("about.invalidRelease")
            } else if tag == appVersion {
                toast = L10n.t("about.upToDate", ["version": appVersion])
            } else {
                toast = L10n.t("about.updateAvailable", ["version": tag])
                if let page = URL(string: githubReleases) { NSWorkspace.shared.open(page) }
            }
        } catch {
            toast = L10n.t("about.checkFailed")
        }
    }

    private func run(_ action: DeviceAction, _ device: NTFSDevice, extra: String? = nil) async {
        let diskKey = device.parentDisk
        guard !busyDisks.contains(diskKey) else { return }
        // 赋值新 Set，保证 @Published 一定发通知（in-place mutate 在部分路径上 UI 不刷新）。
        markBusy(diskKey)
        var busyReleased = false
        defer {
            // 兜底：任意提前退出都不会把整卡锁死在灰色。
            if !busyReleased { clearBusy(diskKey) }
            progressHint = nil
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
                toast = try await service.mount(device)
            case .unmount:
                toast = try await service.unmount(device)
            case .restore:
                AutoMount.markManualReadOnly(device, settings: &settings)
                cooldown[device.identity] = Date().addingTimeInterval(90)
                cooldown[device.disk] = Date().addingTimeInterval(90)
                persist()
                toast = try await service.restore(device)
            case .reset:
                AutoMount.markManualReadOnly(device, settings: &settings)
                cooldown[device.identity] = Date().addingTimeInterval(90)
                cooldown[device.disk] = Date().addingTimeInterval(90)
                persist()
                toast = try await service.reset(device)
            case .repair:
                toast = try await service.repair(device)
            case .rename:
                toast = try await service.rename(device, to: extra ?? device.volumeName)
            case .format:
                progressHint = L10n.t("messages.formattingHint", ["name": device.volumeName])
                let result = try await service.format(device)
                progressHint = nil
                toast = result
            case .eject:
                toast = try await service.eject(device)
            }
            clearBusy(diskKey)
            busyReleased = true
            // 先乐观改本地列表 + 托盘，避免等 mount 表收敛前托盘仍显示旧橙/绿。
            applyOptimisticDeviceState(action, device)
            // 还原/重置只读后禁止立刻 autoMount，否则会把刚挂上的只读又改成读写
            let skipAuto = action == .restore || action == .reset
            await refreshDevicesAfterAction(action, device: device, applyAutoMount: !skipAuto)
        } catch AppError.cancelled {
            clearBusy(diskKey)
            busyReleased = true
            toast = L10n.t("messages.cancelled")
            await refreshDevices(applyAutoMount: false)
        } catch {
            clearBusy(diskKey)
            busyReleased = true
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

    private func clearBusy(_ diskKey: String) {
        var next = busyDisks
        next.remove(diskKey)
        busyDisks = next
    }

    /// 操作成功后立刻改 devices，托盘图标无需等 diskutil/mount 回读。
    private func applyOptimisticDeviceState(_ action: DeviceAction, _ device: NTFSDevice) {
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
            devices.removeAll(where: match)
            knownNTFSDevices.removeValue(forKey: device.devicePath)
        default:
            break
        }
        rememberNTFSDevices(devices)
        updateStatus()
        TrayController.shared.syncAfterAction()
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
            default:
                return true
            }
        }

        // 对 rename/repair 等无明确瞬时预期的操作，走一次常规刷新即可。
        switch action {
        case .mount, .restore, .reset, .unmount, .eject, .format:
            break
        default:
            await refreshDevices(applyAutoMount: shouldAutoMount)
            return
        }

        // 占用 scanning，合并期间 DiskMonitor 触发的刷新，避免旧结果盖住乐观态。
        // 等既有扫描结束；若对方卡在旧死锁路径，最多等 ~2s 后抢锁，避免按钮永久灰。
        var waited = 0
        while scanning, waited < 40 {
            rescanRequested = true
            try? await Task.sleep(nanoseconds: 50_000_000)
            waited += 1
        }
        scanning = true
        var pendingRescan = false

        // 最多约 1.5s。未收敛前不覆盖乐观状态，避免托盘绿/橙来回跳。
        for attempt in 0..<10 {
            let knownDevices = Array(knownNTFSDevices.values) + devices
            let scanned = await DeviceScanner.scan(knownDevices: knownDevices)
            if matches(scanned) {
                devices = scanned
                rememberNTFSDevices(scanned)
                sleepGuard.setMode(settings.sleepMode, disks: mountedWholeDisks())
                updateStatus()
                TrayController.shared.syncAfterAction()
                break
            }
            if attempt == 9 {
                devices = scanned
                rememberNTFSDevices(scanned)
                sleepGuard.setMode(settings.sleepMode, disks: mountedWholeDisks())
                updateStatus()
                TrayController.shared.syncAfterAction()
                break
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }

        pendingRescan = rescanRequested
        rescanRequested = false
        scanning = false

        // autoMount / 追加 refresh 必须在释放 scanning 之后，否则嵌套 run 会再等 scanning → 死锁。
        if pendingRescan {
            await refreshDevices(applyAutoMount: false)
        } else if shouldAutoMount {
            await applyAutoMount(explicit: false)
        }
    }

    private func applyAutoMount(explicit: Bool) async {
        let targets = AutoMount.candidates(
            devices: devices,
            settings: settings,
            attempted: attempted,
            cooldown: cooldown,
            inProgress: inProgress,
            explicit: explicit
        )
        for device in targets {
            let id = device.identity
            attempted.insert(id)
            attempted.insert(device.disk)
            inProgress.insert(id)
            defer { inProgress.remove(id) }
            await run(.mount, device)
        }
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
