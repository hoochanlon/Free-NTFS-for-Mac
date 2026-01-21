#!/bin/bash

################################################################################
# Free NTFS for Mac - Electron 应用打包脚本 (Multi-language Support)
#
# 设置语言: LANG=ja bash build.sh (日文) 或 LANG=en bash build.sh (英文)
################################################################################

set -e

# ============================================================
# 加载多语言支持
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/build-lang.sh" ]; then
	source "$SCRIPT_DIR/build-lang.sh"
else
	t() { echo "$1"; }
fi

# ============================================================
# 定义颜色输出（让终端输出更美观）
# ============================================================
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ============================================================
# 切换到项目根目录（脚本在 ninja/ 文件夹中）
# ============================================================
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT" || {
  echo "$(t error_cd_failed)"
  exit 1
}

echo -e "${GREEN}$(t starting_build)${NC}"

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
      echo -e "${YELLOW}$(t unknown_param "$1")${NC}"
      shift
      ;;
  esac
done

# ============================================================
# 清理 dist 目录（如果用户指定了 --clean）
# ============================================================
# 清理旧的打包文件，确保重新打包时没有残留文件
if [ "$CLEAN" = true ]; then
  echo -e "${YELLOW}$(t cleaning_dist)${NC}"
  rm -rf dist
fi

# ============================================================
# 检查 DMG 使用说明文件
# ============================================================
check_dmg_readme() {
  echo -e "${GREEN}$(t checking_readme)${NC}"

  if [ -f "docs/README.txt" ]; then
    echo -e "${GREEN}$(t readme_ready)${NC}"
    cp "docs/README.txt" "README.txt"
  else
    echo -e "${YELLOW}$(t warning_readme_not_found)${NC}"
    echo -e "${YELLOW}$(t readme_ensure)${NC}"
  fi
}

# 执行检查说明文件
check_dmg_readme

# ============================================================
# 检查依赖是否已安装
# ============================================================
if [ ! -d "node_modules" ]; then
  echo -e "${YELLOW}$(t warning_no_node_modules)${NC}"
  pnpm install || {
    echo -e "${RED}$(t error_install_failed)${NC}"
    exit 1
  }
fi

# ============================================================
# 同步版本号
# ============================================================
echo -e "${GREEN}$(t syncing_version)${NC}"
pnpm run sync-version

# ============================================================
# 编译源代码
# ============================================================
echo -e "${GREEN}$(t compiling)${NC}"
pnpm run build:stylus && pnpm run build:ts

# 验证关键文件是否已更新
if [ ! -f "styles.css" ]; then
  echo -e "${YELLOW}$(t warning_no_styles)${NC}"
  pnpm run build:stylus
fi

# 检查 styles.css 的修改时间，确保是最新的
if [ -f "styles.css" ]; then
  echo -e "${GREEN}$(t styles_updated)${NC}"
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
echo -e "${GREEN}$(t starting_package)${NC}"

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
echo -e "${GREEN}$(t package_complete)${NC}"

# 清理临时生成的 README.txt 文件
if [ -f "README.txt" ]; then
  rm -f "README.txt"
  echo -e "${GREEN}$(t cleaned_temp)${NC}"
fi

# ls -lh: 列出文件，-l 显示详细信息，-h 显示人类可读的文件大小
ls -lh dist/
