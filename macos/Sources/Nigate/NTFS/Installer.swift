import Foundation
import AppKit

/// 一键安装按顺序补齐缺失项：CLT → Homebrew → MacFUSE → ntfs-3g → fswatch。
/// 已装的跳过。CLT 会弹出系统窗口；Homebrew 可能要密码；MacFUSE 要批准扩展。
/// 不关 Gatekeeper。
struct InstallerCopy: Equatable {
    var title: String
    var scope: String
    var next: String
    var macosTooOld: String
    var cltPresent: String
    var installingCLT: String
    var waitingCLT: String
    var cltTimeout: String
    var brewPresent: String
    var installingBrew: String
    var brewOfficial: String
    var brewMirror: String
    var brewFailed: String
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
        scope: "将按顺序安装缺失项：Xcode Command Line Tools、Homebrew、MacFUSE、ntfs-3g、fswatch。已安装的会跳过。",
        next: "过程中会弹出系统安装窗口，可能要输入密码，并批准 MacFUSE 扩展。不要关闭本终端。",
        macosTooOld: "需要 macOS 14 或更高版本。",
        cltPresent: "已检测到 Xcode Command Line Tools，跳过。",
        installingCLT: "正在安装 Xcode Command Line Tools…",
        waitingCLT: "请在系统窗口中点「安装」，完成后脚本会自动继续。",
        cltTimeout: "等待 Xcode Command Line Tools 超时。若已取消系统窗口，关闭终端后重新点「一键安装依赖」。",
        brewPresent: "已检测到 Homebrew，跳过。",
        installingBrew: "正在安装 Homebrew…",
        brewOfficial: "使用 Homebrew 官方安装脚本。",
        brewMirror: "官方源不可用，改用镜像安装 Homebrew…",
        brewFailed: "Homebrew 安装失败。请检查网络，或展开依赖列表中的 Homebrew 条目手动安装。",
        fusePresent: "已检测到 MacFUSE，跳过安装。",
        installingFuse: "正在安装 MacFUSE…",
        installingNtfs: "正在安装 ntfs-3g…",
        installingFswatch: "正在安装 fswatch（可选）…",
        done: "完成。若 macOS 询问，请在系统设置中批准 MacFUSE 扩展，然后回到应用点「检查依赖」。",
        pressEnter: "按 Enter 关闭…"
    )

    static let zhTW = InstallerCopy(
        title: "Nigate 依賴安裝",
        scope: "將依序安裝缺少的項目：Xcode Command Line Tools、Homebrew、MacFUSE、ntfs-3g、fswatch。已安裝的會跳過。",
        next: "過程中會跳出系統安裝視窗，可能要輸入密碼，並核准 MacFUSE 延伸功能。請勿關閉本終端。",
        macosTooOld: "需要 macOS 14 或更高版本。",
        cltPresent: "已偵測到 Xcode Command Line Tools，略過。",
        installingCLT: "正在安裝 Xcode Command Line Tools…",
        waitingCLT: "請在系統視窗中點「安裝」，完成後指令碼會自動繼續。",
        cltTimeout: "等待 Xcode Command Line Tools 逾時。若已取消系統視窗，關閉終端後重新點「一鍵安裝依賴」。",
        brewPresent: "已偵測到 Homebrew，略過。",
        installingBrew: "正在安裝 Homebrew…",
        brewOfficial: "使用 Homebrew 官方安裝指令碼。",
        brewMirror: "官方源不可用，改用鏡像安裝 Homebrew…",
        brewFailed: "Homebrew 安裝失敗。請檢查網路，或展開依賴列表中的 Homebrew 項目手動安裝。",
        fusePresent: "已偵測到 MacFUSE，略過安裝。",
        installingFuse: "正在安裝 MacFUSE…",
        installingNtfs: "正在安裝 ntfs-3g…",
        installingFswatch: "正在安裝 fswatch（選用）…",
        done: "完成。若 macOS 詢問，請在系統設定中核准 MacFUSE 延伸功能，然後回到應用程式點「檢查依賴」。",
        pressEnter: "按 Enter 關閉…"
    )

    static let en = InstallerCopy(
        title: "Nigate dependency installer",
        scope: "Missing items are installed in order: Xcode Command Line Tools, Homebrew, MacFUSE, ntfs-3g, and fswatch. Anything already present is skipped.",
        next: "macOS may show an installer window, ask for your password, and request approval of the MacFUSE extension. Leave this terminal open.",
        macosTooOld: "macOS 14 or later is required.",
        cltPresent: "Xcode Command Line Tools are already present. Skipping.",
        installingCLT: "Installing Xcode Command Line Tools…",
        waitingCLT: "In the system window, choose Install. This script continues when that finishes.",
        cltTimeout: "Timed out waiting for Xcode Command Line Tools. If you cancelled the system window, close this terminal and use Install All Dependencies again.",
        brewPresent: "Homebrew is already present. Skipping.",
        installingBrew: "Installing Homebrew…",
        brewOfficial: "Using the official Homebrew install script.",
        brewMirror: "Official source unavailable. Installing Homebrew from a mirror…",
        brewFailed: "Homebrew installation failed. Check the network, or expand Homebrew on the Dependencies tab and install it manually.",
        fusePresent: "MacFUSE is already present. Skipping install.",
        installingFuse: "Installing MacFUSE…",
        installingNtfs: "Installing ntfs-3g…",
        installingFswatch: "Installing fswatch (optional)…",
        done: "Done. If macOS asks, approve the MacFUSE extension in System Settings, then tap Check Dependencies in the app.",
        pressEnter: "Press Enter to close…"
    )

    static let ja = InstallerCopy(
        title: "Nigate 依存関係インストーラー",
        scope: "未導入の項目を順に入れます：Xcode Command Line Tools、Homebrew、MacFUSE、ntfs-3g、fswatch。既にあるものはスキップします。",
        next: "システムのインストール窓、パスワード入力、MacFUSE 拡張の承認が出ることがあります。このターミナルは閉じないでください。",
        macosTooOld: "macOS 14 以降が必要です。",
        cltPresent: "Xcode Command Line Tools は既にあります。スキップします。",
        installingCLT: "Xcode Command Line Tools をインストールしています…",
        waitingCLT: "システム窓で「インストール」を選んでください。完了するとこのスクリプトが続きます。",
        cltTimeout: "Xcode Command Line Tools の待ち時間が切れました。システム窓をキャンセルした場合は、ターミナルを閉じて「すべてインストール」をやり直してください。",
        brewPresent: "Homebrew は既にあります。スキップします。",
        installingBrew: "Homebrew をインストールしています…",
        brewOfficial: "Homebrew 公式のインストールスクリプトを使います。",
        brewMirror: "公式ソースが使えないため、ミラーから Homebrew を入れます…",
        brewFailed: "Homebrew のインストールに失敗しました。ネットワークを確認するか、依存関係タブの Homebrew を開いて手動で入れてください。",
        fusePresent: "MacFUSE は既にあります。インストールをスキップします。",
        installingFuse: "MacFUSE をインストールしています…",
        installingNtfs: "ntfs-3g をインストールしています…",
        installingFswatch: "fswatch をインストールしています（任意）…",
        done: "完了しました。macOS が尋ねたら、システム設定で MacFUSE 拡張を承認し、アプリで「依存関係を確認」してください。",
        pressEnter: "Enter で閉じます…"
    )

    static let de = InstallerCopy(
        title: "Nigate-Abhängigkeiten",
        scope: "Fehlendes wird der Reihe nach eingerichtet: Xcode Command Line Tools, Homebrew, MacFUSE, ntfs-3g und fswatch. Vorhandenes wird übersprungen.",
        next: "macOS kann ein Installationsfenster zeigen, nach dem Passwort fragen und die Freigabe der MacFUSE-Erweiterung verlangen. Dieses Terminal geöffnet lassen.",
        macosTooOld: "macOS 14 oder neuer ist erforderlich.",
        cltPresent: "Xcode Command Line Tools sind bereits vorhanden. Wird übersprungen.",
        installingCLT: "Xcode Command Line Tools werden installiert…",
        waitingCLT: "Im Systemfenster „Installieren“ wählen. Das Skript fährt fort, sobald das abgeschlossen ist.",
        cltTimeout: "Warten auf Xcode Command Line Tools abgelaufen. Wenn Sie das Systemfenster abgebrochen haben, Terminal schließen und „Alles installieren“ erneut starten.",
        brewPresent: "Homebrew ist bereits vorhanden. Wird übersprungen.",
        installingBrew: "Homebrew wird installiert…",
        brewOfficial: "Offizielles Homebrew-Installationsskript wird verwendet.",
        brewMirror: "Offizielle Quelle nicht erreichbar. Homebrew wird über einen Spiegel installiert…",
        brewFailed: "Homebrew-Installation fehlgeschlagen. Netzwerk prüfen oder Homebrew unter Abhängigkeiten aufklappen und manuell installieren.",
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
        let script = dependencyScript(language: language)
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

    static func dependencyScript(language: AppLanguage) -> String {
        let copy = InstallerCopy.resolve(language)
        return """
        #!/bin/bash
        set -u
        export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin"
        BREW_INSTALLER=""
        cleanup() {
          rm -f "$0"
          if [[ -n "$BREW_INSTALLER" ]]; then rm -f "$BREW_INSTALLER"; fi
        }
        trap cleanup EXIT
        echo "------------------------------------------"
        echo "\(copy.title)"
        echo "------------------------------------------"
        echo "\(copy.scope)"
        echo "\(copy.next)"
        echo
        if [[ "$(/usr/bin/sw_vers -productVersion 2>/dev/null)" < "14.0" ]]; then
          echo "\(copy.macosTooOld)"
          echo "\(copy.pressEnter)"
          read -r
          exit 1
        fi
        clt_ready() {
          /usr/bin/xcode-select -p >/dev/null 2>&1 || return 1
          /usr/bin/xcrun --find clang >/dev/null 2>&1
        }
        if clt_ready; then
          echo "\(copy.cltPresent)"
        else
          echo "\(copy.installingCLT)"
          /usr/bin/xcode-select --install >/dev/null 2>&1 || true
          echo "\(copy.waitingCLT)"
          WAITED=0
          while ! clt_ready; do
            /bin/sleep 8
            WAITED=$((WAITED + 8))
            if [ $((WAITED % 40)) -eq 0 ]; then
              echo "\(copy.waitingCLT)"
            fi
            if [ "$WAITED" -ge 1800 ]; then
              echo "\(copy.cltTimeout)"
              echo "\(copy.pressEnter)"
              read -r
              exit 1
            fi
          done
        fi
        find_brew() {
          local c
          for c in /opt/homebrew/bin/brew /usr/local/bin/brew; do
            if [[ -x "$c" ]]; then
              printf '%s\\n' "$c"
              return 0
            fi
          done
          c="$(command -v brew 2>/dev/null || true)"
          if [[ -n "$c" && -x "$c" ]]; then
            printf '%s\\n' "$c"
            return 0
          fi
          return 1
        }
        activate_brew() {
          if [[ -x /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
          elif [[ -x /usr/local/bin/brew ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
          fi
        }
        BREW="$(find_brew || true)"
        if [[ -n "$BREW" ]]; then
          echo "\(copy.brewPresent)"
        else
          echo "\(copy.installingBrew)"
          BREW_INSTALLER="$(/usr/bin/mktemp -t nigate-brew)"
          FETCH_OK=0
          if /usr/bin/curl -fsSL --connect-timeout 15 --max-time 90 \\
              "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" \\
              -o "$BREW_INSTALLER"; then
            echo "\(copy.brewOfficial)"
            FETCH_OK=1
          elif /usr/bin/curl -fsSL --connect-timeout 15 --max-time 90 \\
              "https://gitee.com/ineo6/homebrew-install/raw/master/install.sh" \\
              -o "$BREW_INSTALLER"; then
            echo "\(copy.brewMirror)"
            FETCH_OK=1
          fi
          if [[ "$FETCH_OK" -ne 1 ]]; then
            echo "\(copy.brewFailed)"
            echo "\(copy.pressEnter)"
            read -r
            exit 1
          fi
          NONINTERACTIVE=1 /bin/bash "$BREW_INSTALLER"
          BREW_STATUS=$?
          rm -f "$BREW_INSTALLER"
          BREW_INSTALLER=""
          if [[ "$BREW_STATUS" -ne 0 ]]; then
            echo "\(copy.brewFailed)"
            echo "\(copy.pressEnter)"
            read -r
            exit 1
          fi
          activate_brew
          BREW="$(find_brew || true)"
          if [[ -z "$BREW" ]]; then
            echo "\(copy.brewFailed)"
            echo "\(copy.pressEnter)"
            read -r
            exit 1
          fi
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
