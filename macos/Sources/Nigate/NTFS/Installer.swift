import Foundation
import AppKit

/// 一键安装只走已有的 Homebrew。CLT / brew 不在包里，停下来告诉用户去依赖列表装。
struct InstallerCopy: Equatable {
    var title: String
    var scope: String
    var excluded: String
    var next: String
    var macosTooOld: String
    var missingCLT: String
    var missingBrew: String
    var fusePresent: String
    var installingFuse: String
    var installingNtfs: String
    var installingFswatch: String
    var done: String
    var pressEnter: String

    static func resolve(_ language: AppLanguage) -> InstallerCopy {
        switch language {
        case .zhCN: return .zhCN
        case .zhTW: return .zhTW
        case .ja: return .ja
        case .de: return .de
        case .en: return .en
        case .system:
            let code = Locale.current.language.languageCode?.identifier ?? "en"
            let region = Locale.current.region?.identifier
            if code == "zh" {
                return (region == "TW" || region == "HK" || region == "MO") ? .zhTW : .zhCN
            }
            if code == "ja" { return .ja }
            if code == "de" { return .de }
            return .en
        }
    }

    static let zhCN = InstallerCopy(
        title: "Nigate 依赖安装",
        scope: "本脚本通过已有的 Homebrew 安装：MacFUSE、ntfs-3g、fswatch。",
        excluded: "不会安装：Xcode Command Line Tools、Homebrew。",
        next: "缺这两项时会停在这里。请回到应用「系统依赖」，展开对应条目，复制命令装好后再点「安装 MacFUSE + ntfs-3g」。过程中可能要输入密码，并批准 MacFUSE 扩展。",
        macosTooOld: "需要 macOS 14 或更高版本。",
        missingCLT: "未检测到 Xcode Command Line Tools。本脚本不能代装，请先运行：\n  xcode-select --install\n按系统窗口完成后再点「安装 MacFUSE + ntfs-3g」。",
        missingBrew: "未找到 Homebrew。本脚本不能代装。请到「系统依赖」展开 Homebrew，按命令安装后再点「安装 MacFUSE + ntfs-3g」。\n  https://brew.sh",
        fusePresent: "已检测到 MacFUSE，跳过安装。",
        installingFuse: "正在安装 MacFUSE…",
        installingNtfs: "正在安装 ntfs-3g…",
        installingFswatch: "正在安装 fswatch（可选）…",
        done: "完成。若 macOS 询问，请在系统设置中批准 MacFUSE 扩展，然后回到应用点「检查依赖」。",
        pressEnter: "按 Enter 关闭…"
    )

    static let zhTW = InstallerCopy(
        title: "Nigate 依賴安裝",
        scope: "本指令碼透過既有的 Homebrew 安裝：MacFUSE、ntfs-3g、fswatch。",
        excluded: "不會安裝：Xcode Command Line Tools、Homebrew。",
        next: "缺少這兩項時會停在這裡。請回到應用程式「系統依賴」，展開對應項目，複製命令裝好後再點「安裝 MacFUSE + ntfs-3g」。過程中可能要輸入密碼，並核准 MacFUSE 延伸功能。",
        macosTooOld: "需要 macOS 14 或更高版本。",
        missingCLT: "未偵測到 Xcode Command Line Tools。本指令碼不能代裝，請先執行：\n  xcode-select --install\n依系統視窗完成後再點「安裝 MacFUSE + ntfs-3g」。",
        missingBrew: "找不到 Homebrew。本指令碼不能代裝。請到「系統依賴」展開 Homebrew，按命令安裝後再點「安裝 MacFUSE + ntfs-3g」。\n  https://brew.sh",
        fusePresent: "已偵測到 MacFUSE，略過安裝。",
        installingFuse: "正在安裝 MacFUSE…",
        installingNtfs: "正在安裝 ntfs-3g…",
        installingFswatch: "正在安裝 fswatch（選用）…",
        done: "完成。若 macOS 詢問，請在系統設定中核准 MacFUSE 延伸功能，然後回到應用程式點「檢查依賴」。",
        pressEnter: "按 Enter 關閉…"
    )

    static let en = InstallerCopy(
        title: "Nigate dependency installer",
        scope: "This script installs MacFUSE, ntfs-3g, and fswatch through Homebrew you already have.",
        excluded: "It does not install Xcode Command Line Tools or Homebrew.",
        next: "If either is missing, the script stops. Expand that row on the Dependencies tab, run its command, then use Install MacFUSE + ntfs-3g again. You may be asked for a password and to approve the MacFUSE extension.",
        macosTooOld: "macOS 14 or later is required.",
        missingCLT: "Xcode Command Line Tools were not found. This script cannot install them. Run:\n  xcode-select --install\nFinish the system window, then use Install MacFUSE + ntfs-3g again.",
        missingBrew: "Homebrew was not found. This script cannot install it. Expand Homebrew on the Dependencies tab, install it, then use Install MacFUSE + ntfs-3g again.\n  https://brew.sh",
        fusePresent: "MacFUSE is already present. Skipping install.",
        installingFuse: "Installing MacFUSE…",
        installingNtfs: "Installing ntfs-3g…",
        installingFswatch: "Installing fswatch (optional)…",
        done: "Done. If macOS asks, approve the MacFUSE extension in System Settings, then tap Check Dependencies in the app.",
        pressEnter: "Press Enter to close…"
    )

    static let ja = InstallerCopy(
        title: "Nigate 依存関係インストーラー",
        scope: "このスクリプトは、既に入っている Homebrew で MacFUSE、ntfs-3g、fswatch を入れます。",
        excluded: "Xcode Command Line Tools と Homebrew はインストールしません。",
        next: "どちらかが無い場合はここで止まります。依存関係タブで該当行を開き、コマンドを実行してから、もう一度「MacFUSE + ntfs-3g を入れる」を実行してください。パスワード入力と MacFUSE 拡張の承認を求められることがあります。",
        macosTooOld: "macOS 14 以降が必要です。",
        missingCLT: "Xcode Command Line Tools が見つかりません。このスクリプトでは入れられません。先に実行してください：\n  xcode-select --install\nシステムの窓で完了してから、「MacFUSE + ntfs-3g を入れる」をやり直してください。",
        missingBrew: "Homebrew が見つかりません。このスクリプトでは入れられません。依存関係タブで Homebrew を開き、案内のコマンドで入れてからやり直してください。\n  https://brew.sh",
        fusePresent: "MacFUSE は既にあります。インストールをスキップします。",
        installingFuse: "MacFUSE をインストールしています…",
        installingNtfs: "ntfs-3g をインストールしています…",
        installingFswatch: "fswatch をインストールしています（任意）…",
        done: "完了しました。macOS が尋ねたら、システム設定で MacFUSE 拡張を承認し、アプリで「依存関係を確認」してください。",
        pressEnter: "Enter で閉じます…"
    )

    static let de = InstallerCopy(
        title: "Nigate-Abhängigkeiten",
        scope: "Dieses Skript installiert MacFUSE, ntfs-3g und fswatch über das bereits vorhandene Homebrew.",
        excluded: "Xcode Command Line Tools und Homebrew werden nicht installiert.",
        next: "Fehlt eines von beiden, hält das Skript an. Klappen Sie den Eintrag unter Abhängigkeiten auf, führen Sie den Befehl aus, und starten Sie „MacFUSE + ntfs-3g installieren“ erneut. Passwort und Freigabe der MacFUSE-Erweiterung können verlangt werden.",
        macosTooOld: "macOS 14 oder neuer ist erforderlich.",
        missingCLT: "Xcode Command Line Tools wurden nicht gefunden. Dieses Skript kann sie nicht installieren. Zuerst ausführen:\n  xcode-select --install\nDanach das Systemfenster abschließen und „MacFUSE + ntfs-3g installieren“ erneut starten.",
        missingBrew: "Homebrew wurde nicht gefunden. Dieses Skript kann es nicht installieren. Klappen Sie Homebrew unter Abhängigkeiten auf, installieren Sie es, und starten Sie danach erneut.\n  https://brew.sh",
        fusePresent: "MacFUSE ist bereits vorhanden. Installation wird übersprungen.",
        installingFuse: "MacFUSE wird installiert…",
        installingNtfs: "ntfs-3g wird installiert…",
        installingFswatch: "fswatch wird installiert (optional)…",
        done: "Fertig. Falls macOS nachfragt, geben Sie die MacFUSE-Erweiterung in den Systemeinstellungen frei und prüfen Sie die Abhängigkeiten in der App erneut.",
        pressEnter: "Eingabetaste zum Schließen…"
    )
}

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
        let copy = InstallerCopy.resolve(language)
        return """
        #!/bin/bash
        set -u
        export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin"
        trap 'rm -f "$0"' EXIT
        echo "------------------------------------------"
        echo "\(copy.title)"
        echo "------------------------------------------"
        echo "\(copy.scope)"
        echo "\(copy.excluded)"
        echo "\(copy.next)"
        echo
        if [[ "$(/usr/bin/sw_vers -productVersion 2>/dev/null)" < "14.0" ]]; then
          echo "\(copy.macosTooOld)"
          echo "\(copy.pressEnter)"
          read -r
          exit 1
        fi
        NEED_STOP=0
        if ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
          echo "\(copy.missingCLT)"
          NEED_STOP=1
        fi
        BREW=""
        for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
          if [[ -x "$candidate" ]]; then BREW="$candidate"; break; fi
        done
        if [[ -z "$BREW" ]]; then
          echo "\(copy.missingBrew)"
          NEED_STOP=1
        fi
        if [[ "$NEED_STOP" -ne 0 ]]; then
          echo "\(copy.pressEnter)"
          read -r
          exit 1
        fi
        FUSE_LIB="/usr/local/lib/libfuse.2.dylib"
        FUSE_FS="/Library/Filesystems/macfuse.fs/Contents/Resources/mount_macfuse"
        FUSE_LOAD="/Library/Filesystems/macfuse.fs/Contents/Resources/load_macfuse"
        if [[ -e "$FUSE_LIB" && ( -e "$FUSE_FS" || -e "$FUSE_LOAD" ) ]]; then
          echo "\(copy.fusePresent)"
        elif "$BREW" list --cask macfuse >/dev/null 2>&1; then
          echo "\(copy.installingFuse)"
          "$BREW" reinstall --cask macfuse || exit $?
        else
          echo "\(copy.installingFuse)"
          "$BREW" install --cask macfuse || exit $?
        fi
        echo "\(copy.installingNtfs)"
        "$BREW" tap gromgit/homebrew-fuse || exit $?
        "$BREW" install gromgit/fuse/ntfs-3g-mac || "$BREW" install ntfs-3g || exit $?
        echo "\(copy.installingFswatch)"
        "$BREW" install fswatch || true
        echo "\(copy.done)"
        echo "\(copy.pressEnter)"
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
