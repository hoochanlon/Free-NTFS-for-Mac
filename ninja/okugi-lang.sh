#!/bin/bash
# ============================================================
# okugi.sh 多语言支持文件
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
				title) echo "Git历史清理脚本" ;;
				warning_rewrite) echo "⚠️  警告：此操作会重写Git历史！" ;;
				warning_backup) echo "⚠️  执行前请确保已备份仓库并通知协作者！" ;;
				confirm) echo "是否继续？(yes/no): " ;;
				cancelled) echo "操作已取消" ;;
				starting) echo "开始清理Git历史..." ;;
				step1) echo "1. 移除 .electron-cache 目录..." ;;
				step2) echo "2. 移除 shell_for_helpdesk/NTFS-Pro-Installer-v1.1.1.pkg..." ;;
				step3) echo "3. 清理引用..." ;;
				complete) echo "清理完成！" ;;
				check_size) echo "请检查仓库大小：" ;;
				if_reduced) echo "如果大小已减小，可以执行以下命令推送到远程：" ;;
				force_push_warning) echo "⚠️  注意：force push会影响所有协作者，请确保已通知他们！" ;;
				*) echo "$key" ;;
			esac
			;;
		ja)
			case "$key" in
				title) echo "Git履歴クリーンアップスクリプト" ;;
				warning_rewrite) echo "⚠️  警告：この操作はGit履歴を書き換えます！" ;;
				warning_backup) echo "⚠️  実行前にリポジトリをバックアップし、すべての協力者に通知してください！" ;;
				confirm) echo "続行しますか？(yes/no): " ;;
				cancelled) echo "操作がキャンセルされました" ;;
				starting) echo "Git履歴のクリーンアップを開始..." ;;
				step1) echo "1. .electron-cache ディレクトリを削除中..." ;;
				step2) echo "2. shell_for_helpdesk/NTFS-Pro-Installer-v1.1.1.pkg を削除中..." ;;
				step3) echo "3. 参照をクリーンアップ中..." ;;
				complete) echo "クリーンアップが完了しました！" ;;
				check_size) echo "リポジトリサイズを確認してください：" ;;
				if_reduced) echo "サイズが減少した場合、次のコマンドを実行してリモートにプッシュできます：" ;;
				force_push_warning) echo "⚠️  注意：force pushはすべての協力者に影響します。必ず通知してください！" ;;
				*) echo "$key" ;;
			esac
			;;
		en|*)
			case "$key" in
				title) echo "Git History Cleanup Script" ;;
				warning_rewrite) echo "⚠️  Warning: This operation will rewrite Git history!" ;;
				warning_backup) echo "⚠️  Make sure you have backed up the repository and notified all collaborators before proceeding!" ;;
				confirm) echo "Continue? (yes/no): " ;;
				cancelled) echo "Operation cancelled" ;;
				starting) echo "Starting Git history cleanup..." ;;
				step1) echo "1. Removing .electron-cache directory..." ;;
				step2) echo "2. Removing shell_for_helpdesk/NTFS-Pro-Installer-v1.1.1.pkg..." ;;
				step3) echo "3. Cleaning up references..." ;;
				complete) echo "Cleanup complete!" ;;
				check_size) echo "Please check repository size:" ;;
				if_reduced) echo "If size has been reduced, you can push to remote with the following commands:" ;;
				force_push_warning) echo "⚠️  Note: Force push will affect all collaborators, make sure you have notified them!" ;;
				*) echo "$key" ;;
			esac
			;;
	esac
}
