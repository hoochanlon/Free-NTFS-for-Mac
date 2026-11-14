import SwiftUI
import AppKit

enum HelpScrollTarget: Hashable {
    case block(Int)
}

private enum HelpImageLayout {
    static let width: CGFloat = 520

    static func size(for image: NSImage) -> CGSize {
        let original = image.size
        guard original.width > 0, original.height > 0 else {
            return CGSize(width: width, height: 300)
        }
        return CGSize(width: width, height: width * original.height / original.width)
    }
}

struct HelpMarkdownView: View {
    let blocks: [HelpBlock]
    let activeSearchBlockID: Int?

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 15) {
            ForEach(blocks) { block in
                content(for: block)
                    .padding(.horizontal, 8)
                    .padding(.vertical, block.id == activeSearchBlockID ? 7 : 0)
                    .background {
                        if block.id == activeSearchBlockID {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.13))
                        }
                    }
                    .id(HelpScrollTarget.block(block.id))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    @ViewBuilder
    private func content(for block: HelpBlock) -> some View {
        switch block.content {
        case let .heading(level, value):
            heading(value, level: level)
        case let .paragraph(value):
            inline(value)
                .font(.body)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        case let .list(items):
            VStack(alignment: .leading, spacing: 9) {
                ForEach(items) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(marker(for: item.marker))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 25, alignment: .trailing)
                        inline(item.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.leading, CGFloat(item.depth) * 18)
                }
            }
            .padding(.vertical, 2)
        case let .code(language, source):
            codeBlock(language: language, source: source)
        case let .callout(kind, value):
            callout(kind: kind, text: value)
        case let .table(rows):
            table(rows)
        case let .image(name, alt):
            imageBlock(name: name, alt: alt)
        }
    }

    @ViewBuilder
    private func heading(_ value: String, level: Int) -> some View {
        switch level {
        case 1:
            inline(value)
                .font(.system(size: 27, weight: .bold))
                .padding(.top, 3)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(.quaternary)
                        .frame(height: 1)
                }
        case 2:
            inline(value)
                .font(.title2.weight(.semibold))
                .padding(.top, 15)
                .padding(.bottom, 1)
        case 3:
            inline(value)
                .font(.headline)
                .padding(.top, 8)
        default:
            inline(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 5)
        }
    }

    private func codeBlock(language: String, source: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                if !language.isEmpty {
                    Text(language.uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                CopyCommandButton(command: source)
            }
            ScrollView(.horizontal) {
                Text(source)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.primary.opacity(0.08)))
    }

    private func callout(kind: HelpCalloutKind, text: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: kind.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(kind.tint)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 5) {
                Text(kind.rawValue)
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(kind.tint)
                inline(text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(kind.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(kind.tint)
                .frame(width: 3)
                .padding(.vertical, 9)
        }
    }

    private func table(_ rows: [[String]]) -> some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(rows.indices, id: \.self) { rowIndex in
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(rows[rowIndex].indices, id: \.self) { columnIndex in
                            inline(rows[rowIndex][columnIndex])
                                .font(rowIndex == 0 ? .subheadline.weight(.semibold) : .body)
                                .frame(minWidth: 120, maxWidth: 260, alignment: .leading)
                                .padding(10)
                                .frame(maxHeight: .infinity, alignment: .topLeading)
                                .background(rowIndex == 0 ? Color.primary.opacity(0.045) : .clear)
                            if columnIndex < rows[rowIndex].count - 1 {
                                Rectangle()
                                    .fill(.quaternary)
                                    .frame(width: 1)
                            }
                        }
                    }
                    if rowIndex < rows.count - 1 {
                        Divider()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
        }
    }

    @ViewBuilder
    private func imageBlock(name: String, alt: String) -> some View {
        if let url = helpImageURL(name), let nsImage = NSImage(contentsOf: url) {
            let size = HelpImageLayout.size(for: nsImage)
            Group {
                if url.pathExtension.lowercased() == "gif" {
                    HelpAnimatedImage(url: url, size: size)
                } else {
                    Image(nsImage: nsImage)
                        .resizable()
                        .interpolation(.high)
                }
            }
            .frame(width: size.width, height: size.height)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityAlt(alt))
            .padding(.vertical, 4)
        } else if showsCaption(alt) {
            Text(alt)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
        }
    }

    private func showsCaption(_ alt: String) -> Bool {
        let trimmed = alt.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.compare("Image", options: .caseInsensitive) != .orderedSame
    }

    private func accessibilityAlt(_ alt: String) -> String {
        showsCaption(alt) ? alt : ""
    }

    private func helpImageURL(_ name: String) -> URL? {
        let file = URL(fileURLWithPath: name).lastPathComponent
        return L10n.resource("Help/images/\(file)")
            ?? L10n.resource("Help/\(name)")
            ?? L10n.resource(name)
    }

    private func inline(_ source: String) -> Text {
        let cleaned = source.replacingOccurrences(
            of: "<img\\b[^>]*>",
            with: "",
            options: .regularExpression
        )
        let value = (try? AttributedString(markdown: cleaned, options: .init(interpretedSyntax: .full)))
            ?? AttributedString(cleaned)
        return Text(value)
    }

    private func marker(for marker: HelpListItem.Marker) -> String {
        switch marker {
        case .bullet:
            "•"
        case let .numbered(number):
            "\(number)."
        }
    }
}

private struct HelpAnimatedImage: NSViewRepresentable {
    let url: URL
    let size: CGSize

    func makeNSView(context: Context) -> NSImageView {
        let view = HelpGIFImageView()
        view.imageScaling = .scaleAxesIndependently
        view.animates = true
        view.canDrawSubviewsIntoLayer = true
        view.imageFrameStyle = .none
        view.imageAlignment = .alignCenter
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.image = NSImage(contentsOf: url)
        return view
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        if nsView.image == nil {
            nsView.image = NSImage(contentsOf: url)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSImageView, context: Context) -> CGSize? {
        size
    }
}

private final class HelpGIFImageView: NSImageView {
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
}

private extension HelpCalloutKind {
    var symbol: String {
        switch self {
        case .tip: "lightbulb"
        case .important: "exclamationmark.circle"
        case .warning, .caution: "exclamationmark.triangle"
        case .note: "info.circle"
        }
    }

    var tint: Color {
        switch self {
        case .tip: .green
        case .important: .orange
        case .warning, .caution: .red
        case .note: .accentColor
        }
    }
}
