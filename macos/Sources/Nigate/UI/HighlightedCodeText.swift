import SwiftUI

struct HighlightedCodeText: View {
    let source: String
    var language: String = ""
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        highlighted
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
    }

    private var highlighted: Text {
        let spans = CodeHighlight.spans(in: source, language: language)
        let dark = colorScheme == .dark
        guard let first = spans.first else { return Text("") }
        return spans.dropFirst().reduce(piece(first, dark: dark)) { text, span in
            text + piece(span, dark: dark)
        }
    }

    private func piece(_ span: CodeSpan, dark: Bool) -> Text {
        Text(span.text).foregroundStyle(span.kind.color(dark: dark))
    }
}

private extension CodeSpanKind {
    func color(dark: Bool) -> Color {
        switch self {
        case .plain:
            .primary
        case .comment:
            rgb(dark ? 0x8B949E : 0x57606A)
        case .string:
            rgb(dark ? 0xA5D6FF : 0x0A3069)
        case .variable:
            rgb(dark ? 0xFFA657 : 0x953800)
        case .number, .attr:
            rgb(dark ? 0x79C0FF : 0x0550AE)
        case .keyword, .builtin:
            rgb(dark ? 0xFF7B72 : 0xCF222E)
        case .title:
            rgb(dark ? 0xD2A8FF : 0x6639BA)
        }
    }
}

private func rgb(_ hex: Int) -> Color {
    Color(
        .sRGB,
        red: Double((hex >> 16) & 0xFF) / 255,
        green: Double((hex >> 8) & 0xFF) / 255,
        blue: Double(hex & 0xFF) / 255
    )
}
