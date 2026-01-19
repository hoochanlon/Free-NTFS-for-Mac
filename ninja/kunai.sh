#!/bin/bash

################################################################################
# Free NTFS for Mac - 依赖安装脚本
#
# 功能说明：
#   一次性安装所有必要的系统依赖，包括：
#   - macOS 版本检查（要求 macOS 14+）
#   - macOS 安全检查设置
#   - Xcode Command Line Tools
#   - Homebrew (可选择原生或国内镜像源)
#   - MacFUSE
#   - ntfs-3g-mac
#   - fswatch (可选，用于事件驱动检测)
#
# 使用方法：
#   bash kunai.sh
#   或添加执行权限后: chmod +x kunai.sh && ./kunai.sh
#
# 设置语言：
#   LANG=zh_CN bash kunai.sh  # 中文
#   LANG=en_US bash kunai.sh  # 英文
#   LANG=ja_JP bash kunai.sh  # 日文
################################################################################

# 注意：不使用 set -e，因为某些命令（如 spctl）可能返回非零退出码但不影响功能
# set -e

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
				subtitle) echo "Free NTFS for Mac - 依赖安装脚本" ;;
				step) echo "[步骤 $1] $2" ;;
				checking) echo "检查 $1..." ;;
				installing) echo "正在安装 $1..." ;;
				installed) echo "✅ $1 已安装" ;;
				not_found) echo "❌ 未找到 $1" ;;
				success) echo "✅ $1 安装成功" ;;
				error) echo "❌ 错误: $1" ;;
				skip) echo "⏭️  跳过: $1 已存在" ;;
				select_brew) echo "请选择 Homebrew 安装源:" ;;
				option_1) echo "  1) 官方源 (推荐，但可能需要科学上网)" ;;
				option_2) echo "  2) 国内镜像源 (Gitee，适合国内用户)" ;;
				prompt) echo "请输入选项 [1-2] (默认: 2): " ;;
				invalid_option) echo "❌ 无效选项，使用默认值: 国内镜像源" ;;
				installing_brew_official) echo "正在从官方源安装 Homebrew..." ;;
				installing_brew_mirror) echo "正在从国内镜像源安装 Homebrew..." ;;
				configuring_brew_mirror) echo "正在配置 Homebrew 使用国内镜像源..." ;;
				brew_configured) echo "✅ Homebrew 已配置为使用国内镜像源" ;;
				all_done) echo "✨ 所有依赖安装完成！" ;;
				checking_macos) echo "检查 macOS 版本..." ;;
				macos_version) echo "macOS 版本: $1" ;;
				macos_satisfied) echo "✅ macOS 版本符合要求 (需要 macOS 14+)" ;;
				macos_unsatisfied) echo "❌ macOS 版本不符合要求 (需要 macOS 14+，当前: $1)" ;;
				install_fswatch) echo "是否安装 fswatch (可选，用于事件驱动检测，零延迟、低CPU)？" ;;
				installing_fswatch) echo "正在安装 fswatch..." ;;
				fswatch_installed) echo "✅ fswatch 已安装" ;;
				fswatch_skipped) echo "⏭️  跳过 fswatch 安装" ;;
				*) echo "$key" ;;
			esac
			;;
		ja)
			case "$key" in
				title) echo "==========================================" ;;
				subtitle) echo "Free NTFS for Mac - 依存関係インストールスクリプト" ;;
				step) echo "[ステップ $1] $2" ;;
				checking) echo "$1 を確認中..." ;;
				installing) echo "$1 をインストール中..." ;;
				installed) echo "✅ $1 がインストール済みです" ;;
				not_found) echo "❌ $1 が見つかりません" ;;
				success) echo "✅ $1 のインストールに成功しました" ;;
				error) echo "❌ エラー: $1" ;;
				skip) echo "⏭️  スキップ: $1 は既に存在します" ;;
				select_brew) echo "Homebrew のインストールソースを選択してください:" ;;
				option_1) echo "  1) 公式ソース (推奨、ただしVPNが必要な場合があります)" ;;
				option_2) echo "  2) 中国ミラーソース (Gitee、中国ユーザー向け)" ;;
				prompt) echo "オプションを入力してください [1-2] (デフォルト: 2): " ;;
				invalid_option) echo "❌ 無効なオプション、デフォルト値を使用: 中国ミラーソース" ;;
				installing_brew_official) echo "公式ソースから Homebrew をインストール中..." ;;
				installing_brew_mirror) echo "中国ミラーソースから Homebrew をインストール中..." ;;
				configuring_brew_mirror) echo "Homebrew を中国ミラーソースを使用するように設定中..." ;;
				brew_configured) echo "✅ Homebrew が中国ミラーソースを使用するように設定されました" ;;
				all_done) echo "✨ すべての依存関係のインストールが完了しました！" ;;
				checking_macos) echo "macOS バージョンを確認中..." ;;
				macos_version) echo "macOS バージョン: $1" ;;
				macos_satisfied) echo "✅ macOS バージョンが要件を満たしています (macOS 14+ が必要)" ;;
				macos_unsatisfied) echo "❌ macOS バージョンが要件を満たしていません (macOS 14+ が必要、現在: $1)" ;;
				install_fswatch) echo "fswatch をインストールしますか？(オプション、イベント駆動検出用、ゼロレイテンシー、低CPU)" ;;
				installing_fswatch) echo "fswatch をインストール中..." ;;
				fswatch_installed) echo "✅ fswatch がインストールされました" ;;
				fswatch_skipped) echo "⏭️  fswatch のインストールをスキップ" ;;
				*) echo "$key" ;;
			esac
			;;
		en|*)
			case "$key" in
				title) echo "==========================================" ;;
				subtitle) echo "Free NTFS for Mac - Dependency Installation Script" ;;
				step) echo "[Step $1] $2" ;;
				checking) echo "Checking $1..." ;;
				installing) echo "Installing $1..." ;;
				installed) echo "✅ $1 is already installed" ;;
				not_found) echo "❌ $1 not found" ;;
				success) echo "✅ $1 installed successfully" ;;
				error) echo "❌ Error: $1" ;;
				skip) echo "⏭️  Skipping: $1 already exists" ;;
				select_brew) echo "Please select Homebrew installation source:" ;;
				option_1) echo "  1) Official source (Recommended, but may require VPN)" ;;
				option_2) echo "  2) China mirror source (Gitee, for users in China)" ;;
				prompt) echo "Enter option [1-2] (default: 2): " ;;
				invalid_option) echo "❌ Invalid option, using default: China mirror source" ;;
				installing_brew_official) echo "Installing Homebrew from official source..." ;;
				installing_brew_mirror) echo "Installing Homebrew from China mirror source..." ;;
				configuring_brew_mirror) echo "Configuring Homebrew to use China mirror source..." ;;
				brew_configured) echo "✅ Homebrew configured to use China mirror source" ;;
				all_done) echo "✨ All dependencies installed successfully!" ;;
				checking_macos) echo "Checking macOS version..." ;;
				macos_version) echo "macOS version: $1" ;;
				macos_satisfied) echo "✅ macOS version meets requirements (macOS 14+ required)" ;;
				macos_unsatisfied) echo "❌ macOS version does not meet requirements (macOS 14+ required, current: $1)" ;;
				install_fswatch) echo "Install fswatch (optional, for event-driven detection, zero latency, low CPU)?" ;;
				installing_fswatch) echo "Installing fswatch..." ;;
				fswatch_installed) echo "✅ fswatch installed" ;;
				fswatch_skipped) echo "⏭️  Skipping fswatch installation" ;;
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
# 步骤 0: 检查 macOS 版本
# ============================================================
echo -e "${GREEN}$(t step 0 "检查 macOS 版本")${NC}"
echo "$(t checking_macos)"

MACOS_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "未知")
echo "$(t macos_version "$MACOS_VERSION")"

# 解析版本号
if [ "$MACOS_VERSION" != "未知" ]; then
	MAJOR_VERSION=$(echo "$MACOS_VERSION" | cut -d'.' -f1)
	if [ "$MAJOR_VERSION" -ge 14 ] 2>/dev/null; then
		echo "$(t macos_satisfied)"
	else
		echo -e "${RED}$(t macos_unsatisfied "$MACOS_VERSION")${NC}"
		echo -e "${YELLOW}提示: 请通过 系统设置 > 软件更新 升级 macOS${NC}"
		read -p "是否继续安装？(y/N): " continue_install
		if [ "$continue_install" != "y" ] && [ "$continue_install" != "Y" ]; then
			echo "安装已取消"
			exit 1
		fi
	fi
else
	echo -e "${YELLOW}⚠️  无法检测 macOS 版本，继续安装...${NC}"
fi
echo ""

# ============================================================
# 步骤 1: 禁用 macOS 安全检查
# ============================================================
echo -e "${GREEN}$(t step 1 "禁用 macOS 安全检查")${NC}"
echo "$(t checking "Gatekeeper 设置")"
# 尝试禁用 Gatekeeper
# 注意：在某些 macOS 版本中，即使命令执行成功，也可能返回非零退出码
# 或者需要用户在系统设置中确认，所以这里不检查退出码
spctl_output=$(sudo spctl --master-disable 2>&1) || true
echo "$spctl_output"

# 检查输出中是否包含需要确认的提示
if echo "$spctl_output" | grep -qi "needs to be confirmed\|需要确认\|要确认"; then
	echo -e "${YELLOW}⚠️  Gatekeeper 设置需要在系统设置中确认${NC}"
	echo "$(t checking "提示: 请在 系统设置 > 隐私与安全性 中确认禁用 Gatekeeper")"
	echo "$(t checking "脚本将继续执行，您可以在安装完成后手动确认")"
else
	echo "$(t success "macOS 安全检查已禁用")"
fi
echo ""

# ============================================================
# 步骤 2: 检查并安装 Xcode Command Line Tools
# ============================================================
echo -e "${GREEN}$(t step 2 "安装 Xcode Command Line Tools")${NC}"
if [ -x $(command -v swift) ]; then
	echo "$(t installed "Xcode Command Line Tools")"
else
	echo "$(t not_found "Xcode Command Line Tools")"
	echo "$(t installing "Xcode Command Line Tools")"
	echo "$(t checking "这将打开系统对话框，请按照提示完成安装...")"
	xcode-select --install || {
		echo "$(t error "Xcode Command Line Tools 安装失败或已取消")"
		echo "$(t checking "请手动运行: xcode-select --install")"
	}
	echo "$(t checking "等待 Xcode Command Line Tools 安装完成...")"
	# 等待用户完成安装
	read -p "$(t prompt)" -t 1 || true
fi
echo ""

# ============================================================
# 步骤 3: 检查并安装 Homebrew
# ============================================================
echo -e "${GREEN}$(t step 3 "安装 Homebrew")${NC}"
if [ -x $(command -v brew) ]; then
	echo "$(t installed "Homebrew")"
	BREW_SOURCE="existing"
else
	echo "$(t not_found "Homebrew")"

	# 选择安装源
	echo ""
	echo -e "${YELLOW}$(t select_brew)${NC}"
	echo "$(t option_1)"
	echo "$(t option_2)"
	echo ""
	read -p "$(t prompt)" brew_choice

	case "$brew_choice" in
		1)
			BREW_SOURCE="official"
			echo "$(t installing_brew_official)"
			/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
			;;
		2|"")
			BREW_SOURCE="mirror"
			echo "$(t installing_brew_mirror)"
			/bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"
			;;
		*)
			BREW_SOURCE="mirror"
			echo "$(t invalid_option)"
			echo "$(t installing_brew_mirror)"
			/bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"
			;;
	esac

	# 确保 Homebrew 在 PATH 中
	if [ -f "/opt/homebrew/bin/brew" ]; then
		eval "$(/opt/homebrew/bin/brew shellenv)"
		BREW_PREFIX="/opt/homebrew"
	elif [ -f "/usr/local/bin/brew" ]; then
		eval "$(/usr/local/bin/brew shellenv)"
		BREW_PREFIX="/usr/local"
	fi

	# 如果使用官方源安装，询问是否配置国内镜像
	if [ "$BREW_SOURCE" = "official" ] && [ -n "$BREW_PREFIX" ]; then
		echo ""
		read -p "$(t configuring_brew_mirror) (y/N): " configure_mirror
		if [ "$configure_mirror" = "y" ] || [ "$configure_mirror" = "Y" ]; then
			# 配置 Homebrew 使用国内镜像
			# 配置 git remote
			if [ -d "$BREW_PREFIX" ]; then
				cd "$BREW_PREFIX" && git remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git 2>/dev/null || true
			fi
			if [ -d "$BREW_PREFIX/Homebrew/Library/Taps/homebrew/homebrew-core" ]; then
				cd "$BREW_PREFIX/Homebrew/Library/Taps/homebrew/homebrew-core" && git remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git 2>/dev/null || true
			fi

			# 添加到 shell 配置文件
			shell_config=""
			if [ -f "$HOME/.zshrc" ]; then
				shell_config="$HOME/.zshrc"
			elif [ -f "$HOME/.bash_profile" ]; then
				shell_config="$HOME/.bash_profile"
			elif [ -f "$HOME/.bashrc" ]; then
				shell_config="$HOME/.bashrc"
			fi

			if [ -n "$shell_config" ]; then
				# 检查是否已经配置过
				if ! grep -q "HOMEBREW_BOTTLE_DOMAIN" "$shell_config" 2>/dev/null; then
					cat >> "$shell_config" << 'EOF'

# Homebrew 国内镜像配置
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
EOF
					echo "$(t brew_configured)"
				else
					echo "$(t skip "Homebrew 镜像配置已存在")"
				fi
			fi
		fi
	fi

	echo "$(t success "Homebrew")"
fi
echo ""

# ============================================================
# 步骤 4: 安装 MacFUSE
# ============================================================
echo -e "${GREEN}$(t step 4 "安装 MacFUSE")${NC}"
if brew list --cask macfuse &>/dev/null; then
	echo "$(t installed "MacFUSE")"
else
	echo "$(t installing "MacFUSE")"
	brew tap gromgit/homebrew-fuse
	brew install --cask macfuse
	echo "$(t success "MacFUSE")"
fi
echo ""

# ============================================================
# 步骤 5: 安装 ntfs-3g-mac
# ============================================================
echo -e "${GREEN}$(t step 5 "安装 ntfs-3g-mac")${NC}"
if brew list ntfs-3g-mac &>/dev/null; then
	echo "$(t installed "ntfs-3g-mac")"
else
	echo "$(t installing "ntfs-3g-mac")"
	brew install ntfs-3g-mac
	echo "$(t success "ntfs-3g-mac")"
fi
echo ""

# ============================================================
# 步骤 6: 安装 fswatch (可选)
# ============================================================
echo -e "${GREEN}$(t step 6 "安装 fswatch (可选)")${NC}"
if command -v fswatch >/dev/null 2>&1; then
	echo "$(t installed "fswatch")"
else
	echo "$(t not_found "fswatch")"
	echo ""
	read -p "$(t install_fswatch) (y/N): " install_fswatch_choice
	if [ "$install_fswatch_choice" = "y" ] || [ "$install_fswatch_choice" = "Y" ]; then
		echo "$(t installing_fswatch)"
		brew install fswatch
		echo "$(t success "fswatch")"
	else
		echo "$(t fswatch_skipped)"
		echo "$(t checking "提示: fswatch 是可选的性能优化工具，安装后可实现零延迟的设备检测")"
	fi
fi
echo ""

# ============================================================
# 步骤 7: 验证安装
# ============================================================
echo -e "${GREEN}$(t step 7 "验证安装")${NC}"

# 检查 ntfs-3g
NTFS3G_PATH=$(which ntfs-3g 2>/dev/null || echo "")
if [ -z "$NTFS3G_PATH" ]; then
	if [ -f "/opt/homebrew/bin/ntfs-3g" ]; then
		NTFS3G_PATH="/opt/homebrew/bin/ntfs-3g"
	elif [ -f "/usr/local/bin/ntfs-3g" ]; then
		NTFS3G_PATH="/usr/local/bin/ntfs-3g"
	fi
fi

if [ -n "$NTFS3G_PATH" ] && [ -f "$NTFS3G_PATH" ]; then
	echo "✅ ntfs-3g 路径: $NTFS3G_PATH"
else
	echo -e "${RED}$(t error "无法找到 ntfs-3g，请检查安装是否成功")${NC}"
	exit 1
fi

# 检查其他依赖
echo ""
echo "$(t checking "依赖状态:")"
echo "  macOS 版本: $MACOS_VERSION $([ "$MACOS_VERSION" != "未知" ] && [ "$(echo "$MACOS_VERSION" | cut -d'.' -f1)" -ge 14 ] 2>/dev/null && echo '✅ 符合要求' || echo '⚠️  需要 macOS 14+')"
echo "  Xcode Command Line Tools: $([ -x $(command -v swift) ] && echo '✅ 已安装' || echo '❌ 未安装')"
echo "  Homebrew: $([ -x $(command -v brew) ] && echo '✅ 已安装' || echo '❌ 未安装')"
echo "  MacFUSE: $(brew list --cask macfuse &>/dev/null && echo '✅ 已安装' || echo '❌ 未安装')"
echo "  ntfs-3g: $([ -n "$NTFS3G_PATH" ] && echo '✅ 已安装' || echo '❌ 未安装')"
echo "  fswatch: $(command -v fswatch >/dev/null 2>&1 && echo '✅ 已安装 (可选)' || echo '⏭️  未安装 (可选)')"
echo ""

# ============================================================
# 完成
# ============================================================
echo ""
echo -e "${GREEN}$(t all_done)${NC}"
echo ""
echo "$(t checking "现在可以运行 ninja/nigate.sh 来使用 NTFS 读写功能了！")"
echo ""
