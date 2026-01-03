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
  showConfirmDialog: (title: string, message: string) => ipcRenderer.invoke('show-confirm-dialog', { title, message }),
  showMessageDialog: (title: string, message: string, type?: 'info' | 'warning' | 'error') => ipcRenderer.invoke('show-message-dialog', { title, message, type }),
  readLogsFile: () => ipcRenderer.invoke('read-logs-file'),
  writeLogsFile: (content: string) => ipcRenderer.invoke('write-logs-file', content)
};

contextBridge.exposeInMainWorld('electronAPI', electronAPI);
