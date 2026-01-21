#!/bin/bash
# ============================================================
# build-clean.sh 多语言支持文件
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
				error_cd_failed) echo "❌ 错误: 无法切换到项目根目录" ;;
				cleaning_cache) echo "🧹 清理构建缓存..." ;;
				deleting_dist) echo "  删除 dist 目录..." ;;
				cleaning_electron_cache) echo "  清理 electron-builder 缓存..." ;;
				cleaning_build) echo "  清理编译产物..." ;;
				recompiling) echo "📦 重新编译..." ;;
				starting_build) echo "🚀 开始打包..." ;;
				complete) echo "✅ 完成！" ;;
				*) echo "$key" ;;
			esac
			;;
		ja)
			case "$key" in
				error_cd_failed) echo "❌ エラー: プロジェクトルートディレクトリに切り替えできません" ;;
				cleaning_cache) echo "🧹 ビルドキャッシュをクリーンアップ中..." ;;
				deleting_dist) echo "  dist ディレクトリを削除中..." ;;
				cleaning_electron_cache) echo "  electron-builder キャッシュをクリーンアップ中..." ;;
				cleaning_build) echo "  ビルド成果物をクリーンアップ中..." ;;
				recompiling) echo "📦 再コンパイル中..." ;;
				starting_build) echo "🚀 パッケージングを開始中..." ;;
				complete) echo "✅ 完了！" ;;
				*) echo "$key" ;;
			esac
			;;
		en|*)
			case "$key" in
				error_cd_failed) echo "❌ Error: Cannot switch to project root directory" ;;
				cleaning_cache) echo "🧹 Cleaning build cache..." ;;
				deleting_dist) echo "  Deleting dist directory..." ;;
				cleaning_electron_cache) echo "  Cleaning electron-builder cache..." ;;
				cleaning_build) echo "  Cleaning build artifacts..." ;;
				recompiling) echo "📦 Recompiling..." ;;
				starting_build) echo "🚀 Starting build..." ;;
				complete) echo "✅ Complete!" ;;
				*) echo "$key" ;;
			esac
			;;
	esac
}
