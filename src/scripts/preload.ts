import { contextBridge, ipcRenderer } from 'electron';
import type { ElectronAPI } from '../types/electron';

const electronAPI: ElectronAPI = {
  checkDependencies: () => ipcRenderer.invoke('check-dependencies'),
  getNTFSDevices: () => ipcRenderer.invoke('get-ntfs-devices'),
  mountDevice: (device) => ipcRenderer.invoke('mount-device', device),
  unmountDevice: (device) => ipcRenderer.invoke('unmount-device', device),
  restoreToReadOnly: (device) => ipcRenderer.invoke('restore-to-readonly', device),
  ejectDevice: (device) => ipcRenderer.invoke('eject-device', device),
  // 已移除自动安装功能
  // installDependencies: () => ipcRenderer.invoke('install-dependencies'),
  requestSudoPassword: () => ipcRenderer.invoke('request-sudo-password'),
  onDeviceUpdate: (callback) => {
    ipcRenderer.on('device-update', (event, data) => callback(data));
  },
  openLogsWindow: () => ipcRenderer.invoke('open-logs-window'),
  closeLogsWindow: () => ipcRenderer.invoke('close-logs-window'),
  openModuleWindow: (moduleName: string) => ipcRenderer.invoke('open-module-window', moduleName),
  closeModuleWindow: () => ipcRenderer.invoke('close-module-window'),
  readMarkdown: (filename: string) => ipcRenderer.invoke('read-markdown', filename),
  openAboutWindow: () => ipcRenderer.invoke('open-about-window'),
  openExternal: (url: string) => ipcRenderer.invoke('open-external', url),
  broadcastThemeChange: (isLightMode: boolean) => ipcRenderer.invoke('broadcast-theme-change', isLightMode),
  onThemeChange: (callback: (isLightMode: boolean) => void) => {
    ipcRenderer.on('theme-changed', (event, isLightMode: boolean) => callback(isLightMode));
  },
  getSettings: () => ipcRenderer.invoke('get-settings'),
  saveSettings: (settings: Partial<import('../types/electron').AppSettings>) => ipcRenderer.invoke('save-settings', settings),
  onSettingsChange: (callback: (settings: Partial<import('../types/electron').AppSettings>) => void) => {
    ipcRenderer.on('settings-changed', (event, settings: Partial<import('../types/electron').AppSettings>) => callback(settings));
  },
  hasSavedPassword: () => ipcRenderer.invoke('has-saved-password'),
  deleteSavedPassword: () => ipcRenderer.invoke('delete-saved-password'),
  exportLogs: (content: string) => ipcRenderer.invoke('export-logs', content),
  switchToTab: (tabName: string) => ipcRenderer.invoke('switch-to-tab', tabName),
  onSwitchTab: (callback: (tabName: string) => void) => {
    ipcRenderer.on('switch-tab', (event, tabName: string) => callback(tabName));
  },
  onShowAboutDialog: (callback: () => void) => {
    ipcRenderer.on('show-about-dialog', () => callback());
  },
  onTrayAction: (callback: (action: string) => void) => {
    ipcRenderer.on('tray-action', (event, action: string) => callback(action));
  },
  onTrayDeviceAction: (callback: (data: { action: string; device: any }) => void) => {
    ipcRenderer.on('tray-device-action', (event, data: { action: string; device: any }) => callback(data));
  },
  showConfirmDialog: (title: string, message: string) => ipcRenderer.invoke('show-confirm-dialog', { title, message }),
  showMessageDialog: (title: string, message: string, type?: 'info' | 'warning' | 'error') => ipcRenderer.invoke('show-message-dialog', { title, message, type }),
  readLogsFile: () => ipcRenderer.invoke('read-logs-file'),
  writeLogsFile: (content: string) => ipcRenderer.invoke('write-logs-file', content),
  showMainWindow: () => ipcRenderer.invoke('show-main-window'),
  adjustTrayWindowHeightByDeviceCount: (deviceCount: number) => ipcRenderer.invoke('adjust-tray-window-height-by-device-count', deviceCount)
};

contextBridge.exposeInMainWorld('electronAPI', electronAPI);

// 在页面加载前就添加 tray-window 类（如果是托盘窗口）
// 通过检查窗口特征来判断：无边框、固定大小、不在任务栏显示
// 这些特征在 window-manager.ts 中设置
if (typeof window !== 'undefined' && window.document) {
  // 等待 DOM 准备好
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
      if (document.body) {
        // 检查是否是托盘窗口（通过检查窗口特征）
        // 托盘窗口通常是无边框、固定大小的
        // 但更可靠的方法是在 window-manager.ts 中通过 executeJavaScript 添加类
        // 这里作为备用方案
      }
    });
  } else if (document.body) {
    // DOM 已经准备好
  }
}
