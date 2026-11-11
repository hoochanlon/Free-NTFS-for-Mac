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
    @Published var renameDevice: NTFSDevice?
    @Published var toast: String?
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

    init() {
        let loaded = SettingsStore.load()
        settings = loaded
        tab = loaded.startupTab
        L10n.apply(loaded.language)
        statusText = L10n.t("status.checking")
    }

    func bootstrap() async {
        await refreshFSKitControlPlane()
        normalizeMountBackendIfNeeded()
        applyAppearance()
        applyLoginItem()
        applyDockPolicy()
        sleepGuard.setMode(settings.sleepMode, disks: [])
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
        SettingsStore.save(settings)
        L10n.apply(settings.language)
        languageStamp += 1
        applyAppearance()
        applyLoginItem()
        sleepGuard.setMode(settings.sleepMode, disks: mountedWholeDisks())
        TrayController.shared.reload()
    }

    func setTab(_ next: AppTab) {
        tab = next
    }

    func toggleAutoMount() {
        guard !protectLocked else { return }
        settings.autoMount.toggle()
        persist()
        if settings.autoMount {
            Task { await applyAutoMount(explicit: true) }
        }
    }

    func toggleTray() {
        setTrayMode(!settings.trayMode)
    }

    func setTrayMode(_ enabled: Bool) {
        guard !protectLocked, settings.trayMode != enabled else { return }
        settings.trayMode = enabled
        persist()
        applyDockPolicy()
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
        persist()
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
        scanning = true
        defer { scanning = false }

        repeat {
            rescanRequested = false
            devices = await DeviceScanner.scan()
            sleepGuard.setMode(settings.sleepMode, disks: mountedWholeDisks())
            updateStatus()
            TrayController.shared.reload()
            if applyAutoMount { await self.applyAutoMount(explicit: false) }
        } while rescanRequested
    }

    func perform(_ action: DeviceAction, on device: NTFSDevice, extra: String? = nil) {
        Task { await run(action, device, extra: extra) }
    }

    func runBatch(_ action: DeviceAction) {
        Task {
            let targets: [NTFSDevice]
            switch action {
            case .mount: targets = devices.filter { $0.isReadOnly || $0.isUnmounted }
            case .restore: targets = devices.filter { $0.isReadWrite }
            case .unmount: targets = devices.filter { $0.isMounted }
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
        busyDisks.insert(diskKey)
        defer { busyDisks.remove(diskKey) }
        let service = MountService(backend: resolvedMountBackend()) { [weak self] key, params in
            guard let self else { throw AppError.cancelled }
            return try await self.askPassword(key, params)
        }
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
                toast = try await service.format(device)
            case .eject:
                toast = try await service.eject(device)
            }
            // 还原/重置只读后禁止立刻 autoMount，否则会把刚挂上的只读又改成读写
            let skipAuto = action == .restore || action == .reset
            await refreshDevices(applyAutoMount: !skipAuto)
        } catch AppError.cancelled {
            toast = L10n.t("messages.cancelled")
            await refreshDevices(applyAutoMount: false)
        } catch {
            alert = AppAlert(title: L10n.t("dialog.error"), message: mapError(error, action: action, device: device), kind: .error)
            await refreshDevices(applyAutoMount: false)
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

    private func applyDockPolicy() {
        NSApp.setActivationPolicy(settings.trayMode ? .accessory : .regular)
        if !settings.trayMode { NSApp.activate(ignoringOtherApps: true) }
    }

    private func mapError(_ error: Error, action: DeviceAction, device: NTFSDevice) -> String {
        if let app = error as? AppError, let code = app.code {
            if code.hasPrefix("REPAIR_UNMOUNT_FAILED:") {
                return L10n.t("messages.repairUnmountFailed", ["error": String(code.dropFirst("REPAIR_UNMOUNT_FAILED:".count))])
            }
            if code.hasPrefix("REPAIR_FILESYSTEM_FAILED:") {
                return L10n.t("messages.repairFilesystemFailed", ["error": String(code.dropFirst("REPAIR_FILESYSTEM_FAILED:".count))])
            }
            if code == "RENAME_INVALID_NAME" { return L10n.t("messages.renameInvalidName") }
            if code == "RENAME_TOOL_MISSING" { return L10n.t("messages.renameToolMissing") }
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
