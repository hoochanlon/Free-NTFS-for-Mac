#!/bin/bash

################################################################################
# 项目初始化脚本
# 修复 pnpm install 后运行 pnpm run dev 时的常见问题
################################################################################

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔧 开始初始化项目...${NC}"

# ============================================================
# 1. 检查必要的文件是否存在
# ============================================================
echo -e "${YELLOW}📋 检查必要文件...${NC}"

REQUIRED_FILES=(
  "package.json"
  "tsconfig.json"
  "ninja/filter-tsc-output.js"
  "ninja/sync-version.js"
  "ninja/build.sh"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [ ! -f "$file" ]; then
    echo -e "${RED}❌ 错误: 找不到文件 $file${NC}"
    exit 1
  fi
done

echo -e "${GREEN}✅ 所有必要文件都存在${NC}"

# ============================================================
# 2. 设置脚本执行权限
# ============================================================
echo -e "${YELLOW}🔐 设置脚本执行权限...${NC}"

chmod +x ninja/build.sh 2>/dev/null || true
chmod +x ninja/sync-version.js 2>/dev/null || true
chmod +x ninja/filter-tsc-output.js 2>/dev/null || true
chmod +x ninja/restart-watch.sh 2>/dev/null || true

echo -e "${GREEN}✅ 权限设置完成${NC}"

# ============================================================
# 3. 检查并创建必要的目录
# ============================================================
echo -e "${YELLOW}📁 检查目录结构...${NC}"

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
    echo -e "${YELLOW}⚠️  目录不存在，创建: $dir${NC}"
    mkdir -p "$dir"
  fi
done

echo -e "${GREEN}✅ 目录结构检查完成${NC}"

# ============================================================
# 4. 同步版本号
# ============================================================
echo -e "${YELLOW}🔄 同步版本号...${NC}"

if [ -f "ninja/sync-version.js" ]; then
  node ninja/sync-version.js || {
    echo -e "${YELLOW}⚠️  版本号同步失败，继续执行...${NC}"
  }
else
  echo -e "${YELLOW}⚠️  ninja/sync-version.js 不存在，跳过版本同步${NC}"
fi

# ============================================================
# 5. 编译 TypeScript（如果还没有编译）
# ============================================================
echo -e "${YELLOW}📝 检查 TypeScript 编译...${NC}"

if [ ! -d "scripts" ] || [ -z "$(ls -A scripts 2>/dev/null)" ]; then
  echo -e "${YELLOW}⚠️  scripts 目录为空，需要编译 TypeScript...${NC}"
  echo -e "${GREEN}📦 编译 TypeScript...${NC}"
  pnpm run build:ts || {
    echo -e "${YELLOW}⚠️  TypeScript 编译失败，但继续执行...${NC}"
  }
else
  echo -e "${GREEN}✅ TypeScript 已编译${NC}"
fi

# ============================================================
# 6. 编译 Stylus（如果还没有编译）
# ============================================================
echo -e "${YELLOW}🎨 检查 Stylus 编译...${NC}"

if [ ! -f "styles.css" ]; then
  echo -e "${YELLOW}⚠️  styles.css 不存在，需要编译 Stylus...${NC}"
  echo -e "${GREEN}📦 编译 Stylus...${NC}"
  pnpm run build:stylus || {
    echo -e "${YELLOW}⚠️  Stylus 编译失败，但继续执行...${NC}"
  }
else
  echo -e "${GREEN}✅ Stylus 已编译${NC}"
fi

# ============================================================
# 7. 检查依赖是否已安装
# ============================================================
echo -e "${YELLOW}📦 检查依赖...${NC}"

if [ ! -d "node_modules" ]; then
  echo -e "${YELLOW}⚠️  node_modules 不存在，需要安装依赖...${NC}"
  echo -e "${GREEN}📦 安装依赖...${NC}"
  pnpm install || {
    echo -e "${RED}❌ 依赖安装失败${NC}"
    exit 1
  }
else
  echo -e "${GREEN}✅ 依赖已安装${NC}"
fi

# ============================================================
# 8. 验证关键文件
# ============================================================
echo -e "${YELLOW}🔍 验证关键文件...${NC}"

# 检查主入口文件
if [ ! -f "scripts/main.js" ]; then
  echo -e "${YELLOW}⚠️  scripts/main.js 不存在，尝试编译...${NC}"
  pnpm run build:ts
fi

if [ ! -f "scripts/main.js" ]; then
  echo -e "${RED}❌ 错误: scripts/main.js 不存在，请检查 TypeScript 编译${NC}"
  exit 1
fi

echo -e "${GREEN}✅ 关键文件验证完成${NC}"

# ============================================================
# 完成
# ============================================================
echo ""
echo -e "${GREEN}✨ 项目初始化完成！${NC}"
echo ""
echo -e "${GREEN}现在可以运行:${NC}"
echo -e "  ${YELLOW}pnpm run dev${NC}        # 开发模式"
echo -e "  ${YELLOW}pnpm start${NC}          # 启动应用"
echo -e "  ${YELLOW}pnpm run build${NC}      # 构建应用"
echo ""
