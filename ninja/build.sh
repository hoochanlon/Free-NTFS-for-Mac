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

# ============================================================
# 清理函数（在脚本退出时调用）
# ============================================================
DMG_STAGING_DIR="${PROJECT_ROOT}/.dmg-staging"
DMG_STAGING_CREATED=false

cleanup_on_exit() {
  if [ "$DMG_STAGING_CREATED" = true ] && [ -d "$DMG_STAGING_DIR" ]; then
    rm -rf "$DMG_STAGING_DIR" 2>/dev/null || true
  fi

  # 清理临时 Python 目录
  if [ -d "${PROJECT_ROOT}/.temp_bin" ]; then
    rm -rf "${PROJECT_ROOT}/.temp_bin" 2>/dev/null || true
  fi
}

# 注册退出时的清理函数
trap cleanup_on_exit EXIT INT TERM

echo -e "${GREEN}$(t starting_build)${NC}"

# ============================================================
# 初始化变量：存储用户传入的参数
# ============================================================
CLEAN=false    # 是否清理 dist 目录
TARGET=""      # 打包目标格式（dmg 或 zip）

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
      shift
      ;;
    --x64|--universal)
      echo -e "${RED}Intel and universal builds are no longer supported; only Apple Silicon (arm64) is supported.${NC}"
      exit 2
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
# 准备 DMG 附加文件（独立暂存目录，不触碰根目录 README）
# ============================================================
prepare_dmg_extras() {
  echo -e "${GREEN}$(t checking_readme)${NC}"

  local readme_src="docs/README.md"
  local fix_script_src="docs/提示损坏？点我.command"
  if [ ! -f "$readme_src" ] || [ ! -f "$fix_script_src" ]; then
    echo -e "${RED}DMG 附加文件缺失，无法继续打包：${readme_src} 或 ${fix_script_src}${NC}"
    return 1
  fi

  if [ -e "$DMG_STAGING_DIR" ] || [ -L "$DMG_STAGING_DIR" ]; then
    echo -e "${RED}DMG 暂存目录已存在，为避免覆盖其内容而停止：${DMG_STAGING_DIR}${NC}"
    return 1
  fi

  mkdir "$DMG_STAGING_DIR"
  DMG_STAGING_CREATED=true
  cp "$readme_src" "$DMG_STAGING_DIR/README.md"
  cp "$fix_script_src" "$DMG_STAGING_DIR/提示损坏？点我.command"
  chmod +x "$DMG_STAGING_DIR/提示损坏？点我.command"
  echo -e "${GREEN}✓ DMG 附加文件已暂存至 ${DMG_STAGING_DIR}${NC}"
}

# ZIP 单独构建不需要 DMG 附加文件
if [ "$TARGET" != "zip" ]; then
  prepare_dmg_extras
fi

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
# 设置 Electron 下载镜像（推荐）
# ============================================================
# 在部分网络环境下直连 GitHub 可能会 EOF / 超时，因此这里默认启用 Electron 镜像。
# 如需使用官方源，可在执行前显式设置：ELECTRON_MIRROR=""
export ELECTRON_MIRROR="${ELECTRON_MIRROR:-https://npmmirror.com/mirrors/electron/}"

# 可选：指定 Electron 缓存目录（加速二次打包）
export ELECTRON_CACHE="${ELECTRON_CACHE:-${HOME}/.cache/electron}"

# ============================================================
# 修复 Python 路径（electron-builder 需要 python 命令）
# ============================================================
fix_python_path() {
  # 检查 python 命令是否可用
  if ! command -v python >/dev/null 2>&1; then
    # 如果 python 不可用，但 python3 可用，创建临时链接
    if command -v python3 >/dev/null 2>&1; then
      PYTHON3_PATH=$(command -v python3)
      # 在 PATH 最前面添加一个临时目录，创建 python 的符号链接
      TEMP_BIN_DIR="${PROJECT_ROOT}/.temp_bin"
      mkdir -p "$TEMP_BIN_DIR"
      ln -sf "$PYTHON3_PATH" "$TEMP_BIN_DIR/python" 2>/dev/null || true
      export PATH="$TEMP_BIN_DIR:$PATH"
      echo -e "${GREEN}Fixed python path: $TEMP_BIN_DIR/python -> $PYTHON3_PATH${NC}"
    fi
  fi
}

# 执行 Python 路径修复
fix_python_path

# ============================================================
# 清理可能挂载的 DMG（避免构建冲突）
# ============================================================
cleanup_mounted_dmg() {
  echo -e "${YELLOW}$(t cleaning_mounted_dmg)${NC}"

  # 方法1: 直接卸载可能存在的卷（使用 diskutil，更可靠）
  for volume in /Volumes/Nigate*; do
    if [ -d "$volume" ]; then
      echo -e "${YELLOW}Unmounting volume: $volume...${NC}"
      diskutil unmount "$volume" 2>/dev/null || diskutil unmount force "$volume" 2>/dev/null || true
    fi
  done

  # 方法2: 使用 hdiutil info 查找并卸载所有包含 "Nigate" 的 DMG
  # 只处理实际存在的设备，避免错误
  hdiutil info 2>/dev/null | grep -i "nigate" -B 5 -A 5 | grep -E "/dev/disk[0-9]+" | awk '{print $1}' | sort -u | while read disk; do
    if [ -n "$disk" ] && [ -e "$disk" ]; then
      echo -e "${YELLOW}Unmounting disk: $disk...${NC}"
      hdiutil detach "$disk" -force 2>/dev/null || true
    fi
  done

  # 方法3: 使用 diskutil 查找挂载点包含 "Nigate" 的设备
  diskutil list 2>/dev/null | grep -E "^/dev/disk[0-9]+" | awk '{print $1}' | while read disk; do
    if [ -n "$disk" ] && [ -e "$disk" ]; then
      mount_point=$(diskutil info "$disk" 2>/dev/null | grep "Mount Point:" | awk '{print $3}')
      if [ -n "$mount_point" ] && echo "$mount_point" | grep -qi "nigate"; then
        echo -e "${YELLOW}Force unmounting: $disk (mount: $mount_point)...${NC}"
        diskutil unmount force "$mount_point" 2>/dev/null || hdiutil detach "$disk" -force 2>/dev/null || true
      fi
    fi
  done

  # 等待一下确保卸载完成
  sleep 1
}

# 执行清理
cleanup_mounted_dmg

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
if [ -n "$TARGET" ]; then
  # 只构建 Apple Silicon 版本
  ELECTRON_MIRROR="${ELECTRON_MIRROR:-}" pnpm exec electron-builder --mac "$TARGET" --arm64
else
  # 默认构建 Apple Silicon 版本的所有配置目标
  ELECTRON_MIRROR="${ELECTRON_MIRROR:-}" pnpm exec electron-builder --mac --arm64
fi

# ============================================================
# 打包完成，显示结果
# ============================================================
echo -e "${GREEN}$(t package_complete)${NC}"

# DMG 附加文件由 EXIT 清理函数处理；不会改动仓库根目录 README.md。

# 清理临时 Python 目录
if [ -d "${PROJECT_ROOT}/.temp_bin" ]; then
  rm -rf "${PROJECT_ROOT}/.temp_bin"
  echo -e "${GREEN}Cleaned up temporary Python directory${NC}"
fi

# ls -lh: 列出文件，-l 显示详细信息，-h 显示人类可读的文件大小
ls -lh dist/
