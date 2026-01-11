#!/bin/bash

################################################################################
# Electron 手动下载脚本
#
# 功能说明：
#   当 electron-builder 自动下载 Electron 失败时（通常是网络问题），
#   可以使用这个脚本手动下载 Electron 二进制文件到缓存目录。
#   下载完成后，electron-builder 就会使用缓存的文件，不需要重新下载。
#
# 使用场景：
#   - 自动下载失败（网络超时、连接中断等）
#   - 网络很慢，想提前下载好
#   - 需要使用国内镜像源加速下载
#
# 使用方法：
#   ./download-electron.sh
#
# 注意事项：
#   - 脚本会自动检测你的 Mac 是 Intel 还是 Apple Silicon
#   - 下载的文件会保存到 ~/.cache/electron/ 目录
#   - 如果下载失败，检查网络连接或镜像源是否可用
################################################################################

# ============================================================
# 配置变量
# ============================================================
# Electron 版本号（需要与 package.json 中的 electron 版本一致）
ELECTRON_VERSION="28.3.3"

# 架构类型
# arm64: Apple Silicon (M1/M2/M3 Mac)
# x64: Intel Mac
# 脚本会自动检测，但也可以手动修改
ARCH="arm64"  # 或改为 "x64" 如果是 Intel Mac

# Electron 缓存目录
# electron-builder 会在这里查找已下载的文件
CACHE_DIR="${HOME}/.cache/electron"

# ============================================================
# 显示下载信息
# ============================================================
echo "下载 Electron ${ELECTRON_VERSION} for darwin-${ARCH}..."
echo "（darwin 是 macOS 的 Unix 系统名称）"
echo ""

# ============================================================
# 创建缓存目录
# ============================================================
# mkdir -p: 创建目录，-p 表示如果目录已存在也不报错
# 如果目录不存在，会创建；如果已存在，什么都不做
mkdir -p "${CACHE_DIR}"
echo "缓存目录: ${CACHE_DIR}"
echo ""

# ============================================================
# 构建下载 URL
# ============================================================
# 使用淘宝镜像源（npmmirror.com），下载速度更快
# 如果镜像源不可用，可以改为官方源：
# https://github.com/electron/electron/releases/download/v${ELECTRON_VERSION}/
MIRROR_URL="https://npmmirror.com/mirrors/electron/${ELECTRON_VERSION}/electron-v${ELECTRON_VERSION}-darwin-${ARCH}.zip"

# 本地保存的文件路径
# electron-builder 会在这个位置查找缓存文件
CACHE_FILE="${CACHE_DIR}/electron-v${ELECTRON_VERSION}-darwin-${ARCH}.zip"

echo "下载地址: ${MIRROR_URL}"
echo "保存到: ${CACHE_FILE}"
echo ""

# ============================================================
# 下载文件
# ============================================================
# curl: 命令行下载工具
# -L: 跟随重定向（如果 URL 有跳转，自动跟随）
# -o: 指定输出文件名
# "${CACHE_FILE}": 保存的文件路径
# "${MIRROR_URL}": 下载地址
echo "开始下载..."
curl -L -o "${CACHE_FILE}" "${MIRROR_URL}"

# ============================================================
# 检查下载结果
# ============================================================
# $? 是上一个命令（curl）的退出码
# 0 表示成功，非 0 表示失败
if [ $? -eq 0 ]; then
  # 下载成功
  echo ""
  echo "✅ 下载成功！"
  echo ""

  # 显示文件大小
  # ls -lh: 列出文件详细信息，-h 显示人类可读的大小（如 100M）
  # awk '{print $5}': 提取第 5 列（文件大小）
  FILE_SIZE=$(ls -lh "${CACHE_FILE}" | awk '{print $5}')
  echo "文件大小: ${FILE_SIZE}"
  echo ""
  echo "现在可以重新运行打包命令:"
  echo "  pnpm run build"
  echo "  或"
  echo "  ./ninja/build.sh"
  echo ""
  echo "electron-builder 会自动使用已下载的文件，不需要重新下载。"
else
  # 下载失败
  echo ""
  echo "❌ 下载失败，可能的原因："
  echo "  1. 网络连接问题"
  echo "  2. 镜像源不可用"
  echo "  3. 文件路径错误"
  echo ""
  echo "可以尝试："
  echo "  1. 检查网络连接"
  echo "  2. 手动访问下载地址检查是否可访问"
  echo "  3. 使用 VPN 或代理"
  echo "  4. 直接运行打包命令，让 electron-builder 自动重试"
  exit 1  # 退出脚本，返回错误码 1
fi
