#!/bin/bash
# 重启 TypeScript watch 进程的脚本

echo "正在停止现有的 watch 进程..."
pkill -f "tsc --watch" || true
pkill -f "filter-tsc-output.js" || true
sleep 1

# 获取项目根目录（脚本在 ninja 文件夹中）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FILTER_SCRIPT="$PROJECT_ROOT/ninja/filter-tsc-output.js"

echo "验证 filter-tsc-output.js 文件..."
if [ ! -f "$FILTER_SCRIPT" ]; then
    echo "❌ 错误: filter-tsc-output.js 文件不存在！"
    exit 1
fi

echo "✅ filter-tsc-output.js 文件存在"
echo "文件路径: $FILTER_SCRIPT"
echo "文件大小: $(stat -f%z "$FILTER_SCRIPT" 2>/dev/null || stat -c%s "$FILTER_SCRIPT" 2>/dev/null || echo "未知") 字节"

echo ""
echo "现在可以重新运行: pnpm run watch:ts"
