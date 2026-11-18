import Foundation

/// 占用文案。主窗口和托盘同一口径：可用 / 共 / 使用率。进度条颜色另外表达告警。
enum CapacityText {
    static func summary(_ capacity: Capacity) -> String {
        "\(L10n.t("devices.available")) \(bytes(capacity.available))  ·  \(L10n.t("devices.total")) \(bytes(capacity.total))  ·  \(L10n.t("devices.usageRate")) \(capacity.usedPercentLabel)"
    }

    static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }
}
