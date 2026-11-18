import SwiftUI
import AppKit

enum TrayLayout {
    static let width: CGFloat = 420
    static let cardHeight: CGFloat = 122
    static let cardGap: CGFloat = 10
    /// 菜单栏浮层只露出两张卡。四张整列会把面板拉成整屏。
    static let visibleCardLimit = 2

    static var maxListHeight: CGFloat {
        listHeight(deviceCount: visibleCardLimit)
    }

    static func needsScroll(_ deviceCount: Int) -> Bool {
        deviceCount > visibleCardLimit
    }

    static func listHeight(deviceCount: Int) -> CGFloat {
        let visible = min(max(deviceCount, 0), visibleCardLimit)
        guard visible > 0 else { return 160 }
        return CGFloat(visible) * cardHeight + CGFloat(visible - 1) * cardGap
    }

    /// 首帧先按设备数估高，避免 NSHostingView 还没报尺寸时面板被压成一条。
    static func estimatedHeight(deviceCount: Int, hasHint: Bool) -> CGFloat {
        let chrome: CGFloat = 42
        let divider: CGFloat = 1
        let padding: CGFloat = 36
        let titleRow: CGFloat = 28
        let stackGap: CGFloat = 12
        let cards = deviceCount == 0 ? 160 : listHeight(deviceCount: deviceCount)
        let hint: CGFloat = hasHint ? stackGap + 18 : 0
        return chrome + divider + padding + titleRow + stackGap + cards + hint
    }
}

enum TrayPanelPlacement {
    /// 贴菜单栏下沿。留 2pt 给面板阴影，再大就像飘着。
    static let gap: CGFloat = 2
    static let screenPad: CGFloat = 8

    /// 顶边钉在按钮下沿。高度变化只往下长，水平以按钮为中心，出屏才平移。
    static func origin(button: CGRect, size: CGSize, visible: CGRect) -> CGPoint {
        let minX = visible.minX + screenPad
        let maxX = max(minX, visible.maxX - size.width - screenPad)
        let x = min(max(button.midX - size.width / 2, minX), maxX)
        let attachY = min(button.minY, visible.maxY)
        let y = attachY - gap - size.height
        return CGPoint(x: x, y: max(visible.minY + screenPad, y))
    }
}

enum TrayBatchAvailability {
    static func canMountUnmounted(_ devices: [NTFSDevice]) -> Bool {
        devices.contains(where: \.needsMount)
    }

    static func canMountReadOnly(_ devices: [NTFSDevice]) -> Bool {
        devices.contains { !$0.needsMount && $0.isReadOnly }
    }

    static func canRestore(_ devices: [NTFSDevice]) -> Bool {
        devices.contains(where: \.isReadWrite)
    }

    static func canUnmount(_ devices: [NTFSDevice]) -> Bool {
        devices.contains { !$0.needsMount }
    }

    static func canEject(_ devices: [NTFSDevice]) -> Bool {
        !devices.isEmpty
    }
}

private struct TraySizeKey: PreferenceKey {
    static let defaultValue = CGSize.zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next.width > 0, next.height > 0 { value = next }
    }
}

struct TrayPopoverRoot: View {
    @ObservedObject var model: AppModel
    var onSize: (CGSize) -> Void

    var body: some View {
        // 估高偏大时多出来的高度必须堆在底下，否则白卡片在透明面板里垂直居中，图标和面板之间会空一截。
        VStack(spacing: 0) {
            TrayPopoverView()
                .background {
                    GeometryReader { geo in
                        Color.clear.preference(key: TraySizeKey.self, value: geo.size)
                    }
                }
            Spacer(minLength: 0)
        }
        .environmentObject(model)
        .onPreferenceChange(TraySizeKey.self) { size in
            guard size.width > 1, size.height > 1 else { return }
            onSize(size)
        }
    }
}

/// 菜单栏里的压缩设备页：同一套标题栏零件、分隔线、页头和设备卡。
struct TrayPopoverView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            chrome
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                DevicePaneHeader(compact: true) {
                    Task { await model.refreshDevices(applyAutoMount: false) }
                }
                deviceList
                if let hint = model.progressHint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(18)
        }
        .frame(width: TrayLayout.width)
        .fixedSize(horizontal: true, vertical: true)
        .id(model.languageStamp)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            if model.quitConfirmOpen {
                ZStack {
                    Color.black.opacity(0.46)
                    QuitConfirmSheet(compact: true)
                        .padding(18)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var chrome: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                NigateMark()
                Text("Nigate")
                    .font(.system(size: 15, weight: .semibold))
            }
            Spacer(minLength: 8)
            HStack(spacing: 10) {
                ChromeIconButton(
                    system: "cup.and.saucer.fill",
                    title: SleepChrome.title(model.settings.sleepMode),
                    active: model.settings.sleepMode != .off,
                    tint: SleepChrome.tint(model.settings.sleepMode)
                ) {
                    model.cycleSleep()
                }
                .disabled(model.protectLocked)
                ChromeProtectButton()
                ChromeIconButton(
                    system: "macwindow",
                    title: L10n.t("tray.showMainWindow"),
                    active: false,
                    tint: Color.primary.opacity(0.7)
                ) {
                    TrayController.shared.dismiss()
                    model.setTab(.devices)
                    model.revealMainWindow()
                    Task { await model.refreshDevices(applyAutoMount: false) }
                }
                ChromeIconButton(
                    system: "power",
                    title: L10n.t("tray.quit"),
                    active: model.quitConfirmOpen,
                    tint: Palette.error
                ) {
                    model.requestQuit()
                }
                ChromeStatusChip()
                    .padding(.leading, 6)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var deviceList: some View {
        if model.devices.isEmpty {
            emptyState
        } else if TrayLayout.needsScroll(model.devices.count) {
            // 和外层 18pt 对冲，滑条贴面板右缘，卡片仍留在内边距里。
            ScrollView(.vertical) {
                cards
                    .padding(.horizontal, 18)
            }
            .scrollIndicators(.visible, axes: .vertical)
            .frame(height: TrayLayout.maxListHeight)
            .padding(.horizontal, -18)
        } else {
            cards
        }
    }

    private var cards: some View {
        VStack(spacing: TrayLayout.cardGap) {
            ForEach(model.devices, id: \.devicePath) { device in
                DeviceCard(device: device, density: .tray)
            }
        }
        .animation(nil, value: model.devices.map(\.devicePath))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            switch model.deviceListAppearance {
            case .scanning, .cards:
                ProgressView()
                    .controlSize(.regular)
                    .padding(.bottom, 4)
                Text(L10n.t("devices.scanningState")).font(.headline)
                Text(L10n.t("devices.scanningHint"))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            case .empty:
                Image(systemName: "externaldrive.badge.questionmark")
                    .font(.system(size: 42))
                    .foregroundStyle(.secondary)
                Text(L10n.t("devices.emptyState")).font(.headline)
                Text(L10n.t("devices.emptyHint"))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
    }
}
