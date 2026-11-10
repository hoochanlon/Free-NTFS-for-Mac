import * as fs from 'fs';
import * as path from 'path';
import { app } from 'electron';

// 设置文件路径
function getSettingsPath(): string {
  const userDataPath = app.getPath('userData');
  return path.join(userDataPath, 'settings.json');
}

// 默认设置
const DEFAULT_SETTINGS = {
  savePassword: true,
  autoMount: false,
  startupTab: 'dependencies' as 'dependencies' | 'devices' | 'help' | 'settings',
  language: 'system' as 'zh-CN' | 'zh-TW' | 'ja' | 'en' | 'de' | 'system',
  trayMode: false, // 托盘模式，默认关闭
  autoStart: false, // 系统自启，默认关闭
  preventSleep: false, // 智能防止休眠：由标题栏三态切入
  keepAwake: false, // 标题栏一直不休眠，默认关闭
  hideIconTooltips: true,
  // 用户手动设置为只读的设备列表：
  // 优先存 volumeUuid（稳定，不会因插拔变化），拿不到时才存 disk（可能被系统复用，仅用于兼容旧数据）
  manuallyReadOnlyDevices: [] as string[]
};

export interface AppSettings {
  savePassword: boolean;
  autoMount: boolean;
  startupTab: 'dependencies' | 'devices' | 'help' | 'settings';
  language: 'zh-CN' | 'zh-TW' | 'ja' | 'en' | 'de' | 'system';
  trayMode: boolean; // 托盘模式
  autoStart: boolean; // 系统自启
  preventSleep: boolean; // 智能防止休眠
  keepAwake: boolean; // 标题栏一直不休眠
  hideIconTooltips: boolean;
  manuallyReadOnlyDevices?: string[]; // 用户手动设置为只读的设备列表
}

/**
 * 设置管理类
 */
export class SettingsManager {
  /**
   * 读取设置
   */
  static async getSettings(): Promise<AppSettings> {
    try {
      const settingsPath = getSettingsPath();
      if (fs.existsSync(settingsPath)) {
        const data = await fs.promises.readFile(settingsPath, 'utf-8');
        const settings = JSON.parse(data);
        const { windowWidth: _w, windowHeight: _h, enableLogs: _enableLogs, ...rest } = settings;
        if ((rest as { startupTab?: string }).startupTab === 'logs') {
          rest.startupTab = 'dependencies';
        }
        return { ...DEFAULT_SETTINGS, ...rest };
      }
      return { ...DEFAULT_SETTINGS };
    } catch (error) {
      console.error('读取设置失败:', error);
      return { ...DEFAULT_SETTINGS };
    }
  }

  /**
   * 保存设置
   */
  static async saveSettings(settings: Partial<AppSettings>): Promise<void> {
    try {
      const currentSettings = await this.getSettings();
      const newSettings = { ...currentSettings, ...settings };
      const settingsPath = getSettingsPath();
      await fs.promises.writeFile(settingsPath, JSON.stringify(newSettings, null, 2), 'utf-8');
    } catch (error) {
      console.error('保存设置失败:', error);
      throw new Error(`保存设置失败: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  /**
   * 获取特定设置项
   */
  static async getSetting<K extends keyof AppSettings>(key: K): Promise<AppSettings[K]> {
    const settings = await this.getSettings();
    return settings[key];
  }

  /**
   * 设置特定设置项
   */
  static async setSetting<K extends keyof AppSettings>(key: K, value: AppSettings[K]): Promise<void> {
    await this.saveSettings({ [key]: value });
  }
}
