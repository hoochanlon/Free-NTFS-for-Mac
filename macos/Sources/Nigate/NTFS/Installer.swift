import Foundation
import AppKit

enum Installer {
    static func openTerminal(language: AppLanguage) throws {
        let script = localDependencyScript(language: language)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("nigate-install-\(UUID().uuidString).sh")
        try script.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)

        let command = "bash \(shellQuote(url.path)); rm -f \(shellQuote(url.path))"
        let appleScript = "tell application \"Terminal\" to do script \"\(appleScriptQuote(command))\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]
        try process.run()
    }

    private static func localDependencyScript(language: AppLanguage) -> String {
        let isChinese = language == .zhCN || language == .zhTW
        let title = isChinese ? "Nigate 依赖安装" : "Nigate dependency installer"
        let missingBrew = isChinese
            ? "未找到 Homebrew。请从 https://brew.sh 手动安装后重新运行。"
            : "Homebrew was not found. Install it manually from https://brew.sh and run this again."
        return """
        #!/bin/bash
        set -u
        export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin"
        trap 'rm -f "$0"' EXIT
        echo "------------------------------------------"
        echo "\(title)"
        echo "------------------------------------------"
        if [[ "$(/usr/bin/sw_vers -productVersion 2>/dev/null)" < "14.0" ]]; then
          echo "macOS 14 or later is required."
          read -r
          exit 1
        fi
        BREW=""
        for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
          if [[ -x "$candidate" ]]; then BREW="$candidate"; break; fi
        done
        if [[ -z "$BREW" ]]; then
          echo "\(missingBrew)"
          read -r
          exit 1
        fi
        FUSE_LIB="/usr/local/lib/libfuse.2.dylib"
        FUSE_FS="/Library/Filesystems/macfuse.fs/Contents/Resources/mount_macfuse"
        FUSE_LOAD="/Library/Filesystems/macfuse.fs/Contents/Resources/load_macfuse"
        if [[ -e "$FUSE_LIB" && ( -e "$FUSE_FS" || -e "$FUSE_LOAD" ) ]]; then
          echo "macFUSE already present."
        elif "$BREW" list --cask macfuse >/dev/null 2>&1; then
          "$BREW" reinstall --cask macfuse || exit $?
        else
          "$BREW" install --cask macfuse || exit $?
        fi
        "$BREW" tap gromgit/homebrew-fuse || exit $?
        "$BREW" install gromgit/fuse/ntfs-3g-mac || "$BREW" install ntfs-3g || exit $?
        "$BREW" install fswatch || true
        echo "Done. Approve the macFUSE extension in System Settings if macOS asks."
        echo "Press Enter to close..."
        read -r
        """
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptQuote(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
