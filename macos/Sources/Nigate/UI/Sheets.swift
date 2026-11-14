import SwiftUI
import AppKit
import ImageIO

struct HelpPane: View {
    @State private var blocks: [HelpBlock]
    @State private var isContentsVisible = false
    @State private var searchText = ""
    @State private var selectedMatch = 0
    @State private var requestedHeadingID: Int?
    @State private var navigationRequest = UUID()

    init() {
        _blocks = State(initialValue: HelpMarkdownParser.parse(L10n.helpMarkdown()))
    }

    private var outline: [HelpOutlineNode] {
        HelpMarkdownIndex.outline(in: blocks)
    }

    private var searchMatches: [Int] {
        HelpMarkdownIndex.matchingBlockIDs(query: searchText, in: blocks)
    }

    private var activeMatch: Int? {
        searchMatches.indices.contains(selectedMatch) ? searchMatches[selectedMatch] : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isContentsVisible.toggle()
                    }
                } label: {
                    Label(L10n.t("help.toc"), systemImage: "list.bullet")
                        .font(.body.weight(.medium))
                        .padding(.horizontal, 2)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .nigateHelp(L10n.t("help.toggleToc"))

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    TextField(L10n.t("help.searchPlaceholder"), text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .onChange(of: searchText) { _, _ in
                            selectedMatch = 0
                        }

                    if searchMatches.isEmpty {
                        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(L10n.t("help.searchNoResult"))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(L10n.t("help.searchCount", [
                            "current": "\(selectedMatch + 1)",
                            "total": "\(searchMatches.count)"
                        ]))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)

                        Button {
                            selectedMatch = (selectedMatch - 1 + searchMatches.count) % searchMatches.count
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.body)
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.plain)
                        .nigateHelp(L10n.t("help.searchPrev"))
                        .accessibilityLabel(L10n.t("help.searchPrev"))

                        Button {
                            selectedMatch = (selectedMatch + 1) % searchMatches.count
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.body)
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.plain)
                        .nigateHelp(L10n.t("help.searchNext"))
                        .accessibilityLabel(L10n.t("help.searchNext"))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: 560)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12))
                )

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            Divider()

            HStack(spacing: 0) {
                if isContentsVisible {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.t("help.toc"))
                                .font(.title3.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)

                            ForEach(outline) { node in
                                HelpOutlineRow(node: node) { blockID in
                                    requestedHeadingID = blockID
                                    navigationRequest = UUID()
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(width: 252)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
                    Divider()
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        HelpMarkdownView(blocks: blocks, activeSearchBlockID: activeMatch)
                    }
                    .onChange(of: navigationRequest) { _, _ in
                        guard let requestedHeadingID else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(HelpScrollTarget.block(requestedHeadingID), anchor: .top)
                        }
                    }
                    .onChange(of: activeMatch) { _, blockID in
                        guard let blockID else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(HelpScrollTarget.block(blockID), anchor: .center)
                        }
                    }
                }
            }
        }
    }
}

private struct HelpOutlineRow: View {
    let node: HelpOutlineNode
    var depth: Int = 0
    let onSelect: (Int) -> Void

    @State private var isExpanded: Bool

    init(node: HelpOutlineNode, depth: Int = 0, onSelect: @escaping (Int) -> Void) {
        self.node = node
        self.depth = depth
        self.onSelect = onSelect
        _isExpanded = State(initialValue: Self.expandsByDefault(node, depth: depth))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 2) {
                if node.children.isEmpty {
                    Color.clear
                        .frame(width: 16, height: 18)
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .frame(width: 16, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isExpanded ? L10n.t("help.tocCollapse") : L10n.t("help.tocExpand"))
                }

                Button {
                    onSelect(node.heading.blockID)
                } label: {
                    Text(node.heading.title)
                        .font(depth == 0 ? .body.weight(.medium) : .body)
                        .foregroundStyle(depth == 0 ? Color.primary : Color.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
            .padding(.leading, CGFloat(depth) * 12 + 8)
            .padding(.trailing, 8)

            if isExpanded {
                ForEach(node.children) { child in
                    HelpOutlineRow(node: child, depth: depth + 1, onSelect: onSelect)
                }
            }
        }
    }

    private static func expandsByDefault(_ node: HelpOutlineNode, depth: Int) -> Bool {
        depth == 0 && !node.children.isEmpty && node.children.allSatisfy(\.children.isEmpty)
    }
}

struct AboutSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    private static let appIcon: NSImage? = {
        guard let url = Bundle.module.url(forResource: "AppIcon", withExtension: "icns") else { return nil }
        return NSImage(contentsOf: url)
    }()

    private static let authorAvatar: NSImage? = loadAuthorAvatar()
    private static let technologies = "SwiftUI · DiskArbitration · macFUSE · ntfs-3g"

    private static func loadAuthorAvatar() -> NSImage? {
        guard let url = Bundle.module.url(forResource: "avatar", withExtension: "svg") else { return nil }
        let pixelSize = 176
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            return NSImage(cgImage: cgImage, size: NSSize(width: 88, height: 88))
        }
        return NSImage(contentsOf: url)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                if let appIcon = Self.appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                        .accessibilityLabel("Nigate")
                } else {
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .font(.title)
                        .foregroundStyle(Palette.accent)
                }
                VStack(alignment: .leading) {
                    Text(L10n.t("about.title")).font(.title2.weight(.semibold))
                    Text("Nigate \(appVersion)").foregroundStyle(.secondary)
                }
            }
            Text(L10n.t("about.description"))
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.t("about.softwareInfo")).font(.headline)
                        Text("\(L10n.t("about.author")) hoochanlon(胡成龙)")
                        Text("\(L10n.t("about.version")) \(appVersion)")
                        Text("\(L10n.t("about.requirement")) macOS 14+")
                    }
                    Spacer(minLength: 8)
                    if let authorAvatar = Self.authorAvatar {
                        Image(nsImage: authorAvatar)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 88, height: 88)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))
                            .accessibilityLabel("hoochanlon")
                    }
                }
                technologyLine
            }
            VStack(alignment: .leading, spacing: 10) {
                aboutLink(
                    destination: URL(string: githubRepo)!,
                    accessibilityLabel: L10n.t("about.projectLink")
                ) {
                    GitHubMark()
                        .frame(width: 16, height: 16)
                    Text(githubRepo)
                        .textSelection(.enabled)
                }
                aboutLink(
                    destination: URL(string: "mailto:\(authorEmail)")!,
                    accessibilityLabel: L10n.t("about.email")
                ) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 13))
                        .frame(width: 16, height: 16)
                    Text(authorEmail)
                        .textSelection(.enabled)
                }
            }
            .font(.body)
            .foregroundStyle(Palette.accent)
            HStack {
                Button(L10n.t("about.checkUpdates")) {
                    Task { await model.checkUpdates() }
                }
                Spacer()
                Button(L10n.t("about.ok")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    /// 一行能放下就保持「标签 + 技术栈」；否则整串技术名换到下一行，避免最后一项孤行。
    private var technologyLine: some View {
        let label = L10n.t("about.technology")
        return ViewThatFits(in: .horizontal) {
            Text("\(label) \(Self.technologies)")
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                Text(Self.technologies)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(Self.technologies)")
    }

    private func aboutLink<Content: View>(
        destination: URL,
        accessibilityLabel: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Link(destination: destination) {
            HStack(alignment: .center, spacing: 8) {
                content()
            }
            .contentShape(Rectangle())
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

/// 仓库入口图标：圆底 + 代码括号（SF 无官方 GitHub logo）。
private struct GitHubMark: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Palette.accent)
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
        }
        .accessibilityHidden(true)
    }
}

struct SupportAuthorSheet: View {
    @Environment(\.dismiss) private var dismiss

    private static let qrMaxPixel = 720
    private static let qrSize: CGFloat = 280

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Palette.heart)
                Text(L10n.t("support.title"))
                    .font(.title2.weight(.semibold))
            }
            Text(L10n.t("support.subtitle"))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            if let image = Self.tipImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Self.qrSize, height: Self.qrSize)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.08))
                    )
                    .accessibilityLabel(L10n.t("support.title"))
            }

            HStack {
                Spacer()
                Button(L10n.t("support.ok")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 360)
    }

    private static let tipImage: NSImage? = loadTipImage()

    private static func loadTipImage() -> NSImage? {
        let url = Bundle.module.url(forResource: "zanshangma", withExtension: "jpg", subdirectory: "Support")
            ?? Bundle.module.url(forResource: "zanshangma", withExtension: "jpg")
        guard let url else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: true,
            kCGImageSourceThumbnailMaxPixelSize: qrMaxPixel,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            let scale: CGFloat = 2
            return NSImage(
                cgImage: cgImage,
                size: NSSize(
                    width: CGFloat(cgImage.width) / scale,
                    height: CGFloat(cgImage.height) / scale
                )
            )
        }
        return NSImage(contentsOf: url)
    }
}

struct PasswordSheet: View {
    @EnvironmentObject private var model: AppModel
    let state: PasswordSheetState
    @State private var password = ""
    @State private var visible = false
    @State private var save: Bool

    init(state: PasswordSheetState) {
        self.state = state
        _save = State(initialValue: state.savePassword)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(state.title).font(.headline)
            Text(L10n.t("messages.passwordDialog.prompt")).foregroundStyle(.secondary)
            HStack {
                Group {
                    if visible {
                        TextField(L10n.t("messages.passwordDialog.prompt"), text: $password)
                    } else {
                        SecureField(L10n.t("messages.passwordDialog.prompt"), text: $password)
                    }
                }
                .textFieldStyle(.roundedBorder)
                Button(visible ? L10n.t("messages.passwordDialog.hidePassword") : L10n.t("messages.passwordDialog.showPassword")) {
                    visible.toggle()
                }
            }
            Toggle(L10n.t("messages.passwordDialog.savePassword"), isOn: $save)
            HStack {
                Spacer()
                Button(L10n.t("messages.passwordDialog.cancel")) { model.cancelPassword() }
                    .disabled(model.passwordValidationInProgress)
                Button(L10n.t("messages.passwordDialog.confirm")) {
                    model.submitPassword(password, save: save)
                }
                .disabled(model.passwordValidationInProgress)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
