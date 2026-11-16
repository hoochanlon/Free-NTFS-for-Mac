import SwiftUI
import AppKit

enum HelpScrollTarget: Hashable {
    case block(Int)
}

enum HelpScrollSpace {
    static let name = "help-scroll"
}

/// Lazy 容器只上报窗口内的块；章节由阅读线（刚越过视口顶部的块）反推，不能取 minY 最小的旧块。
enum HelpVisibleBlockKey: PreferenceKey {
    static let defaultValue: [Int: CGFloat] = [:]

    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
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
                    .background {
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: HelpVisibleBlockKey.self,
                                value: [block.id: geo.frame(in: .named(HelpScrollSpace.name)).minY]
                            )
                        }
                    }
                    .id(HelpScrollTarget.block(block.id))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    @ViewBuilder
    private func content(for block: HelpBlock) -> some View {
        switch block.content {
        case let .heading(level, value):
            heading(value, level: level)
        case let .paragraph(value):
            inline(value, font: .preferredFont(forTextStyle: .body), lineSpacing: 5)
                .frame(maxWidth: .infinity, alignment: .leading)
        case let .list(items):
            let listFont = NSFont.preferredFont(forTextStyle: .body)
            VStack(alignment: .leading, spacing: 9) {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 8) {
                        inline(
                            marker(for: item.marker),
                            font: listFont,
                            color: .secondaryLabelColor,
                            alignment: .right
                        )
                        .frame(width: 25, alignment: .top)
                        inline(item.text, font: listFont)
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
            inline(value, font: .systemFont(ofSize: 27, weight: .bold))
                .padding(.top, 3)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(.quaternary)
                        .frame(height: 1)
                }
        case 2:
            inline(value, font: Self.semibold(.title2))
                .padding(.top, 15)
                .padding(.bottom, 1)
        case 3:
            inline(value, font: .preferredFont(forTextStyle: .headline))
                .padding(.top, 8)
        default:
            inline(value, font: Self.semibold(.subheadline), color: .secondaryLabelColor)
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
                inline(text, font: .preferredFont(forTextStyle: .body))
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
                            inline(
                                rows[rowIndex][columnIndex],
                                font: rowIndex == 0 ? Self.semibold(.subheadline) : .preferredFont(forTextStyle: .body)
                            )
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

    private func inline(
        _ source: String,
        font: NSFont,
        color: NSColor = .labelColor,
        lineSpacing: CGFloat = 0,
        alignment: NSTextAlignment = .left
    ) -> some View {
        HelpMarkdownText(
            source: stripInlineImages(source),
            font: font,
            color: color,
            lineSpacing: lineSpacing,
            alignment: alignment
        )
    }

    private func stripInlineImages(_ source: String) -> String {
        source.replacingOccurrences(
            of: "<img\\b[^>]*>",
            with: "",
            options: .regularExpression
        )
    }

    private static func semibold(_ style: NSFont.TextStyle) -> NSFont {
        let size = NSFont.preferredFont(forTextStyle: style).pointSize
        return .systemFont(ofSize: size, weight: .semibold)
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

/// AppKit 文本：SwiftUI `Text` 的 markdown 链接在 macOS 上不会出手形。
private struct HelpMarkdownText: NSViewRepresentable {
    let source: String
    let font: NSFont
    var color: NSColor = .labelColor
    var lineSpacing: CGFloat = 0
    var alignment: NSTextAlignment = .left

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var source = ""
        var fontSize: CGFloat = 0
        var lineSpacing: CGFloat = -1
        var alignment: NSTextAlignment = .natural
    }

    func makeNSView(context: Context) -> HelpLinkTextView {
        let view = HelpLinkTextView()
        view.drawsBackground = false
        view.backgroundColor = .clear
        view.isEditable = false
        view.isSelectable = true
        view.isRichText = true
        view.isVerticallyResizable = false
        view.isHorizontallyResizable = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.heightTracksTextView = false
        view.displaysLinkToolTips = true
        view.isAutomaticLinkDetectionEnabled = false
        view.focusRingType = .none
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .cursor: NSCursor.pointingHand
        ]
        return view
    }

    func updateNSView(_ view: HelpLinkTextView, context: Context) {
        view.font = font
        view.textColor = color
        let changed = context.coordinator.source != source
            || context.coordinator.fontSize != font.pointSize
            || context.coordinator.lineSpacing != lineSpacing
            || context.coordinator.alignment != alignment
        if changed {
            view.textStorage?.setAttributedString(
                Self.attributed(source, font: font, color: color, lineSpacing: lineSpacing, alignment: alignment)
            )
            context.coordinator.source = source
            context.coordinator.fontSize = font.pointSize
            context.coordinator.lineSpacing = lineSpacing
            context.coordinator.alignment = alignment
            view.window?.invalidateCursorRects(for: view)
        }
        view.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: HelpLinkTextView, context: Context) -> CGSize? {
        let proposed = proposal.width ?? nsView.bounds.width
        let width = (proposed.isFinite && proposed > 0) ? proposed : HelpImageLayout.width
        guard let container = nsView.textContainer, let layout = nsView.layoutManager else {
            return CGSize(width: width, height: font.pointSize)
        }
        container.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        layout.ensureLayout(for: container)
        let used = layout.usedRect(for: container)
        let minHeight = ceil(font.ascender - font.descender + font.leading + lineSpacing)
        return CGSize(width: width, height: max(ceil(used.maxY), minHeight))
    }

    private static func attributed(
        _ source: String,
        font: NSFont,
        color: NSColor,
        lineSpacing: CGFloat,
        alignment: NSTextAlignment
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        paragraph.alignment = alignment
        paragraph.paragraphSpacing = 0
        paragraph.paragraphSpacingBefore = 0
        let parsed = (try? NSAttributedString(
            markdown: Data(source.utf8),
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? NSAttributedString(string: source)
        let result = NSMutableAttributedString(attributedString: parsed)
        let range = NSRange(location: 0, length: result.length)
        guard range.length > 0 else { return result }
        result.addAttribute(.paragraphStyle, value: paragraph, range: range)
        result.enumerateAttributes(in: range, options: []) { attrs, subrange, _ in
            if attrs[.font] == nil {
                result.addAttribute(.font, value: font, range: subrange)
            }
            if attrs[.link] == nil, attrs[.foregroundColor] == nil {
                result.addAttribute(.foregroundColor, value: color, range: subrange)
            }
        }
        return result
    }
}

private final class HelpLinkTextView: NSTextView {
    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard let storage = textStorage, let layout = layoutManager, let container = textContainer else { return }
        let full = NSRange(location: 0, length: storage.length)
        storage.enumerateAttribute(.link, in: full) { value, range, _ in
            guard value != nil else { return }
            let glyphs = layout.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            layout.enumerateEnclosingRects(
                forGlyphRange: glyphs,
                withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                in: container
            ) { rect, _ in
                self.addCursorRect(rect, cursor: .pointingHand)
            }
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
