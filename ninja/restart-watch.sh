#!/bin/bash

################################################################################
# Free NTFS for Mac - 重启 TypeScript watch 进程脚本 (Multi-language Support)
#
# 设置语言: LANG=ja bash restart-watch.sh (日文) 或 LANG=en bash restart-watch.sh (英文)
################################################################################

# ============================================================
# 加载多语言支持
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/restart-watch-lang.sh" ]; then
	source "$SCRIPT_DIR/restart-watch-lang.sh"
else
	t() { echo "$1"; }
fi

echo "$(t stopping)"
pkill -f "tsc --watch" || true
pkill -f "filter-tsc-output.js" || true
sleep 1

# 获取项目根目录（脚本在 ninja 文件夹中）
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FILTER_SCRIPT="$PROJECT_ROOT/ninja/filter-tsc-output.js"

echo "$(t verifying)"
if [ ! -f "$FILTER_SCRIPT" ]; then
    echo "$(t error_not_found)"
    exit 1
fi

echo "$(t file_exists)"
echo "$(t file_path "$FILTER_SCRIPT")"
FILE_SIZE=$(stat -f%z "$FILTER_SCRIPT" 2>/dev/null || stat -c%s "$FILTER_SCRIPT" 2>/dev/null || echo "$(t unknown)")
echo "$(t file_size "$FILE_SIZE")"

echo ""
echo "$(t ready)"
