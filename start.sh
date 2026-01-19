#!/bin/bash

################################################################################
# 一键运行脚本 - 自动检测并安装所有必要的工具
# 适用于 macOS 系统，完全没有 npm、pnpm、ts、styl 环境的用户
################################################################################

set -e

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
        print_error "此脚本仅支持 macOS 系统"
        exit 1
    fi
}

# 安装 Node.js
install_node() {
    print_step "步骤 1/6: 检查 Node.js"

    if check_node_version; then
        print_success "Node.js 已安装: $(node -v)"
        return 0
    fi

    print_warning "未检测到 Node.js 或版本过低（需要 >= 16）"

    if command_exists brew; then
        print_info "使用 Homebrew 安装 Node.js..."
        brew install node
    else
        print_warning "未检测到 Homebrew"
        echo ""
        print_info "正在安装 Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # 配置 PATH（Apple Silicon Mac）
        if [ -f "/opt/homebrew/bin/brew" ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi

        print_info "使用 Homebrew 安装 Node.js..."
        brew install node
    fi

    # 验证安装
    if ! check_node_version; then
        print_error "Node.js 安装失败或版本不正确"
        exit 1
    fi

    print_success "Node.js 安装成功: $(node -v)"
}

# 安装 pnpm
install_pnpm() {
    print_step "步骤 2/6: 检查 pnpm"

    if command_exists pnpm; then
        print_success "pnpm 已安装: $(pnpm -v)"
        return 0
    fi

    print_warning "未检测到 pnpm，正在安装..."

    # macOS 上优先使用 npm 安装 pnpm
    if command_exists npm; then
        print_info "使用 npm 安装 pnpm..."
        npm install -g pnpm@latest
    else
        print_error "未检测到 npm，请先安装 Node.js"
        exit 1
    fi

    # 验证安装
    if ! command_exists pnpm; then
        print_error "pnpm 安装失败，请手动安装："
        echo "  npm install -g pnpm"
        exit 1
    fi

    print_success "pnpm 安装成功: $(pnpm -v)"
}

# 检查 Electron 是否正常工作
check_electron() {
    if node -e "require('electron')" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# 修复 Electron 安装（参考 fix-electron.sh）
fix_electron() {
    print_warning "Electron 安装异常，正在修复..."

    # 临时禁用 set -e，允许错误处理
    set +e

    # 查找 Electron 安装脚本（参考 fix-electron.sh 的方法）
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
        print_error "找不到 Electron 安装脚本"
        print_info "尝试重新安装 Electron..."

        # 删除现有的 Electron 安装
        rm -rf node_modules/.pnpm/electron@* 2>/dev/null || true
        rm -rf node_modules/electron 2>/dev/null || true

        # 重新安装 Electron（允许构建脚本运行）
        print_info "重新安装 Electron（允许构建脚本）..."
        pnpm install electron@28.3.3 --force --ignore-scripts=false 2>&1
        INSTALL_RESULT=$?

        if [ $INSTALL_RESULT -ne 0 ]; then
            print_warning "强制安装失败，尝试普通安装..."
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
            print_error "重新安装后仍找不到 Electron 安装脚本"
            print_info "建议手动运行修复脚本: ./ninja/fix-electron.sh"
            set -e
            return 1
        fi
    fi

    print_info "找到 Electron 安装脚本: $ELECTRON_INSTALL_SCRIPT"
    print_info "运行 Electron 安装脚本（下载二进制文件）..."
    node "$ELECTRON_INSTALL_SCRIPT" 2>&1 || {
        print_warning "安装脚本执行完成（可能没有输出）"
    }

    # 恢复 set -e
    set -e

    # 再次验证
    if check_electron; then
        print_success "Electron 修复成功"
        return 0
    else
        print_error "Electron 修复失败"
        print_info "建议手动运行修复脚本: ./ninja/fix-electron.sh"
        return 1
    fi
}

# 安装项目依赖（参考 setup.sh）
install_dependencies() {
    print_step "步骤 3/6: 安装项目依赖"

    if [ -d "node_modules" ] && [ -f "pnpm-lock.yaml" ]; then
        print_info "检测到已安装的依赖，检查是否需要更新..."
        # 注意：pnpm 可能会忽略构建脚本，我们需要确保 Electron 的安装脚本能运行
        pnpm install || {
            print_error "依赖安装失败"
            exit 1
        }
    else
        print_info "安装项目依赖（这可能需要几分钟）..."
        pnpm install || {
            print_error "依赖安装失败"
            exit 1
        }
    fi

    # 如果 pnpm 忽略了构建脚本，我们需要手动运行 Electron 安装脚本
    if ! check_electron; then
        print_info "检测到 Electron 可能未正确安装，尝试运行安装脚本..."
        found_script=$(find node_modules -name "install.js" -path "*/electron/*" -type f 2>/dev/null | head -n 1)
        if [ -n "$found_script" ] && [ -f "$found_script" ]; then
            print_info "运行 Electron 安装脚本..."
            node "$found_script" 2>&1 || true
        fi
    fi

    print_success "依赖安装完成"

    # 检查 Electron 是否正常工作（参考 fix-electron.sh）
    print_info "检查 Electron 安装..."
    if ! check_electron; then
        print_warning "Electron 安装异常，尝试修复..."
        if ! fix_electron; then
            print_error "Electron 修复失败"
            print_info "可以尝试手动运行: ./ninja/fix-electron.sh"
            exit 1
        fi
    else
        print_success "Electron 安装正常"
    fi
}

# 编译 TypeScript（参考 setup.sh）
build_typescript() {
    print_step "步骤 4/6: 编译 TypeScript"

    # 检查是否需要编译（参考 setup.sh）
    if [ ! -d "scripts" ] || [ -z "$(ls -A scripts 2>/dev/null)" ]; then
        print_info "scripts 目录为空，需要编译 TypeScript..."
        print_info "编译 TypeScript..."
        pnpm run build:ts || {
            print_warning "TypeScript 编译失败，尝试使用本地 TypeScript..."
            npx tsc || {
                print_error "TypeScript 编译失败"
                exit 1
            }
        }
    elif [ -f "scripts/main.js" ]; then
        print_info "检测到已编译的文件，跳过编译..."
    else
        print_info "编译 TypeScript..."
        pnpm run build:ts || {
            print_warning "TypeScript 编译失败，尝试使用本地 TypeScript..."
            npx tsc || {
                print_error "TypeScript 编译失败"
                exit 1
            }
        }
    fi

    # 验证编译结果（参考 setup.sh）
    if [ ! -f "scripts/main.js" ]; then
        print_error "编译失败：找不到 scripts/main.js"
        print_info "尝试重新编译..."
        pnpm run build:ts || {
            print_error "TypeScript 编译失败，请检查错误信息"
            exit 1
        }
    fi

    print_success "TypeScript 编译完成"
}

# 编译 Stylus（参考 setup.sh）
build_stylus() {
    print_step "步骤 5/6: 编译 Stylus"

    # 检查是否需要编译（参考 setup.sh）
    if [ ! -f "styles.css" ]; then
        print_info "styles.css 不存在，需要编译 Stylus..."
        print_info "编译 Stylus..."
        pnpm run build:stylus || {
            print_warning "Stylus 编译失败，尝试使用本地 Stylus..."
            npx stylus src/styles/main.styl -o styles.css || {
                print_warning "Stylus 编译失败，但继续执行..."
            }
        }
    else
        print_info "检测到 styles.css，跳过编译..."
    fi

    # 验证编译结果
    if [ -f "styles.css" ]; then
        print_success "Stylus 编译完成"
    else
        print_warning "styles.css 不存在，但继续执行..."
    fi
}

# 同步版本号（参考 setup.sh）
sync_version() {
    print_info "同步版本号..."
    if [ -f "ninja/sync-version.js" ]; then
        node ninja/sync-version.js || {
            print_warning "版本号同步失败，继续执行..."
        }
    else
        print_warning "ninja/sync-version.js 不存在，跳过版本同步"
    fi
}

# 运行应用
run_app() {
    print_step "步骤 6/6: 启动应用"

    # 检查 Electron 是否可用
    if [ ! -d "node_modules/electron" ] && [ ! -d "node_modules/.pnpm/electron@*" ]; then
        print_error "Electron 未安装，请先运行依赖安装"
        exit 1
    fi

    # 最后验证 Electron 是否正常工作
    print_info "最后验证 Electron..."
    if ! check_electron; then
        print_warning "Electron 验证失败，尝试修复..."
        if ! fix_electron; then
            print_error "Electron 修复失败"
            echo ""
            print_info "请尝试手动修复："
            echo "  ./ninja/fix-electron.sh"
            echo ""
            print_info "或者清理后重新安装："
            echo "  rm -rf node_modules"
            echo "  pnpm install"
            exit 1
        fi
    fi

    print_success "所有准备工作完成！"
    echo ""
    print_info "启动 Electron 应用..."
    echo ""

    # 运行应用
    pnpm start
}

# 检查必要文件（参考 setup.sh）
check_required_files() {
    print_info "检查必要文件..."

    REQUIRED_FILES=(
        "package.json"
        "tsconfig.json"
    )

    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            print_error "找不到文件: $file"
            exit 1
        fi
    done

    print_success "必要文件检查完成"
}

# 主函数
main() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     Free NTFS for Mac - 一键运行脚本          ║${NC}"
    echo -e "${GREEN}║           仅支持 macOS 系统                    ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    echo ""

    # 检查是否为 macOS
    check_macos

    # 检查是否在项目根目录
    if [ ! -f "package.json" ]; then
        print_error "请在项目根目录运行此脚本"
        exit 1
    fi

    # 检查必要文件（参考 setup.sh）
    check_required_files

    # 执行所有步骤
    install_node
    install_pnpm
    sync_version
    install_dependencies
    build_typescript
    build_stylus
    run_app
}

# 运行主函数
main
