#!/bin/bash
# ============================================================
# restart-watch.sh 多语言支持文件
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
				stopping) echo "正在停止现有的 watch 进程..." ;;
				verifying) echo "验证 filter-tsc-output.js 文件..." ;;
				error_not_found) echo "❌ 错误: filter-tsc-output.js 文件不存在！" ;;
				file_exists) echo "✅ filter-tsc-output.js 文件存在" ;;
				file_path) echo "文件路径: $2" ;;
				file_size) echo "文件大小: $2 字节" ;;
				unknown) echo "未知" ;;
				ready) echo "现在可以重新运行: pnpm run watch:ts" ;;
				*) echo "$key" ;;
			esac
			;;
		ja)
			case "$key" in
				stopping) echo "既存の watch プロセスを停止中..." ;;
				verifying) echo "filter-tsc-output.js ファイルを確認中..." ;;
				error_not_found) echo "❌ エラー: filter-tsc-output.js ファイルが見つかりません！" ;;
				file_exists) echo "✅ filter-tsc-output.js ファイルが存在します" ;;
				file_path) echo "ファイルパス: $2" ;;
				file_size) echo "ファイルサイズ: $2 バイト" ;;
				unknown) echo "不明" ;;
				ready) echo "次を再実行できます: pnpm run watch:ts" ;;
				*) echo "$key" ;;
			esac
			;;
		en|*)
			case "$key" in
				stopping) echo "Stopping existing watch processes..." ;;
				verifying) echo "Verifying filter-tsc-output.js file..." ;;
				error_not_found) echo "❌ Error: filter-tsc-output.js file not found!" ;;
				file_exists) echo "✅ filter-tsc-output.js file exists" ;;
				file_path) echo "File path: $2" ;;
				file_size) echo "File size: $2 bytes" ;;
				unknown) echo "Unknown" ;;
				ready) echo "You can now rerun: pnpm run watch:ts" ;;
				*) echo "$key" ;;
			esac
			;;
	esac
}
