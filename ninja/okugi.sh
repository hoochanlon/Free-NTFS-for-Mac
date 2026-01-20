#!/bin/bash

################################################################################
# Free NTFS for Mac - Git历史清理脚本 (Multi-language Support)
#
# 设置语言: LANG=ja bash okugi.sh (日文) 或 LANG=en bash okugi.sh (英文)
################################################################################

set -e

# ============================================================
# 加载多语言支持
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/okugi-lang.sh" ]; then
	source "$SCRIPT_DIR/okugi-lang.sh"
else
	t() { echo "$1"; }
fi

echo "=========================================="
echo "$(t title)"
echo "=========================================="
echo ""
echo "$(t warning_rewrite)"
echo "$(t warning_backup)"
echo ""
read -p "$(t confirm)" confirm

if [ "$confirm" != "yes" ]; then
    echo "$(t cancelled)"
    exit 0
fi

echo ""
echo "$(t starting)"

# 方法1: 使用git filter-branch（不需要额外安装）
# 移除 .electron-cache 目录下的所有文件
echo "$(t step1)"
git filter-branch --force --index-filter \
  "git rm -rf --cached --ignore-unmatch .electron-cache" \
  --prune-empty --tag-name-filter cat -- --all

# 移除特定的大文件
echo "$(t step2)"
git filter-branch --force --index-filter \
  "git rm -rf --cached --ignore-unmatch shell_for_helpdesk/NTFS-Pro-Installer-v1.1.1.pkg" \
  --prune-empty --tag-name-filter cat -- --all

# 清理引用
echo "$(t step3)"
git for-each-ref --format="delete %(refname)" refs/original | git update-ref --stdin
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo ""
echo "=========================================="
echo "$(t complete)"
echo "=========================================="
echo ""
echo "$(t check_size)"
du -sh .git
echo ""
echo "$(t if_reduced)"
echo "  git push origin --force --all"
echo "  git push origin --force --tags"
echo ""
echo "$(t force_push_warning)"
