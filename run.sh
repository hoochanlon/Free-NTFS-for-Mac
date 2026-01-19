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

# 安装项目依赖
install_dependencies() {
    print_step "步骤 3/6: 安装项目依赖"

    if [ -d "node_modules" ] && [ -f "pnpm-lock.yaml" ]; then
        print_info "检测到已安装的依赖，检查是否需要更新..."
        pnpm install
    else
        print_info "安装项目依赖（这可能需要几分钟）..."
        pnpm install
    fi

    print_success "依赖安装完成"
}

# 编译 TypeScript
build_typescript() {
    print_step "步骤 4/6: 编译 TypeScript"

    # 检查 TypeScript 是否已安装
    if ! command_exists tsc; then
        print_info "TypeScript 未全局安装，使用项目本地版本..."
    fi

    # 检查是否需要编译
    if [ -d "scripts" ] && [ -f "scripts/main.js" ]; then
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

    # 验证编译结果
    if [ ! -f "scripts/main.js" ]; then
        print_error "编译失败：找不到 scripts/main.js"
        exit 1
    fi

    print_success "TypeScript 编译完成"
}

# 编译 Stylus
build_stylus() {
    print_step "步骤 5/6: 编译 Stylus"

    # 检查是否需要编译
    if [ -f "styles.css" ]; then
        print_info "检测到 styles.css，跳过编译..."
    else
        print_info "编译 Stylus..."
        pnpm run build:stylus || {
            print_warning "Stylus 编译失败，尝试使用本地 Stylus..."
            npx stylus src/styles/main.styl -o styles.css || {
                print_error "Stylus 编译失败"
                exit 1
            }
        }
    fi

    # 验证编译结果
    if [ ! -f "styles.css" ]; then
        print_warning "styles.css 不存在，但继续执行..."
    else
        print_success "Stylus 编译完成"
    fi
}

# 同步版本号
sync_version() {
    print_info "同步版本号..."
    if [ -f "ninja/sync-version.js" ]; then
        node ninja/sync-version.js || {
            print_warning "版本号同步失败，继续执行..."
        }
    fi
}

# 运行应用
run_app() {
    print_step "步骤 6/6: 启动应用"

    # 检查 Electron 是否可用
    if [ ! -d "node_modules/electron" ]; then
        print_error "Electron 未安装，请先运行依赖安装"
        exit 1
    fi

    print_success "所有准备工作完成！"
    echo ""
    print_info "启动 Electron 应用..."
    echo ""

    # 运行应用
    pnpm start
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
