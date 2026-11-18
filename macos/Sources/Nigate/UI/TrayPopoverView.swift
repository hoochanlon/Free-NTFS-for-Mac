import SwiftUI
import AppKit

enum TrayLayout {
    static let width: CGFloat = 420
    static let cardHeight: CGFloat = 110
    static let cardGap: CGFloat = 10
    /// 默认露出两张卡。拖底部最多拉到四张。
    static let visibleCardLimit = 2
    static let maxVisibleCardLimit = 4
    static let cornerRadius: CGFloat = 16
    static let resizeStripHeight: CGFloat = 10

    static var defaultListHeight: CGFloat {
        listHeight(deviceCount: visibleCardLimit, limit: visibleCardLimit)
    }

    static var maxListHeight: CGFloat {
        listHeight(deviceCount: maxVisibleCardLimit, limit: maxVisibleCardLimit)
    }

    static func needsScroll(_ deviceCount: Int) -> Bool {
        needsScroll(deviceCount: deviceCount, listHeight: defaultListHeight)
    }

    static func needsScroll(deviceCount: Int, listHeight: CGFloat, contentHeight: CGFloat = 0) -> Bool {
        let content = contentHeight > 1 ? contentHeight : contentListHeight(deviceCount)
        return content > listHeight + 0.5
    }

    static func contentListHeight(_ deviceCount: Int) -> CGFloat {
        listHeight(deviceCount: deviceCount, limit: .max)
    }

    static func listHeight(deviceCount: Int) -> CGFloat {
        listHeight(deviceCount: deviceCount, limit: visibleCardLimit)
    }

    static func listHeight(deviceCount: Int, limit: Int) -> CGFloat {
        let visible = min(max(deviceCount, 0), limit)
        guard visible > 0 else { return 160 }
        return CGFloat(visible) * cardHeight + CGFloat(visible - 1) * cardGap
    }

    /// 首帧按默认两张卡估高，避免 NSHostingView 还没报尺寸时面板被压成一条。
    static func estimatedHeight(deviceCount: Int, hasHint: Bool) -> CGFloat {
        let chrome: CGFloat = 42
        let divider: CGFloat = 1
        let padding: CGFloat = 28
        let titleRow: CGFloat = 28
        let stackGap: CGFloat = 12
        let cards = deviceCount == 0 ? 160 : listHeight(deviceCount: deviceCount)
        let hint: CGFloat = hasHint ? stackGap + 18 : 0
        return chrome + divider + padding + titleRow + stackGap + cards + hint
    }
}

/// 列表区可拖高度：最少默认两张（设备更少时贴内容），最多四张。
/// 有实测堆叠高度时按真实卡片换算，避免估高把视口撑出空白。
enum TrayListResize {
    static func minListHeight(deviceCount: Int, contentHeight: CGFloat = 0) -> CGFloat {
        slotHeight(TrayLayout.visibleCardLimit, contentHeight: contentHeight, deviceCount: deviceCount)
    }

    static func maxListHeight(deviceCount: Int, contentHeight: CGFloat = 0) -> CGFloat {
        slotHeight(TrayLayout.maxVisibleCardLimit, contentHeight: contentHeight, deviceCount: deviceCount)
    }

    static func clamp(_ height: CGFloat, deviceCount: Int, contentHeight: CGFloat = 0) -> CGFloat {
        let lo = minListHeight(deviceCount: deviceCount, contentHeight: contentHeight)
        let hi = maxListHeight(deviceCount: deviceCount, contentHeight: contentHeight)
        return min(max(height, lo), hi)
    }

    static func canResize(deviceCount: Int, contentHeight: CGFloat = 0) -> Bool {
        maxListHeight(deviceCount: deviceCount, contentHeight: contentHeight)
            - minListHeight(deviceCount: deviceCount, contentHeight: contentHeight) > 0.5
    }

    /// 用整列实测高度反推单卡，再按要露出的张数还原视口。
    static func slotHeight(_ visibleLimit: Int, contentHeight: CGFloat, deviceCount: Int) -> CGFloat {
        let fallback = TrayLayout.listHeight(deviceCount: deviceCount, limit: visibleLimit)
        guard deviceCount > 0, contentHeight > 1 else { return fallback }
        let gaps = CGFloat(max(deviceCount - 1, 0)) * TrayLayout.cardGap
        let card = max(contentHeight - gaps, 0) / CGFloat(deviceCount)
        let visible = min(max(visibleLimit, 0), deviceCount)
        guard visible > 0 else { return fallback }
        return CGFloat(visible) * card + CGFloat(max(visible - 1, 0)) * TrayLayout.cardGap
    }
}

@MainActor
final class TrayMetrics: ObservableObject {
    @Published var listHeight: CGFloat = TrayLayout.defaultListHeight
    /// 卡片堆叠实测高度。0 表示还没量到，回退估高。
    @Published var contentHeight: CGFloat = 0

    func reset(deviceCount: Int) {
        listHeight = TrayListResize.minListHeight(
            deviceCount: deviceCount,
            contentHeight: contentHeight
        )
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
    @ObservedObject var metrics: TrayMetrics
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
        .environmentObject(metrics)
        .onPreferenceChange(TraySizeKey.self) { size in
            guard size.width > 1, size.height > 1 else { return }
            onSize(size)
        }
    }
}

/// 菜单栏里的压缩设备页：同一套标题栏零件、分隔线、页头和设备卡。
struct TrayPopoverView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var metrics: TrayMetrics

    private var listHeight: CGFloat {
        TrayListResize.clamp(
            metrics.listHeight,
            deviceCount: model.devices.count,
            contentHeight: metrics.contentHeight
        )
    }

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
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 10)
        }
        .frame(width: TrayLayout.width)
        .fixedSize(horizontal: true, vertical: true)
        .id(model.languageStamp)
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: TrayLayout.cornerRadius, style: .continuous))
        // 裁切之后再挂气泡层，提示画在面板坐标系里，不会被圆角吃掉。
        .nigateHelpHost()
        .onChange(of: model.devices.count) { _, count in
            metrics.contentHeight = 0
            metrics.listHeight = TrayListResize.clamp(metrics.listHeight, deviceCount: count)
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
                ChromeThemeButton()
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
        } else if TrayListResize.canResize(deviceCount: model.devices.count, contentHeight: metrics.contentHeight) {
            let scrolls = TrayLayout.needsScroll(
                deviceCount: model.devices.count,
                listHeight: listHeight,
                contentHeight: metrics.contentHeight
            )
            // 和外层 18pt 对冲，滑条贴面板右缘，卡片仍留在内边距里。
            ScrollView(.vertical) {
                cards
                    .padding(.horizontal, 18)
            }
            .scrollIndicators(scrolls ? .visible : .hidden, axes: .vertical)
            .scrollDisabled(!scrolls)
            .frame(height: listHeight)
            .padding(.horizontal, -18)
            .animation(nil, value: listHeight)
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
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            applyMeasuredContentHeight(height)
        }
        .animation(nil, value: model.devices.map(\.devicePath))
    }

    private func applyMeasuredContentHeight(_ height: CGFloat) {
        guard height > 1, abs(height - metrics.contentHeight) > 0.5 else { return }
        metrics.contentHeight = height
        metrics.listHeight = TrayListResize.clamp(
            metrics.listHeight,
            deviceCount: model.devices.count,
            contentHeight: height
        )
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
