#!/bin/bash

################################################################################
# Free NTFS for Mac - 依赖卸载脚本
#
# 功能说明：
#   卸载通过 install-dependencies.sh 安装的依赖，包括：
#   - MacFUSE
#   - ntfs-3g-mac
#   - fswatch (如果已安装)
#   - Homebrew (可选，如果仅为本项目安装)
#
# 注意：
#   - 本脚本不会卸载 Xcode Command Line Tools
#   - 原因：Xcode Command Line Tools 是 macOS 开发的基础工具，许多其他应用
#     和工具都依赖它。卸载它可能会影响其他开发工具和应用的正常运行。
#     它占用的空间相对较小，保留它不会造成太大影响。
#     如果确实需要卸载，请通过 系统设置 > 开发者工具 手动卸载。
#
# 使用方法：
#   bash uninstall-dependencies.sh
#   或添加执行权限后: chmod +x uninstall-dependencies.sh && ./uninstall-dependencies.sh
#
# 设置语言：
#   LANG=zh_CN bash uninstall-dependencies.sh  # 中文
#   LANG=en_US bash uninstall-dependencies.sh  # 英文
#   LANG=ja_JP bash uninstall-dependencies.sh  # 日文
################################################################################

# ============================================================
# 多语言支持
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

# 设置语言
SCRIPT_LANG=$(detect_language)

# 翻译函数
t() {
	local key=$1
	shift
	case "$SCRIPT_LANG" in
		zh)
			case "$key" in
				title) echo "==========================================" ;;
				subtitle) echo "Free NTFS for Mac - 依赖卸载脚本" ;;
				step) echo "[步骤 $1] $2" ;;
				checking) echo "检查 $1..." ;;
				uninstalling) echo "正在卸载 $1..." ;;
				uninstalled) echo "✅ $1 已卸载" ;;
				not_found) echo "⏭️  $1 未安装，跳过" ;;
				success) echo "✅ $1 卸载成功" ;;
				error) echo "❌ 错误: $1" ;;
				skip) echo "⏭️  跳过: $1" ;;
				all_done) echo "✨ 依赖卸载完成！" ;;
				confirm_uninstall) echo "确定要卸载 $1 吗？(y/N): " ;;
				confirm_brew) echo "是否卸载 Homebrew？(注意：如果 Homebrew 还用于其他项目，请选择 N) (y/N): " ;;
				brew_kept) echo "⏭️  保留 Homebrew" ;;
				brew_uninstalling) echo "正在卸载 Homebrew..." ;;
				xcode_notice) echo "⚠️  注意：本脚本不会卸载 Xcode Command Line Tools" ;;
				xcode_reason) echo "   原因：Xcode Command Line Tools 是 macOS 开发的基础工具，" ;;
				xcode_reason2) echo "         许多其他应用和工具都依赖它。卸载它可能会影响其他开发工具和应用的正常运行。" ;;
				xcode_reason3) echo "         它占用的空间相对较小，保留它不会造成太大影响。" ;;
				xcode_reason4) echo "         如果确实需要卸载，请通过 系统设置 > 开发者工具 手动卸载。" ;;
				*) echo "$key" ;;
			esac
			;;
		ja)
			case "$key" in
				title) echo "==========================================" ;;
				subtitle) echo "Free NTFS for Mac - 依存関係アンインストールスクリプト" ;;
				step) echo "[ステップ $1] $2" ;;
				checking) echo "$1 を確認中..." ;;
				uninstalling) echo "$1 をアンインストール中..." ;;
				uninstalled) echo "✅ $1 がアンインストールされました" ;;
				not_found) echo "⏭️  $1 がインストールされていません、スキップ" ;;
				success) echo "✅ $1 のアンインストールに成功しました" ;;
				error) echo "❌ エラー: $1" ;;
				skip) echo "⏭️  スキップ: $1" ;;
				all_done) echo "✨ 依存関係のアンインストールが完了しました！" ;;
				confirm_uninstall) echo "$1 をアンインストールしますか？(y/N): " ;;
				confirm_brew) echo "Homebrew をアンインストールしますか？(注意：Homebrew が他のプロジェクトでも使用されている場合は N を選択してください) (y/N): " ;;
				brew_kept) echo "⏭️  Homebrew を保持" ;;
				brew_uninstalling) echo "Homebrew をアンインストール中..." ;;
				xcode_notice) echo "⚠️  注意：このスクリプトは Xcode Command Line Tools をアンインストールしません" ;;
				xcode_reason) echo "   理由：Xcode Command Line Tools は macOS 開発の基本ツールであり、" ;;
				xcode_reason2) echo "         多くの他のアプリケーションやツールが依存しています。アンインストールすると他の開発ツールやアプリケーションの正常な動作に影響を与える可能性があります。" ;;
				xcode_reason3) echo "         占有するスペースは比較的小さく、保持しても大きな影響はありません。" ;;
				xcode_reason4) echo "         本当にアンインストールする必要がある場合は、システム設定 > 開発者ツール から手動でアンインストールしてください。" ;;
				*) echo "$key" ;;
			esac
			;;
		en|*)
			case "$key" in
				title) echo "==========================================" ;;
				subtitle) echo "Free NTFS for Mac - Dependency Uninstallation Script" ;;
				step) echo "[Step $1] $2" ;;
				checking) echo "Checking $1..." ;;
				uninstalling) echo "Uninstalling $1..." ;;
				uninstalled) echo "✅ $1 has been uninstalled" ;;
				not_found) echo "⏭️  $1 is not installed, skipping" ;;
				success) echo "✅ $1 uninstalled successfully" ;;
				error) echo "❌ Error: $1" ;;
				skip) echo "⏭️  Skipping: $1" ;;
				all_done) echo "✨ Dependency uninstallation completed!" ;;
				confirm_uninstall) echo "Are you sure you want to uninstall $1? (y/N): " ;;
				confirm_brew) echo "Uninstall Homebrew? (Note: If Homebrew is used for other projects, please select N) (y/N): " ;;
				brew_kept) echo "⏭️  Keeping Homebrew" ;;
				brew_uninstalling) echo "Uninstalling Homebrew..." ;;
				xcode_notice) echo "⚠️  Note: This script will NOT uninstall Xcode Command Line Tools" ;;
				xcode_reason) echo "   Reason: Xcode Command Line Tools is a fundamental tool for macOS development," ;;
				xcode_reason2) echo "          and many other applications and tools depend on it. Uninstalling it may affect" ;;
				xcode_reason3) echo "          the normal operation of other development tools and applications." ;;
				xcode_reason4) echo "          It occupies relatively little space, and keeping it won't cause much impact." ;;
				xcode_reason5) echo "          If you really need to uninstall it, please do so manually via System Settings > Developer Tools." ;;
				*) echo "$key" ;;
			esac
			;;
	esac
}

# ============================================================
# 颜色输出
# ============================================================
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================
# 主程序
# ============================================================

echo ""
echo -e "${BLUE}$(t title)${NC}"
echo -e "${BLUE}$(t subtitle)${NC}"
echo -e "${BLUE}$(t title)${NC}"
echo ""

# ============================================================
# 关于 Xcode Command Line Tools 的说明
# ============================================================
echo -e "${YELLOW}$(t xcode_notice)${NC}"
echo "$(t xcode_reason)"
echo "$(t xcode_reason2)"
echo "$(t xcode_reason3)"
echo "$(t xcode_reason4)"
if [ "$SCRIPT_LANG" = "en" ]; then
	echo "$(t xcode_reason5)"
fi
echo ""

# ============================================================
# 确保 Homebrew 在 PATH 中
# ============================================================
if [ -f "/opt/homebrew/bin/brew" ]; then
	eval "$(/opt/homebrew/bin/brew shellenv)"
	BREW_PREFIX="/opt/homebrew"
elif [ -f "/usr/local/bin/brew" ]; then
	eval "$(/usr/local/bin/brew shellenv)"
	BREW_PREFIX="/usr/local"
fi

# ============================================================
# 步骤 1: 卸载 fswatch (如果已安装)
# ============================================================
echo -e "${GREEN}$(t step 1 "卸载 fswatch")${NC}"
if command -v fswatch >/dev/null 2>&1; then
	echo "$(t checking "fswatch")"
	if [ -x $(command -v brew) ]; then
		if brew list fswatch &>/dev/null; then
			echo "$(t uninstalling "fswatch")"
			brew uninstall fswatch
			echo "$(t success "fswatch")"
		else
			echo "$(t not_found "fswatch (通过 Homebrew)")"
		fi
	else
		echo -e "${YELLOW}$(t error "Homebrew 未找到，无法卸载 fswatch")${NC}"
	fi
else
	echo "$(t not_found "fswatch")"
fi
echo ""

# ============================================================
# 步骤 2: 卸载 ntfs-3g-mac
# ============================================================
echo -e "${GREEN}$(t step 2 "卸载 ntfs-3g-mac")${NC}"
if [ -x $(command -v brew) ]; then
	if brew list ntfs-3g-mac &>/dev/null; then
		echo "$(t checking "ntfs-3g-mac")"
		echo "$(t uninstalling "ntfs-3g-mac")"
		brew uninstall ntfs-3g-mac
		echo "$(t success "ntfs-3g-mac")"
	else
		echo "$(t not_found "ntfs-3g-mac")"
	fi
else
	echo -e "${YELLOW}$(t error "Homebrew 未找到，无法卸载 ntfs-3g-mac")${NC}"
fi
echo ""

# ============================================================
# 步骤 3: 卸载 MacFUSE
# ============================================================
echo -e "${GREEN}$(t step 3 "卸载 MacFUSE")${NC}"
if [ -x $(command -v brew) ]; then
	if brew list --cask macfuse &>/dev/null; then
		echo "$(t checking "MacFUSE")"
		echo "$(t uninstalling "MacFUSE")"
		brew uninstall --cask macfuse
		echo "$(t success "MacFUSE")"
	else
		echo "$(t not_found "MacFUSE")"
	fi
else
	echo -e "${YELLOW}$(t error "Homebrew 未找到，无法卸载 MacFUSE")${NC}"
fi
echo ""

# ============================================================
# 步骤 4: 卸载 gromgit/homebrew-fuse tap (如果存在)
# ============================================================
echo -e "${GREEN}$(t step 4 "卸载 gromgit/homebrew-fuse tap")${NC}"
if [ -x $(command -v brew) ]; then
	if brew tap | grep -q "gromgit/homebrew-fuse"; then
		echo "$(t checking "gromgit/homebrew-fuse tap")"
		echo "$(t uninstalling "gromgit/homebrew-fuse tap")"
		brew untap gromgit/homebrew-fuse
		echo "$(t success "gromgit/homebrew-fuse tap")"
	else
		echo "$(t not_found "gromgit/homebrew-fuse tap")"
	fi
else
	echo -e "${YELLOW}$(t error "Homebrew 未找到，无法卸载 tap")${NC}"
fi
echo ""

# ============================================================
# 步骤 5: 可选卸载 Homebrew
# ============================================================
echo -e "${GREEN}$(t step 5 "可选卸载 Homebrew")${NC}"
if [ -x $(command -v brew) ]; then
	echo "$(t checking "Homebrew")"
	echo -e "${YELLOW}$(t confirm_brew)${NC}"
	read -p "" uninstall_brew_choice
	if [ "$uninstall_brew_choice" = "y" ] || [ "$uninstall_brew_choice" = "Y" ]; then
		echo "$(t brew_uninstalling)"
		# 获取 Homebrew 卸载脚本
		if [ -n "$BREW_PREFIX" ]; then
			# 使用官方卸载脚本
			/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)" || {
				echo -e "${RED}$(t error "Homebrew 卸载失败")${NC}"
				echo "$(t checking "请手动运行: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)\"")"
			}
		else
			echo -e "${RED}$(t error "无法确定 Homebrew 安装路径")${NC}"
		fi
	else
		echo "$(t brew_kept)"
	fi
else
	echo "$(t not_found "Homebrew")"
fi
echo ""

# ============================================================
# 步骤 6: 恢复 macOS 安全检查设置 (可选)
# ============================================================
echo -e "${GREEN}$(t step 6 "恢复 macOS 安全检查设置 (可选)")${NC}"
echo "$(t checking "Gatekeeper 设置")"
read -p "$(t confirm_uninstall "恢复 macOS 安全检查 (Gatekeeper)")" restore_gatekeeper
if [ "$restore_gatekeeper" = "y" ] || [ "$restore_gatekeeper" = "Y" ]; then
	sudo spctl --master-enable 2>&1 || true
	echo "$(t success "macOS 安全检查已恢复")"
else
	echo "$(t skip "保留当前 Gatekeeper 设置")"
fi
echo ""

# ============================================================
# 完成
# ============================================================
echo ""
echo -e "${GREEN}$(t all_done)${NC}"
echo ""
if [ "$SCRIPT_LANG" = "zh" ]; then
	echo "已卸载的依赖："
	echo "  ✅ MacFUSE"
	echo "  ✅ ntfs-3g-mac"
	echo "  ✅ fswatch (如果已安装)"
	echo ""
	echo "保留的依赖："
	echo "  ⏭️  Xcode Command Line Tools (原因见上方说明)"
	echo ""
elif [ "$SCRIPT_LANG" = "ja" ]; then
	echo "アンインストールされた依存関係："
	echo "  ✅ MacFUSE"
	echo "  ✅ ntfs-3g-mac"
	echo "  ✅ fswatch (インストール済みの場合)"
	echo ""
	echo "保持された依存関係："
	echo "  ⏭️  Xcode Command Line Tools (理由は上記を参照)"
	echo ""
else
	echo "Uninstalled dependencies:"
	echo "  ✅ MacFUSE"
	echo "  ✅ ntfs-3g-mac"
	echo "  ✅ fswatch (if installed)"
	echo ""
	echo "Kept dependencies:"
	echo "  ⏭️  Xcode Command Line Tools (see reason above)"
	echo ""
fi
echo ""
