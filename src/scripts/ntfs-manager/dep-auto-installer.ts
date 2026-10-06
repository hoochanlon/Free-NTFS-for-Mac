// 终端逐步安装依赖：GUI 只负责唤起，读写仍走图形界面
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
      intro: '设备读写请回到 Nigate 图形界面。本窗口只按顺序安装系统依赖。',
      wait: '请完成当前安装（系统弹窗或密码提示）。完成后将自动进入下一步，无需再点一次。',
      skip: '已安装，跳过。',
      installing: '正在安装...',
      done: '此步骤已完成。',
      fail: '此步骤失败，已停止后续安装。',
      allDone: '所有步骤已完成',
      closeHint: '按回车键关闭此窗口...',
      stepClt: 'Xcode Command Line Tools',
      stepBrew: 'Homebrew',
      stepMacfuse: 'MacFUSE',
      stepNtfs: 'ntfs-3g',
      stepFswatch: 'fswatch（可选）',
      next: '下一步',
      macfuseHint: '若系统提示内核扩展，请到「系统设置 > 隐私与安全性」批准 macFUSE。',
      brewMissing: '未检测到 Homebrew，无法继续安装后续依赖。',
      cltHint: '将弹出系统安装窗口，请按提示完成。'
    };
  }

  return {
    title: 'Nigate Dependency Installer',
    intro: 'Use the Nigate app for disk read/write. This window only installs system dependencies.',
    wait: 'Finish the current installer or password prompt. The next step will start automatically.',
    skip: 'Already installed, skipping.',
    installing: 'Installing...',
    done: 'This step is done.',
    fail: 'This step failed. Remaining steps were stopped.',
    allDone: 'All steps completed',
    closeHint: 'Press Enter to close this window...',
    stepClt: 'Xcode Command Line Tools',
    stepBrew: 'Homebrew',
    stepMacfuse: 'MacFUSE',
    stepNtfs: 'ntfs-3g',
    stepFswatch: 'fswatch (optional)',
    next: 'Next',
    macfuseHint: 'If macOS asks about a kernel extension, approve macFUSE in System Settings > Privacy & Security.',
    brewMissing: 'Homebrew was not found. Cannot install the remaining dependencies.',
    cltHint: 'A system installer window will appear. Follow the prompts to finish.'
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
MSG_STEP_CLT=${JSON.stringify(m.stepClt)}
MSG_STEP_BREW=${JSON.stringify(m.stepBrew)}
MSG_STEP_MACFUSE=${JSON.stringify(m.stepMacfuse)}
MSG_STEP_NTFS=${JSON.stringify(m.stepNtfs)}
MSG_STEP_FSWATCH=${JSON.stringify(m.stepFswatch)}
MSG_NEXT=${JSON.stringify(m.next)}
MSG_MACFUSE_HINT=${JSON.stringify(m.macfuseHint)}
MSG_BREW_MISSING=${JSON.stringify(m.brewMissing)}
MSG_CLT_HINT=${JSON.stringify(m.cltHint)}
BREW_INSTALL_URL=${JSON.stringify(brewUrl)}
BREW_PATH=""

cd "$HOME" || exit 1
export PATH="/opt/homebrew/bin:/usr/local/bin/$HOME/.homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

print_banner() {
  echo ""
  echo "------------------------------------------"
  echo "$1"
  echo "------------------------------------------"
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
  export PATH="/opt/homebrew/bin:/usr/local/bin/$HOME/.homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
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
    for formula in ntfs-3g-mac ntfs-3g; do
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
  if [ "$status" -ne 0 ]; then
    echo "$MSG_FAIL"
    return 1
  fi
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
  "$BREW_PATH" tap gromgit/homebrew-fuse && "$BREW_PATH" install ntfs-3g-mac
  status=$?
  ensure_path
  if [ "$status" -ne 0 ] || [ -z "$(find_ntfs3g || true)" ]; then
    echo "$MSG_FAIL"
    return 1
  fi
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
  "$BREW_PATH" install fswatch || true
  echo "$MSG_DONE"
}

echo ""
echo "=========================================="
echo "$MSG_TITLE"
echo "=========================================="
echo "$MSG_INTRO"
echo ""

ensure_path

if step_clt && step_brew && step_macfuse && step_ntfs3g; then
  step_fswatch || true
  echo ""
  echo "=========================================="
  echo "$MSG_ALL_DONE"
  echo "=========================================="
else
  echo ""
  echo "$MSG_FAIL"
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
