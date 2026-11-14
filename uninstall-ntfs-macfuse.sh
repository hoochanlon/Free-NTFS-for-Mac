#!/bin/bash
# 测试用：一键卸载 ntfs-3g 与 macFUSE，方便反复走 Nigate 依赖安装流程。
# 不卸载 Homebrew、fswatch。
#
# 用法：
#   ./uninstall-ntfs-macfuse.sh
#   ./uninstall-ntfs-macfuse.sh -y

set -u
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin"

YES=0
for arg in "$@"; do
  case "$arg" in
    -y|--yes) YES=1 ;;
    -h|--help)
      echo "用法: $0 [-y]"
      echo "卸载 ntfs-3g / ntfs-3g-mac 与 macFUSE，用于测试依赖安装。"
      exit 0
      ;;
    *)
      echo "未知参数: $arg" >&2
      echo "用法: $0 [-y]" >&2
      exit 2
      ;;
  esac
done

echo "------------------------------------------"
echo "Nigate 测试卸载：ntfs-3g + macFUSE"
echo "------------------------------------------"
echo "将卸载 Homebrew 中的 ntfs-3g / ntfs-3g-mac 与 macfuse。"
echo "会先尝试卸载当前的 macFUSE 卷，避免文件占用。"
echo

if [[ "$YES" -ne 1 ]]; then
  read -r -p "输入 y 继续：" answer
  case "$answer" in
    y|Y|yes|YES) ;;
    *) echo "已取消。"; exit 1 ;;
  esac
fi

find_brew() {
  local candidate
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return 0
  fi
  return 1
}

# 解析 `mount` 行里的挂载点（卷名可含空格）
mount_point_from_line() {
  local line="$1"
  local rest="${line#* on }"
  printf '%s\n' "${rest% (*}"
}

unmount_macfuse_volumes() {
  local line mount_point
  echo ">> 卸载 macFUSE 卷"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    mount_point="$(mount_point_from_line "$line")"
    [[ -z "$mount_point" ]] && continue
    echo "   umount $mount_point"
    /usr/sbin/diskutil unmount force "$mount_point" >/dev/null 2>&1 \
      || /sbin/umount -f "$mount_point" >/dev/null 2>&1 \
      || echo "   未能卸载 $mount_point"
  done < <(/sbin/mount | /usr/bin/awk '/\(macfuse|, macfuse| fuse[,)]/ { print }')
  /usr/bin/pkill -x ntfs-3g >/dev/null 2>&1 || true
}

brew_has_formula() {
  [[ -n "$BREW" ]] && "$BREW" list --formula --versions "$1" >/dev/null 2>&1
}

brew_has_cask() {
  [[ -n "$BREW" ]] && "$BREW" list --cask --versions "$1" >/dev/null 2>&1
}

uninstall_ntfs3g() {
  echo ">> 卸载 ntfs-3g"
  local formula
  if [[ -n "$BREW" ]]; then
    while IFS= read -r formula; do
      [[ -z "$formula" ]] && continue
      echo "   brew uninstall $formula"
      "$BREW" uninstall --formula --force --ignore-dependencies "$formula" || true
    done < <("$BREW" list --formula 2>/dev/null | /usr/bin/awk 'tolower($0) ~ /^ntfs-3g/')
    for formula in ntfs-3g-mac ntfs-3g; do
      if brew_has_formula "$formula"; then
        echo "   brew uninstall $formula"
        "$BREW" uninstall --formula --force --ignore-dependencies "$formula" || true
      fi
    done
  fi
}

uninstall_macfuse() {
  echo ">> 卸载 macFUSE"
  local cask
  if [[ -n "$BREW" ]]; then
    for cask in macfuse macfuse@dev; do
      if brew_has_cask "$cask"; then
        echo "   brew uninstall --cask $cask"
        "$BREW" uninstall --cask --force "$cask" || true
      fi
    done
  fi

  /usr/bin/sudo /sbin/kextunload -b io.macfuse.filesystems.macfuse >/dev/null 2>&1 || true

  local uninstaller
  for uninstaller in \
    /Library/Filesystems/macfuse.fs/Contents/Resources/uninstall_macfuse \
    /Library/Filesystems/macfuse.fs/Contents/Resources/uninstall_macfuse.sh
  do
    if [[ -x "$uninstaller" ]]; then
      echo "   运行 $uninstaller"
      /usr/bin/sudo "$uninstaller" || true
    fi
  done

  local leftover
  for leftover in \
    /Library/Filesystems/macfuse.fs \
    /Library/PreferencePanes/macFUSE.prefPane \
    /usr/local/lib/libfuse.dylib \
    /opt/homebrew/lib/libfuse.dylib \
    /usr/local/lib/libfuse.2.dylib \
    /opt/homebrew/lib/libfuse.2.dylib
  do
    if [[ -e "$leftover" || -L "$leftover" ]]; then
      echo "   删除残留 $leftover"
      /usr/bin/sudo /bin/rm -rf "$leftover"
    fi
  done

  local pkg
  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    echo "   pkgutil --forget $pkg"
    /usr/bin/sudo /usr/sbin/pkgutil --forget "$pkg" >/dev/null 2>&1 || true
  done < <(/usr/sbin/pkgutil --pkgs 2>/dev/null | /usr/bin/awk 'tolower($0) ~ /macfuse/')

  revoke_macfuse_system_extensions
}

# 只撤扩展登记，撤不掉「已允许开发者 Benjamin Fleischer」这条系统批准。
revoke_macfuse_system_extensions() {
  echo ">> 尝试移除 macFUSE 系统扩展登记"
  local team bundle
  while IFS= read -r team bundle; do
    [[ -z "${team:-}" || -z "${bundle:-}" ]] && continue
    echo "   systemextensionsctl uninstall $team $bundle"
    /usr/bin/sudo /usr/bin/systemextensionsctl uninstall "$team" "$bundle" || true
  done < <(
    /usr/bin/systemextensionsctl list 2>/dev/null | /usr/bin/awk '
      tolower($0) ~ /macfuse|osxfuse/ {
        team = ""; bundle = ""
        for (i = 1; i <= NF; i++) {
          if ($i ~ /^[A-Z0-9]{10}$/) team = $i
          if ($i ~ /^io\.(macfuse|osxfuse)/) {
            bundle = $i
            sub(/\(.*$/, "", bundle)
          }
        }
        if (team != "" && bundle != "") print team, bundle
      }
    '
  )
}

print_flag() {
  local label="$1"
  local found="$2"
  if [[ "$found" -eq 1 ]]; then
    echo "   [仍在] $label"
  else
    echo "   [已无] $label"
  fi
}

status_report() {
  echo
  echo ">> 检测结果（与 Nigate 依赖页同一批路径）"
  local found

  found=0
  if [[ -n "$BREW" ]] && brew_has_cask macfuse; then found=1; fi
  print_flag "brew cask macfuse" "$found"

  found=0
  if [[ -n "$BREW" ]] && { brew_has_formula ntfs-3g-mac || brew_has_formula ntfs-3g; }; then found=1; fi
  print_flag "brew formula ntfs-3g / ntfs-3g-mac" "$found"

  found=0
  if command -v ntfs-3g >/dev/null 2>&1; then found=1; fi
  print_flag "PATH 中的 ntfs-3g$(command -v ntfs-3g 2>/dev/null | sed 's/^/ /')" "$found"

  local path
  for path in \
    /Library/Filesystems/macfuse.fs/Contents/Resources/mount_macfuse \
    /Library/Filesystems/macfuse.fs/Contents/Resources/load_macfuse \
    /usr/local/lib/libfuse.dylib \
    /opt/homebrew/lib/libfuse.dylib
  do
    found=0
    if [[ -e "$path" || -L "$path" ]]; then found=1; fi
    print_flag "$path" "$found"
  done

  local ext
  ext="$(/usr/bin/systemextensionsctl list 2>/dev/null | /usr/bin/tr '[:upper:]' '[:lower:]' || true)"
  found=0
  if printf '%s\n' "$ext" | /usr/bin/grep -q -e macfuse -e fuse; then found=1; fi
  print_flag "systemextensionsctl 仍提到 fuse/macfuse" "$found"

  echo
  echo ">> 开发者批准（弹窗用这一条，不是软件文件）"
  local policy kext_loaded
  policy="$(/usr/bin/sudo /usr/bin/sqlite3 /var/db/SystemPolicyConfiguration/KextPolicy \
    "SELECT team_id, bundle_id, allowed FROM kext_policy WHERE team_id = '3T5GSNBU6W';" 2>/dev/null || true)"
  if [[ -n "$policy" ]]; then
    echo "$policy" | while IFS= read -r row; do
      echo "   KextPolicy 仍记录: $row"
    done
  else
    echo "   读不到 KextPolicy（SIP 会挡住），但不代表批准已清除。"
  fi

  kext_loaded="$(/usr/bin/kmutil showloaded 2>/dev/null | /usr/bin/awk 'tolower($0) ~ /macfuse|osxfuse|3t5gsnbu6w/ { print; found=1 } END { if (!found) exit 1 }' || true)"
  if [[ -n "$kext_loaded" ]]; then
    echo "   仍有已加载 kext:"
    echo "$kext_loaded" | /usr/bin/sed 's/^/   /'
  else
    echo "   当前没有加载中的 macFUSE kext。"
  fi

  echo
  echo "Benjamin Fleischer 的系统扩展弹窗按 Team ID 记住，卸载软件不会撤批准。"
  echo "同一台已点过允许的 Mac 上重装，一般不会再弹。要测弹窗请用安装前的虚拟机快照。"
  echo "若依赖页仍显示已安装，重启后再检查。"
}

BREW=""
if BREW="$(find_brew)"; then
  echo "Homebrew: $BREW"
else
  BREW=""
  echo "未找到 Homebrew，将只清理 macFUSE 系统残留。"
fi

echo
echo "后续步骤需要管理员权限。"
/usr/bin/sudo -v || { echo "无法获取管理员权限。"; exit 1; }

unmount_macfuse_volumes
uninstall_ntfs3g
uninstall_macfuse
status_report
echo "完成。"
