// 终端自动安装系统依赖：GUI 只负责唤起，步骤与「系统依赖」标签页对齐
import { app } from 'electron';
import { execFile } from 'child_process';
import { promisify } from 'util';
import * as fs from 'fs';
import * as path from 'path';
import { SettingsManager } from '../utils/settings';

const execFileAsync = promisify(execFile);

type InstallerLang = 'zh' | 'en';

function resolveInstallerLang(settingsLanguage: string): InstallerLang {
  const raw = settingsLanguage === 'system' ? app.getLocale() : settingsLanguage;
  return raw.toLowerCase().startsWith('zh') ? 'zh' : 'en';
}

function escapeAppleScriptString(value: string): string {
  return value.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
}

function buildMessages(lang: InstallerLang) {
  if (lang === 'zh') {
    return {
      title: 'Nigate 依赖自动安装',
      intro: '将按系统依赖标签页的顺序，自动安装全部可执行步骤。设备读写请回到 Nigate。',
      wait: '如出现系统弹窗或密码提示，完成后会自动继续，不必再点一次「一键安装」。',
      skip: '已安装，跳过。',
      installing: '正在安装...',
      done: '此步骤已完成。',
      fail: '此步骤失败，已停止后续安装。',
      allDone: '所有可自动完成的步骤已结束',
      closeHint: '按回车键关闭此窗口...',
      next: '下一步',
      stepMacos: 'macOS 版本',
      stepGatekeeper: '允许任何来源（Gatekeeper）',
      stepClt: 'Xcode Command Line Tools',
      stepBrew: 'Homebrew',
      stepMacfuse: 'MacFUSE',
      stepNtfs: 'ntfs-3g',
      stepFswatch: 'fswatch（可选）',
      stepVerify: '核对安装结果',
      sudoHint: '后续安装需要管理员权限，请输入登录密码（通常只需一次）。',
      sudoFail: '未获得管理员权限，无法继续自动安装。',
      macosOk: '版本符合要求。',
      macosLow: '当前系统版本可能低于 macOS 14，仍继续安装。',
      gatekeeperHint: '正在执行 sudo spctl --master-disable。若系统要求确认，请到「系统设置 > 隐私与安全性」开启「任何来源」。',
      gatekeeperDone: 'Gatekeeper 已处理。',
      macfuseHint: '若弹出内核扩展提示，请到「系统设置 > 隐私与安全性」批准 macFUSE。',
      kextHint: 'Apple Silicon 若无法加载内核扩展：关机后长按电源键进入启动选项 → 选项 → 继续 → 实用工具 → 启动安全性实用工具，降低安全性并允许认可开发者的内核扩展。',
      fsExtHint: '请到「系统设置 > 通用 > 登录项与扩展 > 文件系统扩展」，启用 macFUSE 和 ntfs-3g。',
      brewMissing: '未检测到 Homebrew，无法继续安装后续依赖。',
      cltHint: '将弹出系统安装窗口，请按提示完成。完成后会自动进入下一步。',
      manualRemain: '以下步骤必须在系统设置中由你确认，脚本无法代替：',
      present: '已就绪',
      missing: '未就绪'
    };
  }

  return {
    title: 'Nigate Dependency Installer',
    intro: 'This window installs every automatable step from the System Dependencies tab. Use the Nigate app for disk read/write.',
    wait: 'If macOS shows a dialog or password prompt, finish it. The next step starts automatically.',
    skip: 'Already installed, skipping.',
    installing: 'Installing...',
    done: 'This step is done.',
    fail: 'This step failed. Remaining steps were stopped.',
    allDone: 'All automatable steps finished',
    closeHint: 'Press Enter to close this window...',
    next: 'Next',
    stepMacos: 'macOS version',
    stepGatekeeper: 'Allow apps from anywhere (Gatekeeper)',
    stepClt: 'Xcode Command Line Tools',
    stepBrew: 'Homebrew',
    stepMacfuse: 'MacFUSE',
    stepNtfs: 'ntfs-3g',
    stepFswatch: 'fswatch (optional)',
    stepVerify: 'Verify installation',
    sudoHint: 'Administrator access is required. Enter your login password once.',
    sudoFail: 'Administrator access was not granted. Automatic install cannot continue.',
    macosOk: 'Version meets the requirement.',
    macosLow: 'This macOS version may be below 14. Continuing anyway.',
    gatekeeperHint: 'Running sudo spctl --master-disable. If macOS asks for confirmation, enable “Anywhere” in System Settings > Privacy & Security.',
    gatekeeperDone: 'Gatekeeper step finished.',
    macfuseHint: 'If macOS asks about a kernel extension, approve macFUSE in System Settings > Privacy & Security.',
    kextHint: 'On Apple Silicon, if the kernel extension cannot load: shut down, press and hold the power button, open Startup Options > Options > Utilities > Startup Security Utility, then reduce security and allow kernel extensions from identified developers.',
    fsExtHint: 'In System Settings > General > Login Items & Extensions > File System Extensions, enable macFUSE and ntfs-3g.',
    brewMissing: 'Homebrew was not found. Cannot install the remaining dependencies.',
    cltHint: 'A system installer window will appear. After you finish it, the next step starts automatically.',
    manualRemain: 'These remaining steps must be confirmed in System Settings:',
    present: 'Ready',
    missing: 'Not ready'
  };
}

function buildInstallScript(lang: InstallerLang): string {
  const m = buildMessages(lang);
  const brewUrl = lang === 'zh'
    ? 'https://gitee.com/ineo6/homebrew-install/raw/master/install.sh'
    : 'https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh';

  return `#!/bin/bash
set -u

MSG_TITLE=${JSON.stringify(m.title)}
MSG_INTRO=${JSON.stringify(m.intro)}
MSG_WAIT=${JSON.stringify(m.wait)}
MSG_SKIP=${JSON.stringify(m.skip)}
MSG_INSTALLING=${JSON.stringify(m.installing)}
MSG_DONE=${JSON.stringify(m.done)}
MSG_FAIL=${JSON.stringify(m.fail)}
MSG_ALL_DONE=${JSON.stringify(m.allDone)}
MSG_CLOSE_HINT=${JSON.stringify(m.closeHint)}
MSG_NEXT=${JSON.stringify(m.next)}
MSG_STEP_MACOS=${JSON.stringify(m.stepMacos)}
MSG_STEP_GATEKEEPER=${JSON.stringify(m.stepGatekeeper)}
MSG_STEP_CLT=${JSON.stringify(m.stepClt)}
MSG_STEP_BREW=${JSON.stringify(m.stepBrew)}
MSG_STEP_MACFUSE=${JSON.stringify(m.stepMacfuse)}
MSG_STEP_NTFS=${JSON.stringify(m.stepNtfs)}
MSG_STEP_FSWATCH=${JSON.stringify(m.stepFswatch)}
MSG_STEP_VERIFY=${JSON.stringify(m.stepVerify)}
MSG_SUDO_HINT=${JSON.stringify(m.sudoHint)}
MSG_SUDO_FAIL=${JSON.stringify(m.sudoFail)}
MSG_MACOS_OK=${JSON.stringify(m.macosOk)}
MSG_MACOS_LOW=${JSON.stringify(m.macosLow)}
MSG_GATEKEEPER_HINT=${JSON.stringify(m.gatekeeperHint)}
MSG_GATEKEEPER_DONE=${JSON.stringify(m.gatekeeperDone)}
MSG_MACFUSE_HINT=${JSON.stringify(m.macfuseHint)}
MSG_KEXT_HINT=${JSON.stringify(m.kextHint)}
MSG_FS_EXT_HINT=${JSON.stringify(m.fsExtHint)}
MSG_BREW_MISSING=${JSON.stringify(m.brewMissing)}
MSG_CLT_HINT=${JSON.stringify(m.cltHint)}
MSG_MANUAL_REMAIN=${JSON.stringify(m.manualRemain)}
MSG_PRESENT=${JSON.stringify(m.present)}
MSG_MISSING=${JSON.stringify(m.missing)}
BREW_INSTALL_URL=${JSON.stringify(brewUrl)}
BREW_PATH=""
SUDO_KEEPALIVE_PID=""
CHANGED=0

cd "$HOME" || exit 1
export NONINTERACTIVE=1
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_ENV_HINTS=1
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

print_banner() {
  echo ""
  echo "------------------------------------------"
  echo "$1"
  echo "------------------------------------------"
}

mark_changed() {
  CHANGED=1
}

stop_sudo_keepalive() {
  if [ -n "$SUDO_KEEPALIVE_PID" ]; then
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    SUDO_KEEPALIVE_PID=""
  fi
}

start_sudo_keepalive() {
  echo "$MSG_SUDO_HINT"
  if ! sudo -v; then
    echo "$MSG_SUDO_FAIL"
    return 1
  fi
  (
    while true; do
      sudo -n true || exit 0
      sleep 50
    done
  ) 2>/dev/null &
  SUDO_KEEPALIVE_PID=$!
  trap 'stop_sudo_keepalive' EXIT
}

find_brew() {
  local candidate
  candidate=$(command -v brew 2>/dev/null)
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    printf '%s\\n' "$candidate"
    return 0
  fi
  for candidate in "$HOME/.homebrew/bin/brew" "/opt/homebrew/bin/brew" "/usr/local/bin/brew"; do
    if [ -x "$candidate" ]; then
      printf '%s\\n' "$candidate"
      return 0
    fi
  done
  return 1
}

ensure_path() {
  export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
  BREW_PATH=$(find_brew || true)
  if [ -n "$BREW_PATH" ]; then
    local brew_prefix
    brew_prefix=$(dirname "$(dirname "$BREW_PATH")")
    export PATH="$brew_prefix/bin:$brew_prefix/sbin:$PATH"
    if [ -x "$BREW_PATH" ]; then
      eval "$("$BREW_PATH" shellenv 2>/dev/null)" || true
    fi
  fi
}

clt_ready() {
  command -v swift >/dev/null 2>&1
}

find_ntfs3g() {
  local candidate formula formula_prefix
  candidate=$(command -v ntfs-3g 2>/dev/null)
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    printf '%s\\n' "$candidate"
    return 0
  fi
  for candidate in "/opt/homebrew/bin/ntfs-3g" "/usr/local/bin/ntfs-3g"; do
    if [ -x "$candidate" ]; then
      printf '%s\\n' "$candidate"
      return 0
    fi
  done
  if [ -n "$BREW_PATH" ]; then
    for formula in ntfs-3g-mac ntfs-3g gromgit/fuse/ntfs-3g-mac; do
      formula_prefix=$("$BREW_PATH" --prefix "$formula" 2>/dev/null || true)
      for candidate in "$formula_prefix/bin/ntfs-3g" "$formula_prefix/sbin/ntfs-3g"; do
        if [ -x "$candidate" ]; then
          printf '%s\\n' "$candidate"
          return 0
        fi
      done
    done
  fi
  return 1
}

macfuse_present() {
  if [ -x "/Library/Filesystems/macfuse.fs/Contents/Resources/mount_macfuse" ]; then
    return 0
  fi
  if [ -e "/usr/local/lib/libfuse.dylib" ] || [ -e "/opt/homebrew/lib/libfuse.dylib" ]; then
    return 0
  fi
  if [ -n "$BREW_PATH" ] && "$BREW_PATH" list --cask macfuse >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

macfuse_needs_work() {
  if ! macfuse_present; then
    return 0
  fi
  if [ -n "$BREW_PATH" ] && "$BREW_PATH" list --cask macfuse >/dev/null 2>&1; then
    local outdated
    outdated=$(HOMEBREW_NO_AUTO_UPDATE=1 "$BREW_PATH" outdated --cask --greedy macfuse 2>/dev/null || true)
    if [ -n "$outdated" ]; then
      return 0
    fi
  fi
  return 1
}

open_privacy_settings() {
  open "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension" >/dev/null 2>&1 \\
    || open "x-apple.systempreferences:com.apple.preference.security" >/dev/null 2>&1 \\
    || true
}

open_login_items() {
  open "x-apple.systempreferences:com.apple.LoginItems-Settings.extension" >/dev/null 2>&1 || true
}

step_macos() {
  print_banner "$MSG_NEXT: $MSG_STEP_MACOS"
  local version major
  version=$(sw_vers -productVersion 2>/dev/null || echo "")
  if [ -z "$version" ]; then
    echo "$MSG_MACOS_LOW"
    return 0
  fi
  echo "$version"
  major=$(echo "$version" | cut -d. -f1)
  if [ "$major" -ge 14 ] 2>/dev/null; then
    echo "$MSG_MACOS_OK"
  else
    echo "$MSG_MACOS_LOW"
  fi
}

step_gatekeeper() {
  print_banner "$MSG_NEXT: $MSG_STEP_GATEKEEPER"
  echo "$MSG_GATEKEEPER_HINT"
  sudo spctl --master-disable || true
  echo "$MSG_GATEKEEPER_DONE"
}

step_clt() {
  print_banner "$MSG_NEXT: $MSG_STEP_CLT"
  if clt_ready; then
    echo "$MSG_SKIP"
    return 0
  fi
  echo "$MSG_CLT_HINT"
  echo "$MSG_INSTALLING"
  xcode-select --install 2>/dev/null || true
  echo "$MSG_WAIT"
  while ! clt_ready; do
    sleep 5
  done
  mark_changed
  echo "$MSG_DONE"
}

step_brew() {
  print_banner "$MSG_NEXT: $MSG_STEP_BREW"
  ensure_path
  if [ -n "$BREW_PATH" ]; then
    echo "$MSG_SKIP"
    return 0
  fi
  echo "$MSG_INSTALLING"
  echo "$MSG_WAIT"
  if /bin/bash -c "$(curl -fsSL "$BREW_INSTALL_URL")"; then
    ensure_path
    if [ -z "$BREW_PATH" ]; then
      echo "$MSG_BREW_MISSING"
      return 1
    fi
    mark_changed
    echo "$MSG_DONE"
    return 0
  fi
  echo "$MSG_FAIL"
  return 1
}

step_macfuse() {
  print_banner "$MSG_NEXT: $MSG_STEP_MACFUSE"
  ensure_path
  if [ -z "$BREW_PATH" ]; then
    echo "$MSG_BREW_MISSING"
    return 1
  fi
  if ! macfuse_needs_work; then
    echo "$MSG_SKIP"
    return 0
  fi
  echo "$MSG_MACFUSE_HINT"
  echo "$MSG_INSTALLING"
  echo "$MSG_WAIT"
  local status=0
  if "$BREW_PATH" list --cask macfuse >/dev/null 2>&1; then
    "$BREW_PATH" upgrade --cask --greedy macfuse
    status=$?
  else
    "$BREW_PATH" install --cask macfuse
    status=$?
  fi
  if [ "$status" -ne 0 ] && ! macfuse_present; then
    echo "$MSG_FAIL"
    return 1
  fi
  mark_changed
  echo "$MSG_DONE"
}

step_ntfs3g() {
  print_banner "$MSG_NEXT: $MSG_STEP_NTFS"
  ensure_path
  if [ -z "$BREW_PATH" ]; then
    echo "$MSG_BREW_MISSING"
    return 1
  fi
  if [ -n "$(find_ntfs3g || true)" ]; then
    echo "$MSG_SKIP"
    return 0
  fi
  echo "$MSG_INSTALLING"
  echo "$MSG_WAIT"
  local status=0
  "$BREW_PATH" tap gromgit/homebrew-fuse && "$BREW_PATH" install gromgit/fuse/ntfs-3g-mac
  status=$?
  ensure_path
  if [ "$status" -ne 0 ] || [ -z "$(find_ntfs3g || true)" ]; then
    echo "$MSG_FAIL"
    return 1
  fi
  mark_changed
  echo "$MSG_DONE"
}

step_fswatch() {
  print_banner "$MSG_NEXT: $MSG_STEP_FSWATCH"
  ensure_path
  if command -v fswatch >/dev/null 2>&1; then
    echo "$MSG_SKIP"
    return 0
  fi
  if [ -z "$BREW_PATH" ]; then
    echo "$MSG_SKIP"
    return 0
  fi
  echo "$MSG_INSTALLING"
  if "$BREW_PATH" install fswatch; then
    mark_changed
  fi
  echo "$MSG_DONE"
}

step_verify() {
  print_banner "$MSG_STEP_VERIFY"
  ensure_path
  local macos_version macos_state clt_state brew_state fuse_state ntfs_state fswatch_state
  macos_version=$(sw_vers -productVersion 2>/dev/null || echo "?")
  macos_state="$MSG_MISSING"
  if [ "$(echo "$macos_version" | cut -d. -f1)" -ge 14 ] 2>/dev/null; then
    macos_state="$MSG_PRESENT"
  fi
  if clt_ready; then clt_state="$MSG_PRESENT"; else clt_state="$MSG_MISSING"; fi
  if [ -n "$BREW_PATH" ]; then brew_state="$MSG_PRESENT"; else brew_state="$MSG_MISSING"; fi
  if macfuse_present; then fuse_state="$MSG_PRESENT"; else fuse_state="$MSG_MISSING"; fi
  if [ -n "$(find_ntfs3g || true)" ]; then ntfs_state="$MSG_PRESENT"; else ntfs_state="$MSG_MISSING"; fi
  if command -v fswatch >/dev/null 2>&1; then fswatch_state="$MSG_PRESENT"; else fswatch_state="$MSG_MISSING"; fi
  echo "macOS $macos_version: $macos_state"
  echo "CLT: $clt_state"
  echo "Homebrew: $brew_state"
  echo "MacFUSE: $fuse_state"
  echo "ntfs-3g: $ntfs_state"
  echo "fswatch: $fswatch_state"
}

echo ""
echo "=========================================="
echo "$MSG_TITLE"
echo "=========================================="
echo "$MSG_INTRO"
echo "$MSG_WAIT"
echo ""

ensure_path

if start_sudo_keepalive \\
  && step_macos \\
  && step_gatekeeper \\
  && step_clt \\
  && step_brew \\
  && step_macfuse \\
  && step_ntfs3g; then
  step_fswatch || true
  step_verify || true
  echo ""
  echo "=========================================="
  echo "$MSG_ALL_DONE"
  echo "=========================================="
  echo ""
  echo "$MSG_MANUAL_REMAIN"
  echo "$MSG_KEXT_HINT"
  echo "$MSG_FS_EXT_HINT"
  if [ "$CHANGED" -ne 0 ]; then
    open_privacy_settings
    open_login_items
  fi
else
  echo ""
  echo "$MSG_FAIL"
  step_verify || true
fi

echo ""
read -r -p "$MSG_CLOSE_HINT"
`;
}

export async function openDependencyInstaller(): Promise<{ success: boolean; error?: string }> {
  try {
    const settings = await SettingsManager.getSettings();
    const lang = resolveInstallerLang(settings.language);
    const scriptPath = path.join(app.getPath('temp'), 'nigate-install-deps.sh');
    await fs.promises.writeFile(scriptPath, buildInstallScript(lang), 'utf8');
    await fs.promises.chmod(scriptPath, 0o755);

    const escaped = escapeAppleScriptString(scriptPath);
    await execFileAsync('osascript', [
      '-e', 'tell application "Terminal"',
      '-e', 'activate',
      '-e', `do script "exec /bin/bash \\"${escaped}\\""`,
      '-e', 'end tell'
    ]);

    return { success: true };
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    return { success: false, error: errorMessage };
  }
}
