import SwiftUI
import AppKit

struct CopyCommandButton: View {
    let command: String
    @State private var copied = false
    @State private var copyToken = 0

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
            copyToken += 1
            withAnimation(.spring(response: 0.32, dampingFraction: 0.62)) {
                copied = true
            }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .fontWeight(.semibold)
                .foregroundStyle(copied ? Palette.success : Color.primary)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: copyToken)
                .frame(width: 28, height: 28)
                .scaleEffect(copied ? 1.08 : 1)
        }
        .buttonStyle(.bordered)
        .tint(copied ? Palette.success : nil)
        .nigateHelp(L10n.t("dependencies.copyCommand"))
        .accessibilityLabel(L10n.t("dependencies.copyCommand"))
        .task(id: copyToken) {
            guard copyToken > 0 else { return }
            try? await Task.sleep(for: .milliseconds(1300))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                copied = false
            }
        }
    }
}
