#!/bin/bash

################################################################################
# Free NTFS for Mac - 清理构建缓存并重新打包 (Multi-language Support)
#
# 设置语言: LANG=ja bash build-clean.sh (日文) 或 LANG=en bash build-clean.sh (英文)
################################################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ============================================================
# 加载多语言支持
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/build-clean-lang.sh" ]; then
	source "$SCRIPT_DIR/build-clean-lang.sh"
else
	t() { echo "$1"; }
fi

PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT" || {
  echo -e "${RED}$(t error_cd_failed)${NC}"
  exit 1
}

echo -e "${GREEN}$(t cleaning_cache)${NC}"

# 清理 dist 目录
if [ -d "dist" ]; then
  echo -e "${YELLOW}$(t deleting_dist)${NC}"
  rm -rf dist
fi

# 清理 electron-builder 缓存
if [ -d "${HOME}/.cache/electron-builder" ]; then
  echo -e "${YELLOW}$(t cleaning_electron_cache)${NC}"
  rm -rf "${HOME}/.cache/electron-builder"
fi

# 清理编译产物
echo -e "${YELLOW}$(t cleaning_build)${NC}"
if [ -f "styles.css" ]; then
  rm -f styles.css
fi

# 重新编译
echo -e "${GREEN}$(t recompiling)${NC}"
pnpm run build:all

# 重新打包
echo -e "${GREEN}$(t starting_build)${NC}"
./ninja/build.sh "$@"

echo -e "${GREEN}$(t complete)${NC}"
