#!/bin/bash

################################################################################
# Electron 安装修复脚本
# 修复 pnpm 安装后 Electron 二进制文件缺失的问题
################################################################################

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Electron 安装修复脚本${NC}"
echo ""

# ============================================================
# 1. 检查 Electron 是否已正确安装
# ============================================================
echo -e "${YELLOW}📋 检查 Electron 安装状态...${NC}"

check_electron() {
  if node -e "require('electron')" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

if check_electron; then
  echo -e "${GREEN}✅ Electron 已正确安装${NC}"
  echo ""
  echo -e "${GREEN}无需修复，Electron 工作正常！${NC}"
  exit 0
fi

echo -e "${YELLOW}⚠️  Electron 安装异常，开始修复...${NC}"
echo ""

# ============================================================
# 2. 检查必要的文件
# ============================================================
echo -e "${YELLOW}📋 检查必要文件...${NC}"

if [ ! -f "package.json" ]; then
  echo -e "${RED}❌ 错误: 找不到 package.json${NC}"
  exit 1
fi

if ! command -v pnpm &> /dev/null; then
  echo -e "${RED}❌ 错误: 未找到 pnpm，请先安装 pnpm${NC}"
  exit 1
fi

echo -e "${GREEN}✅ 必要文件检查完成${NC}"

# ============================================================
# 3. 清理并重新安装依赖
# ============================================================
echo ""
echo -e "${YELLOW}🧹 清理并重新安装依赖...${NC}"

# 删除 node_modules
if [ -d "node_modules" ]; then
  echo -e "${YELLOW}  删除 node_modules...${NC}"
  rm -rf node_modules
fi

# 重新安装依赖
echo -e "${YELLOW}  重新安装依赖...${NC}"
pnpm install || {
  echo -e "${RED}❌ 依赖安装失败${NC}"
  exit 1
}

echo -e "${GREEN}✅ 依赖安装完成${NC}"

# ============================================================
# 4. 手动运行 Electron 安装脚本
# ============================================================
echo ""
echo -e "${YELLOW}📦 下载 Electron 二进制文件...${NC}"

# 查找 electron 的安装脚本
ELECTRON_INSTALL_SCRIPT=""

# 尝试多个可能的路径（pnpm 的路径结构）
POSSIBLE_PATHS=(
  "node_modules/.pnpm/electron@*/node_modules/electron/install.js"
  "node_modules/electron/install.js"
)

for path_pattern in "${POSSIBLE_PATHS[@]}"; do
  found_script=$(find . -path "$path_pattern" -type f 2>/dev/null | head -n 1)
  if [ -n "$found_script" ]; then
    ELECTRON_INSTALL_SCRIPT="$found_script"
    break
  fi
done

if [ -z "$ELECTRON_INSTALL_SCRIPT" ]; then
  echo -e "${RED}❌ 错误: 找不到 Electron 安装脚本${NC}"
  exit 1
fi

echo -e "${YELLOW}  运行安装脚本: $ELECTRON_INSTALL_SCRIPT${NC}"
node "$ELECTRON_INSTALL_SCRIPT" || {
  echo -e "${YELLOW}⚠️  安装脚本执行完成（可能没有输出）${NC}"
}

# ============================================================
# 5. 验证安装
# ============================================================
echo ""
echo -e "${YELLOW}🔍 验证 Electron 安装...${NC}"

if check_electron; then
  echo -e "${GREEN}✅ Electron 安装成功！${NC}"
  echo ""
  echo -e "${GREEN}✨ 修复完成！现在可以正常运行项目了${NC}"
  echo ""
  echo -e "${GREEN}可以运行:${NC}"
  echo -e "  ${YELLOW}pnpm run dev${NC}        # 开发模式"
  echo -e "  ${YELLOW}pnpm start${NC}          # 启动应用"
  echo ""
else
  echo -e "${RED}❌ Electron 安装验证失败${NC}"
  echo ""
  echo -e "${YELLOW}建议尝试以下步骤:${NC}"
  echo -e "  1. 检查网络连接"
  echo -e "  2. 清理 pnpm 缓存: ${BLUE}pnpm store prune${NC}"
  echo -e "  3. 重新运行此脚本"
  echo ""
  exit 1
fi
