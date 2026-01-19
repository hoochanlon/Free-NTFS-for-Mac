#!/bin/bash

# Git历史清理脚本
# 用于从Git历史中移除大文件，减小仓库大小
#
# ⚠️ 警告：此操作会重写Git历史，需要force push
# 执行前请确保：
# 1. 已备份仓库
# 2. 已通知所有协作者
# 3. 已创建备份分支

set -e

echo "=========================================="
echo "Git历史清理脚本"
echo "=========================================="
echo ""
echo "⚠️  警告：此操作会重写Git历史！"
echo "⚠️  执行前请确保已备份仓库并通知协作者！"
echo ""
read -p "是否继续？(yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "操作已取消"
    exit 0
fi

echo ""
echo "开始清理Git历史..."

# 方法1: 使用git filter-branch（不需要额外安装）
# 移除 .electron-cache 目录下的所有文件
echo "1. 移除 .electron-cache 目录..."
git filter-branch --force --index-filter \
  "git rm -rf --cached --ignore-unmatch .electron-cache" \
  --prune-empty --tag-name-filter cat -- --all

# 移除特定的大文件
echo "2. 移除 shell_for_helpdesk/NTFS-Pro-Installer-v1.1.1.pkg..."
git filter-branch --force --index-filter \
  "git rm -rf --cached --ignore-unmatch shell_for_helpdesk/NTFS-Pro-Installer-v1.1.1.pkg" \
  --prune-empty --tag-name-filter cat -- --all

# 清理引用
echo "3. 清理引用..."
git for-each-ref --format="delete %(refname)" refs/original | git update-ref --stdin
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo ""
echo "=========================================="
echo "清理完成！"
echo "=========================================="
echo ""
echo "请检查仓库大小："
du -sh .git
echo ""
echo "如果大小已减小，可以执行以下命令推送到远程："
echo "  git push origin --force --all"
echo "  git push origin --force --tags"
echo ""
echo "⚠️  注意：force push会影响所有协作者，请确保已通知他们！"
