import Foundation

enum AutoMount {
    static func candidates(
        devices: [NTFSDevice],
        settings: AppSettings,
        attempted: Set<String>,
        cooldown: [String: Date],
        inProgress: Set<String>,
        now: Date = Date(),
        explicit: Bool
    ) -> [NTFSDevice] {
        guard settings.autoMount else { return [] }
        let manual = Set(settings.manuallyReadOnlyDevices)
        return devices.filter { device in
            guard device.isMounted, device.isReadOnly, !device.isUnmounted else { return false }
            let id = device.identity
            if manual.contains(id) || manual.contains(device.disk) { return false }
            if (cooldown[id] ?? .distantPast) > now { return false }
            if (cooldown[device.disk] ?? .distantPast) > now { return false }
            if inProgress.contains(id) { return false }
            if !explicit && attempted.contains(id) { return false }
            return true
        }
    }

    static func markManualReadOnly(_ device: NTFSDevice, settings: inout AppSettings) {
        let id = device.identity
        if !settings.manuallyReadOnlyDevices.contains(id) {
            settings.manuallyReadOnlyDevices.append(id)
        }
    }

    static func clearManualReadOnly(_ device: NTFSDevice, settings: inout AppSettings) {
        settings.manuallyReadOnlyDevices.removeAll { $0 == device.identity || $0 == device.disk }
    }
}
