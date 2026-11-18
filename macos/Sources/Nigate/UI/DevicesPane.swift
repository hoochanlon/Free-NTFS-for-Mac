import SwiftUI
import AppKit

struct DevicesPane: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DevicePaneHeader(compact: false) {
                Task { await model.refreshDevices() }
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
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
                }
                .padding(.horizontal, -18)
            }
        }
        .padding(18)
    }
}

struct DevicePaneHeader: View {
    var compact: Bool
    var onRefresh: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(L10n.t("devices.title"))
                .font(compact ? .title3.weight(.semibold) : .title2.weight(.semibold))
                .layoutPriority(1)
            Spacer(minLength: 8)
            DeviceBatchActions(compact: compact, onRefresh: onRefresh)
        }
    }
}

struct DeviceBatchActions: View {
    @EnvironmentObject private var model: AppModel
    var compact: Bool
    var onRefresh: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            labeledRow(.titleAndIcon)
            labeledRow(.titleOnly)
            labeledRow(.iconOnly)
        }
        .controlSize(compact ? .small : .regular)
    }

    private func labeledRow<S: LabelStyle>(_ style: S) -> some View {
        row.labelStyle(style)
    }

    private var row: some View {
        HStack(spacing: compact ? 6 : 8) {
            batch("arrow.clockwise", L10n.t("devices.refreshDevices"), action: onRefresh)
                .disabled(model.isScanningDevices)
            if TrayBatchAvailability.canMountUnmounted(model.devices) {
                batch("externaldrive", L10n.t("devices.mountAllDevices")) { model.runBatch(.mount) }
            }
            if TrayBatchAvailability.canMountReadOnly(model.devices) {
                batch("pencil.and.outline", L10n.t("devices.mountAll")) { model.runBatch(.mount) }
            }
            if TrayBatchAvailability.canRestore(model.devices) {
                batch("eye", L10n.t("devices.restoreAllReadOnly")) { model.runBatch(.restore) }
            }
            if TrayBatchAvailability.canUnmount(model.devices) {
                batch("eject", L10n.t("devices.unmountAll")) { model.runBatch(.unmount) }
            }
            if TrayBatchAvailability.canEject(model.devices) {
                batch("externaldrive.badge.xmark", L10n.t("devices.ejectAll")) { model.runBatch(.eject) }
            }
        }
    }

    private func batch(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
        }
        .buttonStyle(.bordered)
        .help(title)
    }
}

enum DeviceCardDensity {
    case full
    case tray
}

struct DeviceCard: View {
    @EnvironmentObject private var model: AppModel
    let device: NTFSDevice
    var density: DeviceCardDensity = .full

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 信息区：双击打开挂载点；按钮行不绑双击，避免误触。
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
                if density == .full {
                    HStack(spacing: 18) {
                        labeled(L10n.t("devices.deviceLabel"), device.disk)
                        labeled(
                            L10n.t("devices.mountPointLabel"),
                            device.volume.isEmpty ? L10n.t("devices.notMounted") : device.volume
                        )
                    }
                }
                if let capacity = device.capacity {
                    VStack(alignment: .leading, spacing: 4) {
                        CapacityBar(capacity: capacity)
                        Text(CapacityText.summary(capacity))
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

            ViewThatFits(in: .horizontal) {
                labeledActions(.titleAndIcon)
                labeledActions(.titleOnly)
                labeledActions(.iconOnly)
            }
            .controlSize(density == .tray ? .small : .regular)
            .disabled(model.isDeviceBusy(device))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.06)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(TrayDeviceRow.accessibilityLabel(device, status: statusLabel))
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

    private func labeledActions<S: LabelStyle>(_ style: S) -> some View {
        actionRow().labelStyle(style)
    }

    private func actionRow() -> some View {
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
                if density == .full {
                    action(L10n.t("devices.repair"), "wrench.and.screwdriver") { confirm(.repair) }
                    action(L10n.t("devices.rename"), "character.cursor.ibeam") { model.renameDevice = device }
                    if device.canFormat {
                        action(L10n.t("devices.format"), "internaldrive") { confirm(.format) }
                    }
                    action(L10n.t("devices.reset"), "arrow.counterclockwise") { confirm(.reset) }
                }
            }
        }
    }

    private func action(_ title: String, _ icon: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Label(title, systemImage: icon)
        }
        .buttonStyle(.bordered)
        .help(title)
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
