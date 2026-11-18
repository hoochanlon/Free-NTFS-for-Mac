import SwiftUI

/// 不用系统 ProgressView。切换 NSApp.appearance 会清掉它的 tint，而且不会再设回来。
struct CapacityBar: View {
    let capacity: Capacity
    var height: CGFloat = 4

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
        .frame(height: height)
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
