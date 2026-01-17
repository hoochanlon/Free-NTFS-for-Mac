#!/bin/bash

################################################################################
# 清理构建缓存并重新打包
# 用于解决打包后出现旧版本问题
################################################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT" || {
  echo -e "${RED}❌ 错误: 无法切换到项目根目录${NC}"
  exit 1
}

echo -e "${GREEN}🧹 清理构建缓存...${NC}"

# 清理 dist 目录
if [ -d "dist" ]; then
  echo -e "${YELLOW}  删除 dist 目录...${NC}"
  rm -rf dist
fi

# 清理 electron-builder 缓存
if [ -d "${HOME}/.cache/electron-builder" ]; then
  echo -e "${YELLOW}  清理 electron-builder 缓存...${NC}"
  rm -rf "${HOME}/.cache/electron-builder"
fi

# 清理编译产物
echo -e "${YELLOW}  清理编译产物...${NC}"
if [ -f "styles.css" ]; then
  rm -f styles.css
fi

# 重新编译
echo -e "${GREEN}📦 重新编译...${NC}"
pnpm run build:all

# 重新打包
echo -e "${GREEN}🚀 开始打包...${NC}"
./ninja/build.sh "$@"

echo -e "${GREEN}✅ 完成！${NC}"
