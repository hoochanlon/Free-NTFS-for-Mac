#!/bin/bash

################################################################################
# Free NTFS for Mac - Electron 应用打包脚本
#
# 功能说明：
#   这个脚本用于将 Electron 应用打包成 macOS 安装包（DMG 或 ZIP 格式）
#
# 打包流程：
#   1. 编译 TypeScript 代码（.ts -> .js）
#   2. 编译 Stylus 样式文件（.styl -> .css）
#   3. 使用 electron-builder 打包成 macOS 应用
#
# 使用方法：
#   基本打包: ./build.sh
#   清理后打包: ./build.sh --clean
#   仅打包 DMG: ./build.sh --dmg
#   仅打包 ZIP: ./build.sh --zip
#   明确指定 ARM64: ./build.sh --arm64（默认就是 ARM64）
#
# 输出位置：
#   打包完成后，文件会在 dist/ 目录中
################################################################################

# ============================================================
# 设置错误处理
# ============================================================
# set -e: 如果任何命令失败（返回非零退出码），立即退出脚本
# 这样可以避免在出错时继续执行，导致更多问题
set -e

# ============================================================
# 定义颜色输出（让终端输出更美观）
# ============================================================
# \033[0;32m: 绿色
# \033[1;33m: 黄色（加粗）
# \033[0m: 重置颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color（无颜色，用于重置）

# ============================================================
# 切换到项目根目录（脚本在 ninja/ 文件夹中）
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT" || {
  echo "❌ 错误: 无法切换到项目根目录"
  exit 1
}

echo -e "${GREEN}开始构建 Free NTFS for Mac...${NC}"

# ============================================================
# 初始化变量：存储用户传入的参数
# ============================================================
CLEAN=false    # 是否清理 dist 目录
TARGET=""      # 打包目标格式（dmg 或 zip）
ARCH=""        # 架构（x64 或 arm64）

# ============================================================
# 解析命令行参数
# ============================================================
# $# 是参数个数，$@ 是所有参数
# while [[ $# -gt 0 ]]: 当还有参数时继续循环
while [[ $# -gt 0 ]]; do
  case $1 in
    --clean)
      # 用户想要清理 dist 目录
      CLEAN=true
      shift  # shift 移除第一个参数，继续处理下一个
      ;;
    --dmg)
      # 用户只想打包 DMG 格式
      TARGET="dmg"
      shift
      ;;
    --zip)
      # 用户只想打包 ZIP 格式
      TARGET="zip"
      shift
      ;;
    --arm64)
      # 用户想打包 Apple Silicon 版本（默认就是 ARM64，这个选项主要用于明确指定）
      ARCH="--arm64"
      shift
      ;;
    *)
      # 未知参数，给出警告但继续执行
      echo -e "${YELLOW}未知参数: $1${NC}"
      shift
      ;;
  esac
done

# ============================================================
# 清理 dist 目录（如果用户指定了 --clean）
# ============================================================
# 清理旧的打包文件，确保重新打包时没有残留文件
if [ "$CLEAN" = true ]; then
  echo -e "${YELLOW}清理 dist 目录...${NC}"
  rm -rf dist  # 删除 dist 目录及其所有内容
fi

# ============================================================
# 同步版本号
# ============================================================
# 在编译之前，先同步版本号（从 package.json 更新到所有相关文件）
echo -e "${GREEN}同步版本号...${NC}"
pnpm run sync-version

# ============================================================
# 编译源代码
# ============================================================
# 在打包之前，需要先编译 TypeScript 和 Stylus
echo -e "${GREEN}编译 TypeScript 和 Stylus...${NC}"
# pnpm run build:all: 运行 package.json 中定义的 build:all 脚本
# 这个脚本会：
#   - 同步版本号（已在上一步完成）
#   - 编译 TypeScript (.ts -> .js)
#   - 编译 Stylus (.styl -> .css)
# 强制重新编译，确保使用最新代码
pnpm run build:stylus && pnpm run build:ts

# 验证关键文件是否已更新
if [ ! -f "styles.css" ]; then
  echo -e "${YELLOW}警告: styles.css 不存在，重新编译...${NC}"
  pnpm run build:stylus
fi

# 检查 styles.css 的修改时间，确保是最新的
if [ -f "styles.css" ]; then
  echo -e "${GREEN}✓ styles.css 已更新${NC}"
fi

# ============================================================
# 设置 Electron 下载镜像（可选）
# ============================================================
# 如果从 GitHub 下载 Electron 很慢或失败，可以取消下面的注释
# 使用国内镜像源（淘宝镜像）加速下载
# export ELECTRON_MIRROR="https://npmmirror.com/mirrors/electron/"

# ============================================================
# 开始打包
# ============================================================
echo -e "${GREEN}开始打包...${NC}"

# 设置 Electron Builder 的缓存目录
# 下载的 Electron 二进制文件会缓存到这里，下次打包时就不需要重新下载了
export ELECTRON_BUILDER_CACHE="${HOME}/.cache/electron-builder"

# ============================================================
# 根据用户参数选择打包命令
# ============================================================
# -n "$TARGET": 检查变量是否非空（用户指定了格式）
# -n "$ARCH": 检查变量是否非空（用户指定了架构）

if [ -n "$TARGET" ] && [ -n "$ARCH" ]; then
  # 用户同时指定了格式和架构
  # 例如: ./build.sh --dmg --arm64
  ELECTRON_MIRROR="${ELECTRON_MIRROR:-}" pnpm exec electron-builder --mac $TARGET $ARCH

elif [ -n "$TARGET" ]; then
  # 用户只指定了格式
  # 例如: ./build.sh --dmg
  ELECTRON_MIRROR="${ELECTRON_MIRROR:-}" pnpm exec electron-builder --mac $TARGET

elif [ -n "$ARCH" ]; then
  # 用户只指定了架构
  # 例如: ./build.sh --arm64
  ELECTRON_MIRROR="${ELECTRON_MIRROR:-}" pnpm exec electron-builder --mac $ARCH

else
  # 用户没有指定任何特殊参数，使用默认配置
  # 默认配置在 package.json 的 "build" 字段中定义
  ELECTRON_MIRROR="${ELECTRON_MIRROR:-}" pnpm exec electron-builder
fi

# ============================================================
# 打包完成，显示结果
# ============================================================
echo -e "${GREEN}打包完成！文件位于 dist 目录${NC}"
# ls -lh: 列出文件，-l 显示详细信息，-h 显示人类可读的文件大小
ls -lh dist/
