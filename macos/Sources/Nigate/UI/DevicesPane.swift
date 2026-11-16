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
                .disabled(model.isScanningDevices)
                if model.devices.contains(where: \.needsMount) {
                    batch("externaldrive", L10n.t("devices.mountAllDevices")) { model.runBatch(.mount) }
                }
                if model.devices.contains(where: { !$0.needsMount && $0.isReadOnly }) {
                    batch("pencil.and.outline", L10n.t("devices.mountAll")) { model.runBatch(.mount) }
                }
                if model.devices.contains(where: \.isReadWrite) {
                    batch("eye", L10n.t("devices.restoreAllReadOnly")) { model.runBatch(.restore) }
                }
                if model.devices.contains(where: { !$0.needsMount }) {
                    batch("eject", L10n.t("devices.unmountAll")) { model.runBatch(.unmount) }
                }
                if !model.devices.isEmpty {
                    batch("externaldrive.badge.xmark", L10n.t("devices.ejectAll")) { model.runBatch(.eject) }
                }
            }
            if model.devices.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    switch model.deviceListAppearance {
                    case .scanning, .cards:
                        ProgressView()
                            .controlSize(.regular)
                            .padding(.bottom, 4)
                        Text(L10n.t("devices.scanningState")).font(.headline)
                        Text(L10n.t("devices.scanningHint"))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    case .empty:
                        if let hint = model.progressHint {
                            ProgressView()
                                .controlSize(.regular)
                                .padding(.bottom, 4)
                            Text(hint)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        } else {
                            Image(systemName: "externaldrive.badge.questionmark").font(.system(size: 42)).foregroundStyle(.secondary)
                            Text(L10n.t("devices.emptyState")).font(.headline)
                            Text(L10n.t("devices.emptyHint")).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(model.devices, id: \.devicePath) { device in
                            DeviceCard(device: device)
                        }
                    }
                    .animation(nil, value: model.devices.map(\.devicePath))
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
        .controlSize(.regular)
    }
}

/// 不用系统 ProgressView。切换 NSApp.appearance 会清掉它的 tint，而且不会再设回来。
private struct CapacityBar: View {
    let capacity: Capacity

    var body: some View {
        let fraction = min(1, max(0, Double(capacity.used) / Double(max(capacity.total, 1))))
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule()
                    .fill(fill)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 4)
        .accessibilityElement()
        .accessibilityValue(Text(capacity.usedPercentLabel))
    }

    private var fill: Color {
        switch capacity.fillLevel {
        case .normal: Palette.accent
        case .warning: Palette.warning
        case .critical: Palette.error
        }
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
                        CapacityBar(capacity: capacity)
                        Text("\(L10n.t("devices.available")) \(byteText(capacity.available))  ·  \(L10n.t("devices.total")) \(byteText(capacity.total))  ·  \(L10n.t("devices.usageRate")) \(capacity.usedPercentLabel)")
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

            HStack {
                if device.needsMount {
                    action(L10n.t("devices.mountDevice"), "externaldrive") { model.perform(.mount, on: device) }
                } else {
                    if device.isReadOnly {
                        action(L10n.t("devices.mount"), "pencil") { model.perform(.mount, on: device) }
                    }
                    if device.isReadWrite {
                        action(L10n.t("devices.restoreReadOnly"), "eye") { model.perform(.restore, on: device) }
                    }
                    action(L10n.t("devices.unmount"), "eject") { model.perform(.unmount, on: device) }
                    action(L10n.t("devices.eject"), "externaldrive.badge.xmark") { confirm(.eject) }
                    action(L10n.t("devices.repair"), "wrench.and.screwdriver") { confirm(.repair) }
                    action(L10n.t("devices.rename"), "character.cursor.ibeam") { model.renameDevice = device }
                    if device.canFormat {
                        action(L10n.t("devices.format"), "internaldrive") { confirm(.format) }
                    }
                    action(L10n.t("devices.reset"), "arrow.counterclockwise") { confirm(.reset) }
                }
            }
            .disabled(model.busyDisks.contains(device.parentDisk))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.06)))
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
        .controlSize(.regular)
    }

    private func confirm(_ action: DeviceAction) {
        let title: String
        let message: String
        let symbol: String
        let critical: Bool
        switch action {
        case .eject:
            title = L10n.t("devices.ejectConfirm", ["name": device.volumeName])
            message = L10n.t("devices.ejectConfirmNote")
            symbol = "externaldrive.badge.xmark"
            critical = false
        case .repair:
            title = L10n.t("devices.repairConfirm")
            message = L10n.t("devices.repairConfirmNote") + "\n" + L10n.t("devices.targetDevice", ["name": device.volumeName])
            symbol = "wrench.and.screwdriver"
            critical = false
        case .format:
            title = L10n.t("devices.formatConfirm")
            message = L10n.t("devices.formatConfirmNote")
            symbol = "exclamationmark.triangle.fill"
            critical = true
        case .reset:
            title = L10n.t("devices.resetConfirm", ["name": device.volumeName])
            message = L10n.t("devices.resetConfirmNote")
            symbol = "arrow.counterclockwise"
            critical = false
        default:
            return
        }
        let target = device
        model.presentWindowConfirm(
            title: title,
            message: message,
            symbol: symbol,
            critical: critical,
            confirmTitle: L10n.t("dialog.continue")
        ) { [weak model] in
            model?.perform(action, on: target)
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
            Text(L10n.t("devices.renameNote"))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
