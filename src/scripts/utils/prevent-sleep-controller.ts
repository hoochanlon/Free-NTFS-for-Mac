import { BrowserWindow } from 'electron';
import { caffeinateManager } from './caffeinate-manager';
import { diskIoMonitor } from './disk-io-monitor';
import { SettingsManager } from './settings';

const IDLE_HOLD_MS = 20_000;

export type PreventSleepMode = 'off' | 'always' | 'smart';

type DeviceLike = {
  disk?: string;
  isMounted?: boolean;
  isUnmounted?: boolean;
};

const NEXT_MODE: Record<PreventSleepMode, PreventSleepMode> = {
  off: 'always',
  always: 'smart',
  smart: 'off'
};

export function preventSleepModeOf(keepAwake: boolean, smart: boolean): PreventSleepMode {
  if (keepAwake) return 'always';
  if (smart) return 'smart';
  return 'off';
}

function wholeDisksOf(devices: DeviceLike[]): string[] {
  const disks = new Set<string>();
  for (const device of devices) {
    if (!device.disk || !device.isMounted || device.isUnmounted) {
      continue;
    }
    const match = device.disk.replace(/^\/dev\//, '').match(/^(disk\d+)/);
    if (match) {
      disks.add(match[1]);
    }
  }
  return [...disks].sort();
}

function broadcastKeepAwake(enabled: boolean): void {
  for (const window of BrowserWindow.getAllWindows()) {
    if (!window.isDestroyed()) {
      window.webContents.send('caffeinate-status-changed', enabled);
    }
  }
}

class PreventSleepController {
  private smartEnabled = false;
  private keepAwake = false;
  private lastActiveAt = 0;
  private idleTimer: NodeJS.Timeout | null = null;
  private disks: string[] = [];

  getMode(): PreventSleepMode {
    return preventSleepModeOf(this.keepAwake, this.smartEnabled);
  }

  isEnabled(): boolean {
    return this.keepAwake;
  }

  isSmartEnabled(): boolean {
    return this.smartEnabled;
  }

  async setMode(
    mode: PreventSleepMode,
    options?: { persist?: boolean }
  ): Promise<{ success: boolean; error?: string }> {
    const persist = options?.persist !== false;
    const keepAwake = mode === 'always';
    const smart = mode === 'smart';
    const changed = this.keepAwake !== keepAwake || this.smartEnabled !== smart;
    this.keepAwake = keepAwake;
    this.smartEnabled = smart;
    if (persist && changed) {
      try {
        await SettingsManager.saveSettings({ keepAwake, preventSleep: smart });
      } catch (error) {
        console.error('[PreventSleep] 保存防止休眠模式失败:', error);
      }
    }
    this.apply();
    broadcastKeepAwake(this.keepAwake);
    if (changed) {
      const label = mode === 'always' ? '一直不休眠' : mode === 'smart' ? '智能防止休眠' : '已关闭';
      console.log(`[PreventSleep] ${label}`);
    }
    return { success: true };
  }

  async setEnabled(
    enabled: boolean,
    options?: { persist?: boolean }
  ): Promise<{ success: boolean; error?: string }> {
    return this.setSmartEnabled(enabled, options);
  }

  async setSmartEnabled(
    enabled: boolean,
    options?: { persist?: boolean }
  ): Promise<{ success: boolean; error?: string }> {
    if (enabled) {
      return this.setMode('smart', options);
    }
    if (this.keepAwake) {
      this.smartEnabled = false;
      if (options?.persist !== false) {
        try {
          await SettingsManager.saveSettings({ preventSleep: false });
        } catch (error) {
          console.error('[PreventSleep] 保存智能防止休眠失败:', error);
        }
      }
      this.apply();
      return { success: true };
    }
    return this.setMode('off', options);
  }

  async setKeepAwake(
    enabled: boolean,
    options?: { persist?: boolean }
  ): Promise<{ success: boolean; error?: string }> {
    if (enabled) {
      return this.setMode('always', options);
    }
    if (this.smartEnabled) {
      this.keepAwake = false;
      if (options?.persist !== false) {
        try {
          await SettingsManager.saveSettings({ keepAwake: false });
        } catch (error) {
          console.error('[PreventSleep] 保存一直不休眠失败:', error);
        }
      }
      this.apply();
      broadcastKeepAwake(false);
      return { success: true };
    }
    return this.setMode('off', options);
  }

  async cycle(): Promise<{ success: boolean; isActive: boolean; mode: PreventSleepMode; error?: string }> {
    const next = NEXT_MODE[this.getMode()];
    const result = await this.setMode(next);
    return { ...result, isActive: next !== 'off', mode: next };
  }

  async toggle(): Promise<{ success: boolean; isActive: boolean; error?: string }> {
    const result = await this.cycle();
    return { success: result.success, isActive: result.isActive, error: result.error };
  }

  setDevices(devices: DeviceLike[]): void {
    this.disks = wholeDisksOf(devices);
    if (!this.keepAwake && this.smartEnabled) {
      this.syncMonitor();
    }
  }

  stop(): void {
    this.smartEnabled = false;
    this.keepAwake = false;
    this.clearIdleTimer();
    diskIoMonitor.stop();
    caffeinateManager.stop();
    this.lastActiveAt = 0;
  }

  private apply(): void {
    if (this.keepAwake) {
      this.clearIdleTimer();
      diskIoMonitor.stop();
      void this.hold('keepAwake');
      return;
    }
    if (this.smartEnabled) {
      this.syncMonitor();
      return;
    }
    this.clearIdleTimer();
    diskIoMonitor.stop();
    caffeinateManager.stop();
    this.lastActiveAt = 0;
  }

  private syncMonitor(): void {
    diskIoMonitor.start(this.disks, (active) => {
      this.onIo(active);
    });
  }

  private onIo(active: boolean): void {
    if (this.keepAwake || !this.smartEnabled) {
      return;
    }
    if (active) {
      this.lastActiveAt = Date.now();
      this.clearIdleTimer();
      void this.hold('io');
      return;
    }
    this.scheduleRelease();
  }

  private async hold(reason: 'keepAwake' | 'io'): Promise<void> {
    if (caffeinateManager.getStatus()) {
      return;
    }
    const result = await caffeinateManager.start();
    if (result.success) {
      console.log(
        reason === 'keepAwake'
          ? '[PreventSleep] 已阻止休眠（一直不休眠）'
          : '[PreventSleep] 检测到 NTFS 传输，已阻止休眠'
      );
    } else if (result.error) {
      console.error('[PreventSleep] 启动 caffeinate 失败:', result.error);
    }
  }

  private scheduleRelease(): void {
    if (this.keepAwake || this.idleTimer || !caffeinateManager.getStatus()) {
      return;
    }
    const wait = this.lastActiveAt === 0
      ? 0
      : Math.max(0, IDLE_HOLD_MS - (Date.now() - this.lastActiveAt));
    this.idleTimer = setTimeout(() => {
      this.idleTimer = null;
      if (this.keepAwake || !this.smartEnabled) {
        return;
      }
      caffeinateManager.stop();
      console.log('[PreventSleep] 传输结束，已允许休眠');
    }, wait);
  }

  private clearIdleTimer(): void {
    if (this.idleTimer) {
      clearTimeout(this.idleTimer);
      this.idleTimer = null;
    }
  }
}

export const preventSleepController = new PreventSleepController();
