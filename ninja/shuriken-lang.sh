#!/bin/bash
# ============================================================
# shuriken.sh 多语言支持文件
# ============================================================

# 检测系统语言
detect_language() {
	if [ -n "$LANG" ]; then
		case "$LANG" in
			*zh*|*CN*|*TW*)
				echo "zh"
				;;
			*ja*|*JP*)
				echo "ja"
				;;
			*)
				echo "en"
				;;
		esac
	elif [ -n "$LC_ALL" ]; then
		case "$LC_ALL" in
			*zh*|*CN*|*TW*)
				echo "zh"
				;;
			*ja*|*JP*)
				echo "ja"
				;;
			*)
				echo "en"
				;;
		esac
	else
		sys_lang=$(defaults read -g AppleLanguages 2>/dev/null | head -1 | sed 's/[",]//g' | cut -d'_' -f1)
		case "$sys_lang" in
			zh)
				echo "zh"
				;;
			ja)
				echo "ja"
				;;
			*)
				echo "en"
				;;
		esac
	fi
}

SCRIPT_LANG=$(detect_language)

t() {
	local key=$1
	case "$SCRIPT_LANG" in
		zh)
			case "$key" in
				error_macos_only) echo "此脚本仅适用于 macOS 系统" ;;
				preparing_disable) echo "准备禁用 Gatekeeper（允许任何来源的应用）..." ;;
				needs_admin) echo "此操作需要管理员权限" ;;
				gatekeeper_desc) echo "说明：Gatekeeper 是 macOS 的安全功能，用于限制未签名应用的运行。" ;;
				gatekeeper_result) echo "禁用后，您可以在「系统设置」>「隐私与安全性」中看到「任何来源」选项。" ;;
				executing) echo "正在执行: sudo spctl --master-disable" ;;
				disabled) echo "Gatekeeper 已禁用" ;;
				confirm_settings) echo "提示：需要在「系统设置」>「隐私与安全性」中确认此更改" ;;
				anywhere_option) echo "现在可以在「系统设置」>「隐私与安全性」中看到「任何来源」选项" ;;
				disable_failed) echo "禁用失败，请检查权限" ;;
				enter_password) echo "需要管理员权限，请输入密码：" ;;
				password_error) echo "禁用失败，可能是密码错误或权限不足" ;;
				press_enter) echo "按回车键继续..." ;;
				sip_info) echo "系统完整性保护 (SIP) 说明" ;;
				sip_warning) echo "SIP (System Integrity Protection) 是 macOS 的系统完整性保护机制，" ;;
				sip_warning2) echo "用于限制 root 账户对系统的完全控制权（也叫 Rootless 保护机制）。" ;;
				sip_status_check) echo "SIP 状态检查：" ;;
				sip_status_cmd) echo "  在终端输入: csrutil status" ;;
				sip_disable_steps) echo "禁用 SIP 步骤（需要在恢复模式下操作）：" ;;
				sip_step1) echo "  1. 重启 Mac，按住 Command + R 直到屏幕上出现苹果标志和进度条" ;;
				sip_step2) echo "  2. 进入恢复模式后，在屏幕上方的工具栏找到并打开「终端」" ;;
				sip_step3) echo "  3. 在终端输入命令: csrutil disable" ;;
				sip_step4) echo "  4. 关闭终端，重启 Mac" ;;
				sip_step5) echo "  5. 重启后可以在终端中运行 csrutil status 确认状态" ;;
				sip_security_warning) echo "注意：禁用 SIP 会降低系统安全性，请谨慎操作。" ;;
				sip_reenable) echo "如需重新启用 SIP，在恢复模式下运行: csrutil enable" ;;
				current_status) echo "当前状态检查：" ;;
				gatekeeper_status) echo "Gatekeeper 状态（使用 spctl --status 检查）：" ;;
				cannot_check_gatekeeper) echo "  无法检查 Gatekeeper 状态" ;;
				sip_status_check2) echo "SIP 状态（使用 csrutil status 检查）：" ;;
				cannot_check_sip) echo "  无法在正常模式下检查 SIP 状态" ;;
				sip_recovery_mode) echo "  SIP 状态检查需要在恢复模式下运行 csrutil 命令" ;;
				unlock_app) echo "应用程序解锁工具" ;;
				unlock_desc) echo "此功能可以移除应用程序的隔离属性（quarantine），" ;;
				unlock_desc2) echo "允许运行从网络下载或拖拽安装的应用。" ;;
				drag_app) echo "请拖拽应用程序到此窗口，然后按回车：" ;;
				no_path) echo "未输入应用程序路径" ;;
				not_found) echo "文件或目录不存在: $2" ;;
				unlocking) echo "正在解锁: $2" ;;
				unlock_cmd) echo "执行命令: xattr -cr \"$2\"" ;;
				unlocked) echo "应用程序已解锁" ;;
				unlock_try) echo "您现在可以尝试运行该应用程序" ;;
				unlock_warning) echo "解锁操作完成（某些文件可能没有隔离属性）" ;;
				checking_status) echo "正在检查系统安全设置状态..." ;;
				gatekeeper_status_title) echo "=== Gatekeeper 状态 ===" ;;
				gatekeeper_disabled) echo "Gatekeeper 已禁用（允许任何来源）" ;;
				gatekeeper_enabled) echo "Gatekeeper 已启用" ;;
				disable_option) echo "如需禁用，请选择选项 1" ;;
				sip_status_title) echo "=== SIP (系统完整性保护) 状态 ===" ;;
				sip_disabled) echo "SIP 已禁用" ;;
				sip_enabled) echo "SIP 已启用（默认状态）" ;;
				sip_disable_info) echo "如需禁用，请选择选项 2 查看详细说明" ;;
				menu_title) echo "🥷 Shuriken - macOS 权限设置工具" ;;
				select_operation) echo "请选择操作：" ;;
				option1) echo "禁用 Gatekeeper（允许任何来源）" ;;
				option1_cmd) echo "sudo spctl --master-disable" ;;
				option2) echo "SIP 禁用说明" ;;
				option2_desc) echo "查看系统完整性保护的禁用方法（需恢复模式）" ;;
				option3) echo "解锁应用程序 (xattr -cr)" ;;
				option3_desc) echo "移除应用的隔离属性" ;;
				option4) echo "检查当前状态" ;;
				option4_desc) echo "查看 Gatekeeper 和 SIP 的当前状态" ;;
				option0) echo "退出" ;;
				enter_option) echo "请输入选项 [0-4]: " ;;
				thanks) echo "感谢使用 Shuriken！" ;;
				invalid_option) echo "无效选项，请重新选择" ;;
				*) echo "$key" ;;
			esac
			;;
		ja)
			case "$key" in
				error_macos_only) echo "このスクリプトは macOS システムのみサポートしています" ;;
				preparing_disable) echo "Gatekeeper を無効化する準備中（任意のソースからのアプリを許可）..." ;;
				needs_admin) echo "この操作には管理者権限が必要です" ;;
				gatekeeper_desc) echo "説明：Gatekeeper は macOS のセキュリティ機能で、未署名アプリの実行を制限します。" ;;
				gatekeeper_result) echo "無効化後、「システム設定」>「プライバシーとセキュリティ」で「すべてのソース」オプションが表示されます。" ;;
				executing) echo "実行中: sudo spctl --master-disable" ;;
				disabled) echo "Gatekeeper が無効化されました" ;;
				confirm_settings) echo "ヒント：「システム設定」>「プライバシーとセキュリティ」でこの変更を確認する必要があります" ;;
				anywhere_option) echo "「システム設定」>「プライバシーとセキュリティ」で「すべてのソース」オプションが表示されます" ;;
				disable_failed) echo "無効化に失敗しました。権限を確認してください" ;;
				enter_password) echo "管理者権限が必要です。パスワードを入力してください：" ;;
				password_error) echo "無効化に失敗しました。パスワードが間違っているか、権限が不足している可能性があります" ;;
				press_enter) echo "Enter キーを押して続行..." ;;
				sip_info) echo "システム整合性保護 (SIP) の説明" ;;
				sip_warning) echo "SIP (System Integrity Protection) は macOS のシステム整合性保護メカニズムで、" ;;
				sip_warning2) echo "root アカウントのシステムへの完全な制御権を制限します（Rootless 保護メカニズムとも呼ばれます）。" ;;
				sip_status_check) echo "SIP 状態の確認：" ;;
				sip_status_cmd) echo "  ターミナルで入力: csrutil status" ;;
				sip_disable_steps) echo "SIP を無効化する手順（リカバリーモードで操作が必要）：" ;;
				sip_step1) echo "  1. Mac を再起動し、Command + R を押し続けて、画面に Apple ロゴとプログレスバーが表示されるまで待つ" ;;
				sip_step2) echo "  2. リカバリーモードに入ったら、画面上部のツールバーから「ターミナル」を見つけて開く" ;;
				sip_step3) echo "  3. ターミナルでコマンドを入力: csrutil disable" ;;
				sip_step4) echo "  4. ターミナルを閉じて Mac を再起動" ;;
				sip_step5) echo "  5. 再起動後、ターミナルで csrutil status を実行して状態を確認できる" ;;
				sip_security_warning) echo "注意：SIP を無効化するとシステムのセキュリティが低下します。慎重に操作してください。" ;;
				sip_reenable) echo "SIP を再有効化するには、リカバリーモードで実行: csrutil enable" ;;
				current_status) echo "現在の状態確認：" ;;
				gatekeeper_status) echo "Gatekeeper 状態（spctl --status を使用して確認）：" ;;
				cannot_check_gatekeeper) echo "  Gatekeeper 状態を確認できません" ;;
				sip_status_check2) echo "SIP 状態（csrutil status を使用して確認）：" ;;
				cannot_check_sip) echo "  通常モードでは SIP 状態を確認できません" ;;
				sip_recovery_mode) echo "  SIP 状態の確認には、リカバリーモードで csrutil コマンドを実行する必要があります" ;;
				unlock_app) echo "アプリケーションのロック解除ツール" ;;
				unlock_desc) echo "この機能は、アプリケーションの隔離属性（quarantine）を削除し、" ;;
				unlock_desc2) echo "ネットワークからダウンロードまたはドラッグ＆ドロップでインストールしたアプリを実行できるようにします。" ;;
				drag_app) echo "アプリケーションをこのウィンドウにドラッグして、Enter キーを押してください：" ;;
				no_path) echo "アプリケーションパスが入力されていません" ;;
				not_found) echo "ファイルまたはディレクトリが存在しません: $2" ;;
				unlocking) echo "ロック解除中: $2" ;;
				unlock_cmd) echo "コマンドを実行: xattr -cr \"$2\"" ;;
				unlocked) echo "アプリケーションがロック解除されました" ;;
				unlock_try) echo "アプリケーションを実行してみてください" ;;
				unlock_warning) echo "ロック解除操作が完了しました（一部のファイルには隔離属性がない場合があります）" ;;
				checking_status) echo "システムセキュリティ設定の状態を確認中..." ;;
				gatekeeper_status_title) echo "=== Gatekeeper 状態 ===" ;;
				gatekeeper_disabled) echo "Gatekeeper が無効化されています（任意のソースを許可）" ;;
				gatekeeper_enabled) echo "Gatekeeper が有効になっています" ;;
				disable_option) echo "無効化するには、オプション 1 を選択してください" ;;
				sip_status_title) echo "=== SIP (システム整合性保護) 状態 ===" ;;
				sip_disabled) echo "SIP が無効化されています" ;;
				sip_enabled) echo "SIP が有効になっています（デフォルト状態）" ;;
				sip_disable_info) echo "無効化するには、オプション 2 を選択して詳細な説明を確認してください" ;;
				menu_title) echo "🥷 Shuriken - macOS 権限設定ツール" ;;
				select_operation) echo "操作を選択してください：" ;;
				option1) echo "Gatekeeper を無効化（任意のソースを許可）" ;;
				option1_cmd) echo "sudo spctl --master-disable" ;;
				option2) echo "SIP 無効化の説明" ;;
				option2_desc) echo "システム整合性保護の無効化方法を確認（リカバリーモードが必要）" ;;
				option3) echo "アプリケーションのロック解除 (xattr -cr)" ;;
				option3_desc) echo "アプリの隔離属性を削除" ;;
				option4) echo "現在の状態を確認" ;;
				option4_desc) echo "Gatekeeper と SIP の現在の状態を確認" ;;
				option0) echo "終了" ;;
				enter_option) echo "オプションを入力してください [0-4]: " ;;
				thanks) echo "Shuriken をご利用いただきありがとうございます！" ;;
				invalid_option) echo "無効なオプションです。再度選択してください" ;;
				*) echo "$key" ;;
			esac
			;;
		en|*)
			case "$key" in
				error_macos_only) echo "This script only supports macOS systems" ;;
				preparing_disable) echo "Preparing to disable Gatekeeper (allow apps from any source)..." ;;
				needs_admin) echo "This operation requires administrator privileges" ;;
				gatekeeper_desc) echo "Description: Gatekeeper is a macOS security feature that restricts the execution of unsigned applications." ;;
				gatekeeper_result) echo "After disabling, you can see the 'Anywhere' option in System Settings > Privacy & Security." ;;
				executing) echo "Executing: sudo spctl --master-disable" ;;
				disabled) echo "Gatekeeper has been disabled" ;;
				confirm_settings) echo "Note: You need to confirm this change in System Settings > Privacy & Security" ;;
				anywhere_option) echo "You can now see the 'Anywhere' option in System Settings > Privacy & Security" ;;
				disable_failed) echo "Disable failed, please check permissions" ;;
				enter_password) echo "Administrator privileges required, please enter password:" ;;
				password_error) echo "Disable failed, password may be incorrect or insufficient permissions" ;;
				press_enter) echo "Press Enter to continue..." ;;
				sip_info) echo "System Integrity Protection (SIP) Information" ;;
				sip_warning) echo "SIP (System Integrity Protection) is macOS's system integrity protection mechanism," ;;
				sip_warning2) echo "used to limit the root account's full control over the system (also called Rootless protection mechanism)." ;;
				sip_status_check) echo "SIP Status Check:" ;;
				sip_status_cmd) echo "  Enter in terminal: csrutil status" ;;
				sip_disable_steps) echo "Steps to disable SIP (requires operation in Recovery Mode):" ;;
				sip_step1) echo "  1. Restart Mac, hold Command + R until Apple logo and progress bar appear on screen" ;;
				sip_step2) echo "  2. After entering Recovery Mode, find and open 'Terminal' from the toolbar at the top of the screen" ;;
				sip_step3) echo "  3. Enter command in terminal: csrutil disable" ;;
				sip_step4) echo "  4. Close terminal and restart Mac" ;;
				sip_step5) echo "  5. After restart, you can run csrutil status in terminal to confirm status" ;;
				sip_security_warning) echo "Note: Disabling SIP will reduce system security, please operate with caution." ;;
				sip_reenable) echo "To re-enable SIP, run in Recovery Mode: csrutil enable" ;;
				current_status) echo "Current Status Check:" ;;
				gatekeeper_status) echo "Gatekeeper Status (check using spctl --status):" ;;
				cannot_check_gatekeeper) echo "  Cannot check Gatekeeper status" ;;
				sip_status_check2) echo "SIP Status (check using csrutil status):" ;;
				cannot_check_sip) echo "  Cannot check SIP status in normal mode" ;;
				sip_recovery_mode) echo "  SIP status check requires running csrutil command in Recovery Mode" ;;
				unlock_app) echo "Application Unlock Tool" ;;
				unlock_desc) echo "This feature can remove the quarantine attribute from applications," ;;
				unlock_desc2) echo "allowing apps downloaded from the network or installed by drag-and-drop to run." ;;
				drag_app) echo "Please drag the application to this window, then press Enter:" ;;
				no_path) echo "No application path entered" ;;
				not_found) echo "File or directory does not exist: $2" ;;
				unlocking) echo "Unlocking: $2" ;;
				unlock_cmd) echo "Executing command: xattr -cr \"$2\"" ;;
				unlocked) echo "Application has been unlocked" ;;
				unlock_try) echo "You can now try to run the application" ;;
				unlock_warning) echo "Unlock operation completed (some files may not have quarantine attributes)" ;;
				checking_status) echo "Checking system security settings status..." ;;
				gatekeeper_status_title) echo "=== Gatekeeper Status ===" ;;
				gatekeeper_disabled) echo "Gatekeeper is disabled (allow any source)" ;;
				gatekeeper_enabled) echo "Gatekeeper is enabled" ;;
				disable_option) echo "To disable, please select option 1" ;;
				sip_status_title) echo "=== SIP (System Integrity Protection) Status ===" ;;
				sip_disabled) echo "SIP is disabled" ;;
				sip_enabled) echo "SIP is enabled (default state)" ;;
				sip_disable_info) echo "To disable, please select option 2 to view detailed instructions" ;;
				menu_title) echo "🥷 Shuriken - macOS Permission Settings Tool" ;;
				select_operation) echo "Please select an operation:" ;;
				option1) echo "Disable Gatekeeper (allow any source)" ;;
				option1_cmd) echo "sudo spctl --master-disable" ;;
				option2) echo "SIP Disable Instructions" ;;
				option2_desc) echo "View method to disable System Integrity Protection (requires Recovery Mode)" ;;
				option3) echo "Unlock Application (xattr -cr)" ;;
				option3_desc) echo "Remove application's quarantine attribute" ;;
				option4) echo "Check Current Status" ;;
				option4_desc) echo "View current status of Gatekeeper and SIP" ;;
				option0) echo "Exit" ;;
				enter_option) echo "Please enter option [0-4]: " ;;
				thanks) echo "Thank you for using Shuriken!" ;;
				invalid_option) echo "Invalid option, please select again" ;;
				*) echo "$key" ;;
			esac
			;;
	esac
}
