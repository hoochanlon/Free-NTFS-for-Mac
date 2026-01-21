#!/bin/bash
# ============================================================
# build.sh 多语言支持文件
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
				starting_build) echo "开始构建 Free NTFS for Mac..." ;;
				unknown_param) echo "未知参数: $2" ;;
				cleaning_dist) echo "清理 dist 目录..." ;;
				checking_readme) echo "检查 DMG 使用说明文件..." ;;
				readme_ready) echo "✓ 多语言使用说明文件 README.txt 已准备就绪" ;;
				warning_readme_not_found) echo "⚠️  警告: 未找到 README.txt 使用说明文件" ;;
				readme_ensure) echo "   请确保 docs/README.txt 文件存在" ;;
				warning_no_node_modules) echo "⚠️  警告: node_modules 不存在，正在安装依赖..." ;;
				error_install_failed) echo "❌ 错误: 依赖安装失败" ;;
				syncing_version) echo "同步版本号..." ;;
				compiling) echo "编译 TypeScript 和 Stylus..." ;;
				warning_no_styles) echo "警告: styles.css 不存在，重新编译..." ;;
				styles_updated) echo "✓ styles.css 已更新" ;;
				starting_package) echo "开始打包..." ;;
				package_complete) echo "打包完成！文件位于 dist 目录" ;;
				cleaned_temp) echo "✓ 已清理临时文件 README.txt" ;;
				*) echo "$key" ;;
			esac
			;;
		ja)
			case "$key" in
				error_cd_failed) echo "❌ エラー: プロジェクトルートディレクトリに切り替えできません" ;;
				starting_build) echo "Free NTFS for Mac のビルドを開始..." ;;
				unknown_param) echo "不明なパラメータ: $2" ;;
				cleaning_dist) echo "dist ディレクトリをクリーンアップ中..." ;;
				checking_readme) echo "DMG 使用説明ファイルを確認中..." ;;
				readme_ready) echo "✓ 多言語使用説明ファイル README.txt の準備が完了しました" ;;
				warning_readme_not_found) echo "⚠️  警告: README.txt 使用説明ファイルが見つかりません" ;;
				readme_ensure) echo "   docs/README.txt ファイルが存在することを確認してください" ;;
				warning_no_node_modules) echo "⚠️  警告: node_modules が存在しません。依存関係をインストール中..." ;;
				error_install_failed) echo "❌ エラー: 依存関係のインストールに失敗しました" ;;
				syncing_version) echo "バージョン番号を同期中..." ;;
				compiling) echo "TypeScript と Stylus をコンパイル中..." ;;
				warning_no_styles) echo "警告: styles.css が存在しません。再コンパイル中..." ;;
				styles_updated) echo "✓ styles.css が更新されました" ;;
				starting_package) echo "パッケージングを開始中..." ;;
				package_complete) echo "パッケージングが完了しました！ファイルは dist ディレクトリにあります" ;;
				cleaned_temp) echo "✓ 一時ファイル README.txt をクリーンアップしました" ;;
				*) echo "$key" ;;
			esac
			;;
		en|*)
			case "$key" in
				error_cd_failed) echo "❌ Error: Cannot switch to project root directory" ;;
				starting_build) echo "Starting build Free NTFS for Mac..." ;;
				unknown_param) echo "Unknown parameter: $2" ;;
				cleaning_dist) echo "Cleaning dist directory..." ;;
				checking_readme) echo "Checking DMG README file..." ;;
				readme_ready) echo "✓ Multi-language README.txt file is ready" ;;
				warning_readme_not_found) echo "⚠️  Warning: README.txt file not found" ;;
				readme_ensure) echo "   Please ensure docs/README.txt file exists" ;;
				warning_no_node_modules) echo "⚠️  Warning: node_modules does not exist, installing dependencies..." ;;
				error_install_failed) echo "❌ Error: Dependency installation failed" ;;
				syncing_version) echo "Syncing version number..." ;;
				compiling) echo "Compiling TypeScript and Stylus..." ;;
				warning_no_styles) echo "Warning: styles.css does not exist, recompiling..." ;;
				styles_updated) echo "✓ styles.css has been updated" ;;
				starting_package) echo "Starting packaging..." ;;
				package_complete) echo "Packaging complete! Files are in dist directory" ;;
				cleaned_temp) echo "✓ Cleaned up temporary file README.txt" ;;
				*) echo "$key" ;;
			esac
			;;
	esac
}
