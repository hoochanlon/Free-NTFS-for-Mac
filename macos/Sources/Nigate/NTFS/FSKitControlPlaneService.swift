import Foundation
import NigateFSKitCore

#if canImport(FSKit)
import FSKit
#endif

/// 主应用侧 FSKit 控制面探测。
///
/// 证据优先级：
/// 1. FSClient.installedExtensions（能看到本模块时，以 isEnabled 为准）
/// 2. pluginkit 选举态（+ use / - ignore / 空格 default）
///
/// 注意：未持有有效 Developer ID + fskit.mount 时，FSClient 可能只返回 Apple 模块；
/// 此时仍以 pluginkit 作为安装/选举证据，避免把已注册扩展误判为“未安装”。
enum FSKitControlPlaneService {
    static func probe() async -> NigateFSKitControlPlaneState {
        let version = NigateSystemVersion(ProcessInfo.processInfo.operatingSystemVersion)
        guard NigateFSKit.isSupported(version) else {
            return .unsupportedSystem(version)
        }

        let plugin = await PluginKitProbe.lookup(moduleIdentifier: NigateFSKit.moduleIdentifier)
        let client = await FSClientProbe.lookup(moduleIdentifier: NigateFSKit.moduleIdentifier)

        if let client {
            let enabled = client.isEnabled && plugin?.election != .ignore
            return NigateFSKitControlPlaneState(
                systemSupported: true,
                dataPlaneImplemented: NigateFSKit.isDataPlaneImplemented,
                extensionInstalled: true,
                extensionEnabled: enabled,
                moduleURL: client.url?.absoluteString ?? plugin?.url,
                election: plugin?.election ?? (client.isEnabled ? .use : .ignore),
                source: plugin == nil ? .fsClient : .combined,
                detail: enabled ? nil : "extension installed but disabled"
            )
        }

        if let plugin {
            let enabled = plugin.election != .ignore
            return NigateFSKitControlPlaneState(
                systemSupported: true,
                dataPlaneImplemented: NigateFSKit.isDataPlaneImplemented,
                extensionInstalled: true,
                extensionEnabled: enabled,
                moduleURL: plugin.url,
                election: plugin.election,
                source: .pluginKit,
                detail: enabled
                    ? "detected via pluginkit; enable in System Settings > File System Extensions if mount fails"
                    : "extension election is ignore"
            )
        }

        return NigateFSKitControlPlaneState(
            systemSupported: true,
            dataPlaneImplemented: NigateFSKit.isDataPlaneImplemented,
            extensionInstalled: false,
            extensionEnabled: false,
            source: .none,
            detail: "Nigate FSKit extension not registered; rebuild/install app bundle"
        )
    }
}

private struct PluginKitMatch: Sendable {
    var election: NigateFSKitExtensionElection
    var url: String?
}

private enum PluginKitProbe {
    static func lookup(moduleIdentifier: String) async -> PluginKitMatch? {
        await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
            process.arguments = [
                "-m",
                "-v",
                "-p", "com.apple.fskit.fsmodule",
                "-i", moduleIdentifier
            ]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                return nil
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
                return nil
            }
            return parse(text, moduleIdentifier: moduleIdentifier)
        }.value
    }

    static func parse(_ text: String, moduleIdentifier: String) -> PluginKitMatch? {
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            guard line.contains(moduleIdentifier) else { continue }
            let election: NigateFSKitExtensionElection
            if line.hasPrefix("+") {
                election = .use
            } else if line.hasPrefix("-") {
                election = .ignore
            } else if line.hasPrefix("!") {
                election = .debugger
            } else if line.hasPrefix("=") {
                election = .superseded
            } else if line.hasPrefix("?") {
                election = .unknown
            } else {
                election = .defaulted
            }
            let url = line
                .split(separator: "\t")
                .map(String.init)
                .first(where: { $0.hasPrefix("/") })
            return PluginKitMatch(election: election, url: url)
        }
        return nil
    }
}

private struct FSClientMatch: Sendable {
    var isEnabled: Bool
    var url: URL?
}

private enum FSClientProbe {
    static func lookup(moduleIdentifier: String) async -> FSClientMatch? {
        if #available(macOS 15.4, *) {
            #if canImport(FSKit)
            do {
                let modules = try await FSClient.shared.installedExtensions
                guard let match = modules.first(where: { $0.bundleIdentifier == moduleIdentifier }) else {
                    return nil
                }
                return FSClientMatch(isEnabled: match.isEnabled, url: match.url)
            } catch {
                return nil
            }
            #else
            return nil
            #endif
        }
        return nil
    }
}
