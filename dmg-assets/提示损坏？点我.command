#!/bin/bash
# Nigate - 移除 macOS 隔离属性（解决“已损坏 / 无法验证开发者”）
# 双击运行；可在 DMG 内或安装到“应用程序”后使用

set -u

APP_NAME="Nigate.app"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

candidates=(
  "/Applications/${APP_NAME}"
  "${SCRIPT_DIR}/${APP_NAME}"
  "${HOME}/Applications/${APP_NAME}"
  "${HOME}/Desktop/${APP_NAME}"
  "${HOME}/Downloads/${APP_NAME}"
)

resolve_app() {
  local path
  for path in "${candidates[@]}"; do
    if [ -d "$path" ]; then
      printf '%s\n' "$path"
      return 0
    fi
  done
  return 1
}

echo "══════════════════════════════════════"
echo "  Nigate · 解除“已损坏”限制"
echo "══════════════════════════════════════"
echo ""
echo "本脚本会移除应用的隔离属性（quarantine），"
echo "用于处理未签名分发时的“已损坏 / 无法验证开发者”提示。"
echo ""

APP_PATH="$(resolve_app || true)"

if [ -z "${APP_PATH:-}" ]; then
  echo "未找到 ${APP_NAME}。"
  echo ""
  echo "请先任选其一："
  echo "  1. 将 Nigate.app 拖到「应用程序」后再运行本脚本"
  echo "  2. 把本脚本与 Nigate.app 放在同一文件夹后双击运行"
  echo ""
  read -r -p "按回车退出..."
  exit 1
fi

echo "目标应用: ${APP_PATH}"
echo "正在移除隔离属性..."
echo ""

if xattr -cr "$APP_PATH"; then
  echo "处理完成。请重新打开 Nigate。"
  echo ""
  read -r -p "是否现在打开 Nigate？[Y/n] " answer
  case "${answer:-Y}" in
    [nN]|[nN][oO])
      ;;
    *)
      open "$APP_PATH" 2>/dev/null || true
      ;;
  esac
else
  echo "处理失败。可在「终端」手动执行："
  echo "  xattr -cr \"${APP_PATH}\""
  echo ""
  read -r -p "按回车退出..."
  exit 1
fi

echo ""
read -r -p "按回车退出..."
