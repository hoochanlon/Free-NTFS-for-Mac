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

    private var headings: [HelpHeading] {
        HelpMarkdownIndex.headings(in: blocks)
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
                                .font(.headline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)

                            ForEach(headings) { heading in
                                Button {
                                    requestedHeadingID = heading.blockID
                                    navigationRequest = UUID()
                                } label: {
                                    Text(heading.title)
                                        .font(.subheadline)
                                        .lineLimit(2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, CGFloat(heading.level - 2) * 12 + 10)
                                        .padding(.trailing, 8)
                                        .padding(.vertical, 5)
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(width: 230)
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

struct AboutSheet: View {
    @EnvironmentObject private var model: AppModel

    private var appIcon: NSImage? {
        guard let url = Bundle.module.url(forResource: "AppIcon", withExtension: "icns") else { return nil }
        return NSImage(contentsOf: url)
    }

    private var authorAvatar: NSImage? {
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
                if let appIcon {
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
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.t("about.softwareInfo")).font(.headline)
                    Text("\(L10n.t("about.author")) hoochanlon(胡成龙)")
                    Text("\(L10n.t("about.version")) \(appVersion)")
                    Text("\(L10n.t("about.technology")) SwiftUI · DiskArbitration · macFUSE · ntfs-3g")
                }
                Spacer(minLength: 8)
                if let authorAvatar {
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
                Button(L10n.t("about.ok")) { model.aboutOpen = false }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
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
