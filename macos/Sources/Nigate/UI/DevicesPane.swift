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
            Spacer(minLength: compact ? 6 : 8)
            DeviceBatchActions(compact: compact, onRefresh: onRefresh)
        }
    }
}

struct DeviceBatchActions: View {
    @EnvironmentObject private var model: AppModel
    var compact: Bool
    var onRefresh: () -> Void

    var body: some View {
        // 托盘窄，不能退回「纯文字」：和图标对不上主界面。放不下标题就只留图标。
        Group {
            if compact {
                ViewThatFits(in: .horizontal) {
                    labeledRow(DeviceChipLabelStyle())
                    labeledRow(.iconOnly)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    labeledRow(.titleAndIcon)
                    labeledRow(.titleOnly)
                    labeledRow(.iconOnly)
                }
            }
        }
        .controlSize(compact ? .small : .regular)
    }

    private func labeledRow<S: LabelStyle>(_ style: S) -> some View {
        row(showHelp: style is IconOnlyLabelStyle).labelStyle(style)
    }

    private func row(showHelp: Bool) -> some View {
        HStack(spacing: compact ? 4 : 8) {
            batch("arrow.clockwise", L10n.t("devices.refreshDevices"), showHelp: showHelp, action: onRefresh)
                .disabled(model.isScanningDevices)
            if TrayBatchAvailability.canMountUnmounted(model.devices) {
                batch("externaldrive", L10n.t("devices.mountAllDevices"), showHelp: showHelp) { model.runBatch(.mount) }
            }
            if TrayBatchAvailability.canMountReadOnly(model.devices) {
                batch("pencil.and.outline", L10n.t("devices.mountAll"), showHelp: showHelp) { model.runBatch(.mount) }
            }
            if TrayBatchAvailability.canRestore(model.devices) {
                batch("eye", L10n.t("devices.restoreAllReadOnly"), showHelp: showHelp) { model.runBatch(.restore) }
            }
            if TrayBatchAvailability.canUnmount(model.devices) {
                batch("eject", L10n.t("devices.unmountAll"), showHelp: showHelp) { model.runBatch(.unmount) }
            }
            if TrayBatchAvailability.canEject(model.devices) {
                batch("externaldrive.badge.xmark", L10n.t("devices.ejectAll"), showHelp: showHelp) { model.runBatch(.eject) }
            }
        }
    }

    @ViewBuilder
    private func batch(_ icon: String, _ title: String, showHelp: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
        }
        .modifier(DeviceActionChrome(quiet: compact, pad: compact ? 6 : 8, help: showHelp ? title : nil))
    }
}

/// 托盘批量按钮：图标贴着标题，比系统 titleAndIcon 更省宽度。
private struct DeviceChipLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
                .imageScale(.small)
            configuration.title
        }
    }
}

enum DeviceCardDensity {
    case full
    case tray
}

/// 主窗口用系统 bordered；托盘叠在菜单栏玻璃上，改成淡色描边芯片。
/// 窗口气泡只给纯图标：有文字时再挂同文提示是多余的。
private struct DeviceActionChrome: ViewModifier {
    var quiet: Bool
    var pad: CGFloat = 8
    var help: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if quiet {
            content.buttonStyle(TrayChipButtonStyle(horizontalPad: pad))
                .modifier(OptionalHelp(text: help))
        } else {
            content.buttonStyle(.bordered)
                .modifier(OptionalHelp(text: help))
        }
    }
}

private struct OptionalHelp: ViewModifier {
    var text: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let text {
            content.nigateHelp(text)
        } else {
            content
        }
    }
}

private struct TrayChipButtonStyle: ButtonStyle {
    var horizontalPad: CGFloat = 8
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, horizontalPad)
            .padding(.vertical, 3)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(fillOpacity(pressed: configuration.isPressed)))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isEnabled ? 0.12 : 0.06), lineWidth: 1)
            }
            .opacity(isEnabled ? 1 : 0.45)
    }

    private func fillOpacity(pressed: Bool) -> Double {
        if !isEnabled { return 0.04 }
        return pressed ? 0.14 : 0.07
    }
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
        .background { cardFill }
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(density == .tray ? 0.12 : 0.06)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(TrayDeviceRow.accessibilityLabel(device, status: statusLabel))
    }

    @ViewBuilder
    private var cardFill: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        if density == .tray {
            // 比面板玻璃略深一档，卡片才站得住；不要退回实心窗口底。
            shape.fill(.regularMaterial)
                .overlay(shape.fill(Color.primary.opacity(0.07)))
        } else {
            shape.fill(Color(nsColor: .controlBackgroundColor))
        }
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
        actionRow(showHelp: style is IconOnlyLabelStyle).labelStyle(style)
    }

    private func actionRow(showHelp: Bool) -> some View {
        HStack {
            if device.needsMount {
                action(L10n.t("devices.mountDevice"), "externaldrive", showHelp: showHelp) { model.perform(.mount, on: device) }
            } else {
                if device.isReadOnly {
                    action(L10n.t("devices.mount"), "pencil", showHelp: showHelp) { model.perform(.mount, on: device) }
                }
                if device.isReadWrite {
                    action(L10n.t("devices.restoreReadOnly"), "eye", showHelp: showHelp) { model.perform(.restore, on: device) }
                }
                action(L10n.t("devices.unmount"), "eject", showHelp: showHelp) { model.perform(.unmount, on: device) }
                action(L10n.t("devices.eject"), "externaldrive.badge.xmark", showHelp: showHelp) { confirm(.eject) }
                if density == .full {
                    action(L10n.t("devices.repair"), "wrench.and.screwdriver", showHelp: showHelp) { confirm(.repair) }
                    action(L10n.t("devices.rename"), "character.cursor.ibeam", showHelp: showHelp) { model.renameDevice = device }
                    if device.canFormat {
                        action(L10n.t("devices.format"), "internaldrive", showHelp: showHelp) { confirm(.format) }
                    }
                    action(L10n.t("devices.reset"), "arrow.counterclockwise", showHelp: showHelp) { confirm(.reset) }
                }
            }
        }
    }

    private func action(_ title: String, _ icon: String, showHelp: Bool, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Label(title, systemImage: icon)
        }
        .modifier(DeviceActionChrome(quiet: density == .tray, help: showHelp ? title : nil))
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
