import * as fs from 'fs';
import * as path from 'path';
import { app } from 'electron';
import { WINDOW_SIZE_CONFIG } from '../../config/window-config';

// 设置文件路径
function getSettingsPath(): string {
  const userDataPath = app.getPath('userData');
  return path.join(userDataPath, 'settings.json');
}

// 导出窗口尺寸配置（从统一配置文件导入）
export { WINDOW_SIZE_CONFIG };

// 默认设置
const DEFAULT_SETTINGS = {
  savePassword: true,
  autoMount: false,
  startupTab: 'dependencies' as 'dependencies' | 'devices' | 'logs' | 'help',
  enableLogs: false,
  language: 'system' as 'zh-CN' | 'zh-TW' | 'ja' | 'en' | 'de' | 'system',
  windowWidth: WINDOW_SIZE_CONFIG.defaultWidth,
  windowHeight: WINDOW_SIZE_CONFIG.defaultHeight,
  trayMode: false, // 托盘模式，默认关闭
  autoStart: false // 系统自启，默认关闭
};

export interface AppSettings {
  savePassword: boolean;
  autoMount: boolean;
  startupTab: 'dependencies' | 'devices' | 'logs' | 'help';
  enableLogs: boolean;
  language: 'zh-CN' | 'zh-TW' | 'ja' | 'en' | 'de' | 'system';
  windowWidth: number;
  windowHeight: number;
  trayMode: boolean; // 托盘模式
  autoStart: boolean; // 系统自启
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
        // 合并默认设置，确保所有字段都存在
        return { ...DEFAULT_SETTINGS, ...settings };
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
