import SwiftUI
import AppKit

struct DependenciesPane: View {
    @EnvironmentObject private var model: AppModel
    @State private var expandedDependencies: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.t("dependencies.title")).font(.title2.weight(.semibold))
                Spacer()
                Button {
                    Task { @MainActor in
                        do {
                            let result = try await Shell.run("/usr/bin/open", [
                                "x-apple.systempreferences:com.apple.ExtensionsPreferences?extensionPointIdentifier=com.apple.fskit.fsmodule"
                            ])
                            if !result.ok {
                                model.alert = AppAlert(
                                    title: L10n.t("dialog.error"),
                                    message: result.text,
                                    kind: .error
                                )
                            }
                        } catch {
                            model.alert = AppAlert(
                                title: L10n.t("dialog.error"),
                                message: error.localizedDescription,
                                kind: .error
                            )
                        }
                    }
                } label: {
                    Label(L10n.t("dependencies.openFileSystemExtensions"), systemImage: "macwindow")
                }
                Button {
                    model.openInstaller()
                } label: {
                    Label(L10n.t("dependencies.autoInstall"), systemImage: "terminal")
                }
                Button {
                    Task { await model.refreshDependencies() }
                } label: {
                    Label(L10n.t("dependencies.checkButton"), systemImage: "arrow.clockwise")
                }
            }
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(dependencyItems.indices, id: \.self) { index in
                        dependencyRow(index: index + 1, item: dependencyItems[index])
                    }
                }
                .padding(.horizontal, 18)
            }
            .padding(.horizontal, -18)
        }
        .padding(18)
    }

    private var dependencyItems: [DependencyItem] {
        [
            DependencyItem(
                id: "macos-version",
                icon: "apple.logo",
                name: L10n.t("dependencies.macosVersion.name", ["version": model.dependencies.macosVersionString]),
                status: model.dependencies.macosVersion ? L10n.t("dependencies.versionSatisfied") : L10n.t("dependencies.versionUnsatisfied"),
                isSatisfied: model.dependencies.macosVersion,
                description: L10n.t("dependencies.macosVersion.description"),
                guide: L10n.t("dependencies.macosVersion.installGuide")
            ),
            DependencyItem(
                id: "swift-tools",
                icon: "hammer",
                name: L10n.t("dependencies.swift.name"),
                status: model.dependencies.swift ? L10n.t("dependencies.installed") : L10n.t("dependencies.missing"),
                isSatisfied: model.dependencies.swift,
                description: L10n.t("dependencies.swift.description"),
                guide: L10n.t("dependencies.swift.installGuide"),
                command: "xcode-select --install"
            ),
            DependencyItem(
                id: "homebrew",
                icon: "shippingbox",
                name: L10n.t("dependencies.brew.name"),
                status: model.dependencies.brew ? L10n.t("dependencies.installed") : L10n.t("dependencies.missing"),
                isSatisfied: model.dependencies.brew,
                description: L10n.t("dependencies.brew.description"),
                guide: L10n.t("dependencies.brew.installGuide"),
                command: "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"",
                mirrorCommand: "/bin/zsh -c \"$(curl -fsSL https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh)\""
            ),
            DependencyItem(
                id: "macfuse",
                icon: "externaldrive.connected.to.line.below",
                name: L10n.t("dependencies.macfuse.name"),
                status: model.dependencies.macfuse ? L10n.t("dependencies.installed") : L10n.t("dependencies.missing"),
                isSatisfied: model.dependencies.macfuse,
                description: L10n.t("dependencies.macfuse.description"),
                guide: L10n.t("dependencies.macfuse.installGuide"),
                command: "if brew list --cask macfuse >/dev/null 2>&1; then brew reinstall --cask macfuse; else brew install --cask macfuse; fi",
                instructions: [
                    .callout(
                        id: "apple-silicon-security",
                        text: L10n.t("dependencies.macfuse.appleSiliconSecurity")
                    ),
                    .paragraph(
                        id: "macos-upgrade-error",
                        text: L10n.t("dependencies.macfuse.upgradeError")
                    ),
                    .paragraph(
                        id: "macos-upgrade-security-notice",
                        text: L10n.t("dependencies.macfuse.upgradeSecurityNotice")
                    ),
                    .command(
                        id: "macos-upgrade-security-command",
                        label: L10n.t("dependencies.macfuse.upgradeSecurityLabel"),
                        command: "sudo spctl --master-disable"
                    ),
                    .paragraph(
                        id: "macos-upgrade-command-intro",
                        text: L10n.t("dependencies.macfuse.upgradeCommandIntro")
                    ),
                    .command(
                        id: "macos-upgrade-command",
                        label: L10n.t("dependencies.macfuse.upgradeCommandLabel"),
                        command: "brew upgrade --cask --greedy macfuse"
                    ),
                    .paragraph(
                        id: "macos-upgrade-approval",
                        text: L10n.t("dependencies.macfuse.upgradeApproval")
                    ),
                    .command(
                        id: "macos-upgrade-restore-security-command",
                        label: L10n.t("dependencies.macfuse.upgradeRestoreLabel"),
                        command: "sudo spctl --master-enable"
                    )
                ]
            ),
            DependencyItem(
                id: "ntfs3g",
                icon: "externaldrive.fill.badge.plus",
                name: L10n.t("dependencies.ntfs3g.name"),
                status: model.dependencies.ntfs3g ? L10n.t("dependencies.installed") : L10n.t("dependencies.missing"),
                isSatisfied: model.dependencies.ntfs3g,
                description: L10n.t("dependencies.ntfs3g.description"),
                guide: L10n.t("dependencies.ntfs3g.installGuide"),
                command: "brew tap gromgit/homebrew-fuse && brew install ntfs-3g-mac",
                note: L10n.t("dependencies.ntfs3g.installGuideTip")
            ),
            DependencyItem(
                id: "fswatch",
                icon: "waveform.path.ecg",
                name: L10n.t("dependencies.fswatch.name"),
                status: model.dependencies.fswatch ? L10n.t("dependencies.installedOptional") : L10n.t("dependencies.missingOptional"),
                isSatisfied: model.dependencies.fswatch,
                description: L10n.t("dependencies.fswatch.description"),
                guide: L10n.t("dependencies.fswatch.installGuide"),
                command: "brew install fswatch",
                optional: true
            ),
            DependencyItem(
                id: "fsKit",
                icon: "externaldrive.badge.timemachine",
                name: L10n.t("dependencies.fsKit.name"),
                status: fsKitStatusText,
                isSatisfied: model.dependencies.fsKitControlPlaneAvailable,
                description: L10n.t("dependencies.fsKit.description"),
                guide: fsKitGuideText,
                optional: true
            )
        ]
    }

    private var fsKitStatusText: String {
        let d = model.dependencies
        if d.fsKitControlPlaneAvailable {
            return L10n.t("dependencies.fsKit.statusReady")
        }
        if !d.fsKitSupported {
            return L10n.t("dependencies.unsupported")
        }
        if !d.fsKitExtensionInstalled {
            return L10n.t("dependencies.fsKit.statusNotInstalled")
        }
        if !d.fsKitExtensionEnabled {
            return L10n.t("dependencies.fsKit.statusDisabled")
        }
        return L10n.t("dependencies.fsKit.statusUnavailable")
    }

    private var fsKitGuideText: String {
        var guide = L10n.t("dependencies.fsKit.installGuide")
        if let diagnostic = model.dependencies.fsKitDiagnostic {
            guide += "\n\n" + L10n.fsKitDiagnosticText(diagnostic)
        }
        return guide
    }

    private func dependencyRow(index: Int, item: DependencyItem) -> some View {
        let isExpanded = expandedDependencies.contains(item.id)

        return VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    if isExpanded {
                        expandedDependencies.remove(item.id)
                    } else {
                        expandedDependencies.insert(item.id)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Text(String(index))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(item.statusColor)
                        .frame(width: 22, height: 22)
                        .background(item.statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    Image(systemName: item.icon)
                        .foregroundStyle(.secondary)
                    Text(item.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    statusBadge(item)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.07)))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name).font(.headline)
                        Text(item.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    if let command = item.command {
                        commandCard(command, label: L10n.t("dependencies.installCommandLabel"))
                    }
                    guideCallout(item.guide)
                    if let mirrorCommand = item.mirrorCommand {
                        commandCard(
                            mirrorCommand,
                            label: L10n.t("dependencies.brew.installGuideMirrorCommandLabel")
                        )
                    }
                    ForEach(item.instructions) { instruction in
                        switch instruction {
                        case let .callout(_, text):
                            guideCallout(text)
                        case let .paragraph(_, text):
                            Text(text)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        case let .command(_, label, command):
                            commandCard(command, label: label)
                        }
                    }

                    if let note = item.note {
                        guideCallout(note)
                    }
                }
                .padding(14)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Color.primary.opacity(0.07)))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .transition(.asymmetric(insertion: .opacity, removal: .identity))
            }
        }
    }

    private func statusBadge(_ item: DependencyItem) -> some View {
        HStack(spacing: 5) {
            Image(systemName: item.isSatisfied ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
            Text(item.status)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(item.statusColor)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(item.statusColor.opacity(0.12), in: Capsule())
    }

    private func commandCard(_ command: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Text(command)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                CopyCommandButton(command: command)
            }
            .padding(10)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.primary.opacity(0.08)))
        }
    }

    private func guideCallout(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Palette.accent)
                .frame(width: 3)
            Text(text)
                // 安装步骤/说明是主阅读内容，caption 过小；与描述同级 body。
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
    }
}

private enum DependencyInstruction: Identifiable {
    case callout(id: String, text: String)
    case paragraph(id: String, text: String)
    case command(id: String, label: String, command: String)

    var id: String {
        switch self {
        case let .callout(id, _), let .paragraph(id, _), let .command(id, _, _):
            return id
        }
    }
}

private struct DependencyItem: Identifiable {
    let id: String
    let icon: String
    let name: String
    let status: String
    let isSatisfied: Bool
    let description: String
    let guide: String
    var command: String? = nil
    var mirrorCommand: String? = nil
    var instructions: [DependencyInstruction] = []
    var optional = false
    var note: String? = nil

    var statusColor: Color {
        if isSatisfied { return Palette.success }
        return optional ? Palette.warning : Palette.error
    }
}
