import SwiftUI
import AppKit

struct DevicesPane: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.t("devices.title")).font(.title2.weight(.semibold))
                Spacer()
                batch("arrow.clockwise", L10n.t("devices.refreshDevices")) {
                    Task { await model.refreshDevices() }
                }
                batch("pencil.and.outline", L10n.t("devices.mountAll")) { model.runBatch(.mount) }
                batch("eye", L10n.t("devices.restoreAllReadOnly")) { model.runBatch(.restore) }
                batch("eject", L10n.t("devices.unmountAll")) { model.runBatch(.unmount) }
                batch("externaldrive.badge.xmark", L10n.t("devices.ejectAll")) { model.runBatch(.eject) }
            }
            if model.devices.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "externaldrive.badge.questionmark").font(.system(size: 42)).foregroundStyle(.secondary)
                    Text(L10n.t("devices.emptyState")).font(.headline)
                    Text(L10n.t("devices.emptyHint")).foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(model.devices) { device in
                            DeviceCard(device: device)
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
        }
        .padding(18)
    }

    private func batch(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

struct DeviceCard: View {
    @EnvironmentObject private var model: AppModel
    let device: NTFSDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 信息区：双击打开挂载点（与图2 Finder 一致）；按钮行不绑双击，避免误触。
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "externaldrive.fill")
                        .foregroundStyle(device.isReadWrite ? Palette.success : Palette.warning)
                    Text(device.volumeName).font(.headline)
                    Spacer()
                    Text(statusLabel)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.16), in: Capsule())
                        .foregroundStyle(statusColor)
                }
                HStack(spacing: 18) {
                    labeled(L10n.t("devices.deviceLabel"), device.disk)
                    labeled(L10n.t("devices.mountPointLabel"), device.volume.isEmpty ? L10n.t("devices.notMounted") : device.volume)
                }
                if let capacity = device.capacity {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: Double(capacity.used), total: Double(max(capacity.total, 1)))
                        Text("\(L10n.t("devices.available")) \(byteText(capacity.available))  ·  \(L10n.t("devices.total")) \(byteText(capacity.total))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                openVolumeInFinder()
            }
            .help(openVolumeHelp)

            HStack {
                action(L10n.t("devices.mount"), "pencil") { model.perform(.mount, on: device) }
                action(L10n.t("devices.restoreReadOnly"), "eye") { model.perform(.restore, on: device) }
                action(L10n.t("devices.unmount"), "eject") { model.perform(.unmount, on: device) }
                action(L10n.t("devices.eject"), "externaldrive.badge.xmark") { confirm(.eject) }
                action(L10n.t("devices.repair"), "wrench.and.screwdriver") { confirm(.repair) }
                action(L10n.t("devices.rename"), "character.cursor.ibeam") { model.renameDevice = device }
                if device.canFormat {
                    action(L10n.t("devices.format"), "internaldrive") { confirm(.format) }
                }
                action(L10n.t("devices.reset"), "arrow.counterclockwise") { model.perform(.reset, on: device) }
            }
            .disabled(model.busyDisks.contains(device.parentDisk))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.06)))
    }

    private var openVolumeHelp: String {
        if device.isMounted, !device.volume.isEmpty {
            return L10n.t("devices.openVolumeHint")
        }
        return L10n.t("devices.openVolumeUnavailable")
    }

    private func openVolumeInFinder() {
        guard device.isMounted,
              !device.isUnmounted,
              DiskSafety.isSafeMountPoint(device.volume) else { return }
        let url = URL(fileURLWithPath: device.volume, isDirectory: true)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        // 与侧边栏双击卷宗一致：在 Finder 中打开挂载点。
        NSWorkspace.shared.open(url)
    }

    private var statusLabel: String {
        if device.isUnmounted { return L10n.t("devices.unmounted") }
        return device.isReadWrite ? L10n.t("devices.readWrite") : L10n.t("devices.readOnly")
    }

    private var statusColor: Color { device.isReadWrite ? Palette.success : Palette.warning }

    private func labeled(_ title: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(title).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled)
        }
        .font(.caption)
    }

    private func action(_ title: String, _ icon: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Label(title, systemImage: icon)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func confirm(_ action: DeviceAction) {
        let title: String
        let message: String
        let symbol: String
        let style: NSAlert.Style
        switch action {
        case .eject:
            title = L10n.t("devices.ejectConfirm", ["name": device.volumeName])
            message = L10n.t("devices.ejectConfirmNote")
            symbol = "externaldrive.badge.xmark"
            style = .warning
        case .repair:
            title = L10n.t("devices.repairConfirm")
            message = L10n.t("devices.repairConfirmNote") + "\n" + L10n.t("devices.targetDevice", ["name": device.volumeName])
            symbol = "wrench.and.screwdriver"
            style = .warning
        case .format:
            title = L10n.t("devices.formatConfirm")
            message = L10n.t("devices.formatConfirmNote")
            symbol = "exclamationmark.triangle.fill"
            style = .critical
        default:
            return
        }
        let confirmed = ConfirmAlert.run(
            .init(
                title: title,
                message: message,
                symbolName: symbol,
                style: style,
                continueTitle: L10n.t("dialog.continue"),
                cancelTitle: L10n.t("dialog.cancel")
            )
        )
        if confirmed {
            model.perform(action, on: device)
        }
    }

    private func byteText(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }
}

struct RenameSheet: View {
    @EnvironmentObject private var model: AppModel
    let device: NTFSDevice
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("devices.renameTitle")).font(.headline)
            Text(L10n.t("devices.renameNote")).font(.caption).foregroundStyle(.secondary)
            TextField(L10n.t("devices.renamePlaceholder"), text: $name)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button(L10n.t("dialog.cancel")) { model.renameDevice = nil }
                Button(L10n.t("dialog.confirm")) {
                    model.perform(.rename, on: device, extra: name)
                    model.renameDevice = nil
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear { name = device.volumeName }
    }
}
