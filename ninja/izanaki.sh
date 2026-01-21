#!/bin/bash

################################################################################
# Free NTFS for Mac - 一键运行脚本 (Multi-language Support)
#
# 设置语言: LANG=ja bash izanaki.sh (日文) 或 LANG=en bash izanaki.sh (英文)
################################################################################

set -e

# ============================================================
# 加载多语言支持
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/izanaki-lang.sh" ]; then
	source "$SCRIPT_DIR/izanaki-lang.sh"
else
	# 如果找不到语言文件，使用简单的回退函数
	t() { echo "$1"; }
fi

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_step() {
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  $1${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 检测命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检测 Node.js 版本
check_node_version() {
    if command_exists node; then
        NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$NODE_VERSION" -ge 16 ]; then
            return 0
        fi
    fi
    return 1
}

# 检查是否为 macOS
check_macos() {
    if [ "$(uname -s)" != "Darwin" ]; then
        print_error "$(t error_macos_only)"
        exit 1
    fi
}

# 安装 Node.js
install_node() {
    print_step "$(t step_check_nodejs)"

    if check_node_version; then
        print_success "$(t nodejs_installed "$(node -v)")"
        return 0
    fi

    print_warning "$(t nodejs_not_found)"

    if command_exists brew; then
        print_info "$(t nodejs_installing_homebrew)"
        brew install node
    else
        print_warning "$(t nodejs_homebrew_not_found)"
        echo ""
        print_info "$(t nodejs_installing_homebrew_now)"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # 配置 PATH（Apple Silicon Mac）
        if [ -f "/opt/homebrew/bin/brew" ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi

        print_info "$(t nodejs_installing)"
        brew install node
    fi

    # 验证安装
    if ! check_node_version; then
        print_error "$(t nodejs_install_failed)"
        exit 1
    fi

    print_success "$(t nodejs_install_success "$(node -v)")"
}

# 安装 pnpm
install_pnpm() {
    print_step "$(t step_check_pnpm)"

    if command_exists pnpm; then
        print_success "$(t pnpm_installed "$(pnpm -v)")"
        return 0
    fi

    print_warning "$(t pnpm_not_found)"

    # macOS 上优先使用 npm 安装 pnpm
    if command_exists npm; then
        print_info "$(t pnpm_installing)"
        npm install -g pnpm@latest
    else
        print_error "$(t pnpm_npm_not_found)"
        exit 1
    fi

    # 验证安装
    if ! command_exists pnpm; then
        print_error "$(t pnpm_install_failed)"
        echo "$(t pnpm_install_manual)"
        exit 1
    fi

    print_success "$(t pnpm_install_success "$(pnpm -v)")"
}

# 检查 Electron 是否正常工作
check_electron() {
    if node -e "require('electron')" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# 修复 Electron 安装
fix_electron() {
    print_warning "$(t electron_installing)"

    # 临时禁用 set -e，允许错误处理
    set +e

    # 查找 Electron 安装脚本
    ELECTRON_INSTALL_SCRIPT=""

    # 方法1: 直接查找所有 electron 目录下的 install.js（最可靠）
    found_script=$(find node_modules -name "install.js" -path "*/electron/*" -type f 2>/dev/null | head -n 1)
    if [ -n "$found_script" ] && [ -f "$found_script" ]; then
        ELECTRON_INSTALL_SCRIPT="$found_script"
    fi

    # 方法2: 如果方法1失败，尝试使用 find 的路径模式
    if [ -z "$ELECTRON_INSTALL_SCRIPT" ]; then
        POSSIBLE_PATHS=(
            "node_modules/.pnpm/electron@*/node_modules/electron/install.js"
            "node_modules/electron/install.js"
        )

        for path_pattern in "${POSSIBLE_PATHS[@]}"; do
            found_script=$(find . -path "$path_pattern" -type f 2>/dev/null | head -n 1)
            if [ -n "$found_script" ] && [ -f "$found_script" ]; then
                ELECTRON_INSTALL_SCRIPT="$found_script"
                break
            fi
        done
    fi

    if [ -z "$ELECTRON_INSTALL_SCRIPT" ]; then
        print_error "$(t electron_script_not_found)"
        print_info "$(t electron_reinstalling)"

        # 删除现有的 Electron 安装
        rm -rf node_modules/.pnpm/electron@* 2>/dev/null || true
        rm -rf node_modules/electron 2>/dev/null || true

        # 重新安装 Electron（允许构建脚本运行）
        print_info "$(t electron_reinstalling_force)"
        pnpm install electron@28.3.3 --force --ignore-scripts=false 2>&1
        INSTALL_RESULT=$?

        if [ $INSTALL_RESULT -ne 0 ]; then
            print_warning "$(t electron_reinstalling_normal)"
            pnpm install electron@28.3.3 --ignore-scripts=false 2>&1
            INSTALL_RESULT=$?
        fi

        # 安装后再次查找安装脚本（使用更可靠的方法）
        if [ $INSTALL_RESULT -eq 0 ]; then
            found_script=$(find node_modules -name "install.js" -path "*/electron/*" -type f 2>/dev/null | head -n 1)
            if [ -n "$found_script" ] && [ -f "$found_script" ]; then
                ELECTRON_INSTALL_SCRIPT="$found_script"
            fi
        fi

        if [ -z "$ELECTRON_INSTALL_SCRIPT" ]; then
            print_error "$(t electron_script_not_found)"
            print_info "$(t electron_clean_install)"
            echo "$(t electron_clean_commands)"
            echo "$(t electron_clean_commands2)"
            set -e
            return 1
        fi
    fi

    print_info "$(t electron_script_found "$ELECTRON_INSTALL_SCRIPT")"
    print_info "$(t electron_running_script)"
    node "$ELECTRON_INSTALL_SCRIPT" 2>&1 || {
        print_warning "$(t electron_script_complete)"
    }

    # 恢复 set -e
    set -e

    # 再次验证
    if check_electron; then
        print_success "$(t electron_fix_success)"
        return 0
    else
        print_error "$(t electron_fix_failed)"
        print_info "$(t electron_clean_install)"
        echo "$(t electron_clean_commands)"
        echo "$(t electron_clean_commands2)"
        return 1
    fi
}

# 安装项目依赖
install_dependencies() {
    print_step "$(t step_install_dependencies)"

    if [ -d "node_modules" ] && [ -f "pnpm-lock.yaml" ]; then
        print_info "$(t dependencies_checking)"
        # 注意：pnpm 可能会忽略构建脚本，我们需要确保 Electron 的安装脚本能运行
        pnpm install || {
            print_error "$(t dependencies_install_failed)"
            exit 1
        }
    else
        print_info "$(t dependencies_installing)"
        pnpm install || {
            print_error "$(t dependencies_install_failed)"
            exit 1
        }
    fi

    # 如果 pnpm 忽略了构建脚本，我们需要手动运行 Electron 安装脚本
    if ! check_electron; then
        print_info "$(t dependencies_installing_electron)"
        found_script=$(find node_modules -name "install.js" -path "*/electron/*" -type f 2>/dev/null | head -n 1)
        if [ -n "$found_script" ] && [ -f "$found_script" ]; then
            print_info "$(t dependencies_running_electron_script)"
            node "$found_script" 2>&1 || true
        fi
    fi

    print_success "$(t dependencies_install_success)"

    # 检查 Electron 是否正常工作
    print_info "$(t electron_checking)"
    if ! check_electron; then
        print_warning "$(t electron_installing)"
        if ! fix_electron; then
            print_error "$(t electron_fix_failed)"
            print_info "$(t electron_clean_install)"
            echo "$(t electron_clean_commands)"
            echo "$(t electron_clean_commands2)"
            exit 1
        fi
    else
        print_success "$(t electron_install_normal)"
    fi
}

# 编译 TypeScript
build_typescript() {
    print_step "$(t step_build_typescript)"

    # 检查是否需要编译
    if [ ! -d "scripts" ] || [ -z "$(ls -A scripts 2>/dev/null)" ]; then
        print_info "$(t typescript_scripts_empty)"
        print_info "$(t typescript_compiling)"
        pnpm run build:ts || {
            print_warning "$(t typescript_compile_failed)"
            npx tsc || {
                print_error "$(t typescript_compile_error)"
                exit 1
            }
        }
    elif [ -f "scripts/main.js" ]; then
        print_info "$(t typescript_compiled_exists)"
    else
        print_info "$(t typescript_compiling)"
        pnpm run build:ts || {
            print_warning "$(t typescript_compile_failed)"
            npx tsc || {
                print_error "$(t typescript_compile_error)"
                exit 1
            }
        }
    fi

    # 验证编译结果
    if [ ! -f "scripts/main.js" ]; then
        print_error "$(t typescript_main_not_found)"
        print_info "$(t typescript_recompiling)"
        pnpm run build:ts || {
            print_error "$(t typescript_check_error)"
            exit 1
        }
    fi

    print_success "$(t typescript_compile_success)"
}

# 编译 Stylus
build_stylus() {
    print_step "$(t step_build_stylus)"

    # 检查是否需要编译
    if [ ! -f "styles.css" ]; then
        print_info "$(t stylus_css_not_found)"
        print_info "$(t stylus_compiling)"
        pnpm run build:stylus || {
            print_warning "$(t stylus_compile_failed)"
            npx stylus src/styles/main.styl -o styles.css || {
                print_warning "$(t stylus_compile_warning)"
            }
        }
    else
        print_info "$(t stylus_compiled_exists)"
    fi

    # 验证编译结果
    if [ -f "styles.css" ]; then
        print_success "$(t stylus_compile_success)"
    else
        print_warning "$(t stylus_css_missing)"
    fi
}

# 同步版本号
sync_version() {
    print_info "$(t version_syncing)"
    if [ -f "ninja/sync-version.js" ]; then
        node ninja/sync-version.js || {
            print_warning "$(t version_sync_failed)"
        }
    else
        print_warning "$(t version_sync_not_found)"
    fi
}

# 运行应用
run_app() {
    print_step "$(t step_start_app)"

    # 检查 Electron 是否可用
    if [ ! -d "node_modules/electron" ] && [ ! -d "node_modules/.pnpm/electron@*" ]; then
        print_error "$(t electron_not_installed)"
        exit 1
    fi

    # 最后验证 Electron 是否正常工作
    print_info "$(t electron_verifying)"
    if ! check_electron; then
        print_warning "$(t electron_verify_failed)"
        if ! fix_electron; then
            print_error "$(t electron_fix_failed)"
            echo ""
            print_info "$(t electron_clean_install)"
            echo "$(t electron_clean_commands)"
            echo "$(t electron_clean_commands2)"
            exit 1
        fi
    fi

    print_success "$(t app_all_ready)"
    echo ""
    print_info "$(t app_starting_dev)"
    echo ""

    # 运行应用（开发模式，带热重载和 DevTools）
    pnpm run dev
}

# 检查必要文件和设置权限
check_required_files() {
    print_info "$(t files_checking)"

    REQUIRED_FILES=(
        "package.json"
        "tsconfig.json"
    )

    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            print_error "$(t files_not_found "$file")"
            exit 1
        fi
    done

    print_success "$(t files_check_success)"

    # 设置脚本执行权限
    print_info "$(t files_setting_permissions)"
    chmod +x ninja/build.sh 2>/dev/null || true
    chmod +x ninja/sync-version.js 2>/dev/null || true
    chmod +x ninja/filter-tsc-output.js 2>/dev/null || true
    chmod +x ninja/restart-watch.sh 2>/dev/null || true

    # 检查并创建必要的目录
    print_info "$(t files_checking_dirs)"
    REQUIRED_DIRS=(
        "scripts"
        "src/html"
        "src/scripts"
        "src/styles"
        "src/locales"
        "src/imgs"
        "config"
    )

    for dir in "${REQUIRED_DIRS[@]}"; do
        if [ ! -d "$dir" ]; then
            print_warning "$(t files_dir_not_found "$dir")"
            mkdir -p "$dir"
        fi
    done
}

# 主函数
main() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     $(t script_title)          ║${NC}"
    echo -e "${GREEN}║           $(t script_subtitle)                    ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    echo ""

    # 检查是否为 macOS
    check_macos

    # 检查是否在项目根目录
    if [ ! -f "package.json" ]; then
        print_error "$(t error_not_root_dir)"
        exit 1
    fi

    # 检查必要文件
    check_required_files

    # 执行所有步骤
    install_node
    install_pnpm
    sync_version
    install_dependencies
    build_typescript
    build_stylus

    # 完成提示
    print_step "$(t step_complete)"
    print_success "$(t complete_all_ready)"
    echo ""
    print_info "$(t complete_commands)"
    echo -e "  ${YELLOW}pnpm start${NC}        $(t complete_command_start)"
    echo -e "  ${YELLOW}pnpm run dev${NC}     $(t complete_command_dev)"
    echo ""
}

# 运行主函数
main
