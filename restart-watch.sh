#!/bin/bash
# 重启 TypeScript watch 进程的脚本

echo "正在停止现有的 watch 进程..."
pkill -f "tsc --watch" || true
pkill -f "filter-tsc-output.js" || true
sleep 1

echo "验证 filter-tsc-output.js 文件..."
if [ ! -f "filter-tsc-output.js" ]; then
    echo "❌ 错误: filter-tsc-output.js 文件不存在！"
    exit 1
fi

echo "✅ filter-tsc-output.js 文件存在"
echo "文件路径: $(pwd)/filter-tsc-output.js"
echo "文件大小: $(stat -f%z filter-tsc-output.js) 字节"

echo ""
echo "现在可以重新运行: pnpm run watch:ts"
