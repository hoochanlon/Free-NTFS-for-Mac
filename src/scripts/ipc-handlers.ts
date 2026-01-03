import { ipcMain, dialog, shell, BrowserWindow } from 'electron';
import ntfsManager from './ntfs-manager';
import * as path from 'path';
import * as fs from 'fs';
import { app } from 'electron';
import {
  createLogsWindow,
  closeLogsWindow,
  createModuleWindow,
  closeModuleWindow,
  mainWindow
} from './window-manager';
import { openAboutWindow, getAboutWindow } from './about-window';
import { SettingsManager, AppSettings } from './utils/settings';
import { KeychainManager } from './utils/keychain';
import { rebuildApplicationMenu } from './app-config';

// NTFS 相关 IPC handlers
export function setupNTFSHandlers(): void {
  ipcMain.handle('check-dependencies', async () => {
    return await ntfsManager.checkDependencies();
  });

  ipcMain.handle('get-ntfs-devices', async () => {
    return await ntfsManager.getNTFSDevices();
  });

  ipcMain.handle('mount-device', async (event, device) => {
    try {
      const result = await ntfsManager.mountDevice(device);
      return { success: true, result };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      return { success: false, error: errorMessage };
    }
  });

  ipcMain.handle('unmount-device', async (event, device) => {
    try {
      const result = await ntfsManager.unmountDevice(device);
      return { success: true, result };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      return { success: false, error: errorMessage };
    }
  });

  ipcMain.handle('restore-to-readonly', async (event, device) => {
    try {
      const result = await ntfsManager.restoreToReadOnly(device);
      return { success: true, result };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      return { success: false, error: errorMessage };
    }
  });

  ipcMain.handle('eject-device', async (event, device) => {
    try {
      const result = await ntfsManager.ejectDevice(device);
      return { success: true, result };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      return { success: false, error: errorMessage };
    }
  });

  ipcMain.handle('export-logs', async (event, content: string) => {
    try {
      const { dialog } = require('electron');
      const fs = require('fs').promises;
      const path = require('path');
      const { app } = require('electron');

      const result = await dialog.showSaveDialog({
        title: '导出操作日志',
        defaultPath: path.join(
          app.getPath('documents'),
          `操作日志_${new Date().toISOString().split('T')[0]}.txt`
        ),
        filters: [
          { name: '文本文件', extensions: ['txt'] },
          { name: '所有文件', extensions: ['*'] }
        ]
      });

      if (result.canceled) {
        return { success: false, error: '用户取消' };
      }

      await fs.writeFile(result.filePath, content, 'utf-8');
      return { success: true, path: result.filePath };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      return { success: false, error: errorMessage };
    }
  });

  // 已移除自动安装功能，改为仅检测和提供安装指引
  // ipcMain.handle('install-dependencies', async () => {
  //   try {
  //     const result = await ntfsManager.installDependencies();
  //     return { success: true, result };
  //   } catch (error) {
  //     const errorMessage = error instanceof Error ? error.message : String(error);
  //     return { success: false, error: errorMessage };
  //   }
  // });

  ipcMain.handle('request-sudo-password', async () => {
    return new Promise<void>((resolve) => {
      if (mainWindow) {
        dialog.showMessageBox(mainWindow, {
          type: 'info',
          title: '需要管理员权限',
          message: '挂载 NTFS 设备需要管理员权限。\n\n请在终端中输入您的密码。',
          buttons: ['确定']
        }).then(() => resolve());
      } else {
        resolve();
      }
    });
  });

  // 自定义确认对话框
  ipcMain.handle('show-confirm-dialog', async (event, options: { title: string; message: string }) => {
    if (mainWindow) {
      const result = await dialog.showMessageBox(mainWindow, {
        type: 'question',
        title: options.title,
        message: options.title,
        detail: options.message,
        buttons: ['取消', '确定'],
        defaultId: 1,
        cancelId: 0,
        noLink: true
      });
      return result.response === 1; // 1 是"确定"按钮
    }
    return false;
  });

  // 显示消息对话框（替换 alert）
  ipcMain.handle('show-message-dialog', async (event, options: { title: string; message: string; type?: 'info' | 'warning' | 'error' }) => {
    if (mainWindow) {
      await dialog.showMessageBox(mainWindow, {
        type: options.type || 'info',
        title: options.title,
        message: options.title,
        detail: options.message,
        buttons: ['确定'],
        defaultId: 0,
        noLink: true
      });
    }
  });

  // 读取日志文件
  ipcMain.handle('read-logs-file', async () => {
    try {
      const userDataPath = app.getPath('userData');
      const logsFilePath = path.join(userDataPath, 'logs.json');
      
      if (fs.existsSync(logsFilePath)) {
        const content = await fs.promises.readFile(logsFilePath, 'utf-8');
        // 确保返回的内容不为空
        return { success: true, content: content || '[]' };
      }
      // 文件不存在时返回空数组
      return { success: true, content: '[]' };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      console.error('读取日志文件失败:', errorMessage);
      return { success: false, error: errorMessage };
    }
  });

  // 保存日志文件
  ipcMain.handle('write-logs-file', async (event, content: string) => {
    try {
      const userDataPath = app.getPath('userData');
      const logsFilePath = path.join(userDataPath, 'logs.json');
      
      await fs.promises.writeFile(logsFilePath, content, 'utf-8');
      return { success: true };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      return { success: false, error: errorMessage };
    }
  });
}

// 窗口相关 IPC handlers
export function setupWindowHandlers(): void {
  ipcMain.handle('open-logs-window', async () => {
    await createLogsWindow();
  });

  ipcMain.handle('close-logs-window', async () => {
    closeLogsWindow();
  });

  ipcMain.handle('open-module-window', async (event, moduleName: string) => {
    await createModuleWindow(moduleName);
  });

  ipcMain.handle('close-module-window', async (event) => {
    const window = BrowserWindow.fromWebContents(event.sender);
    if (window) {
      closeModuleWindow(window);
    }
  });

  ipcMain.handle('open-about-window', async () => {
    console.log('IPC: open-about-window 被调用');
    await openAboutWindow();
  });

  ipcMain.handle('switch-to-tab', async (event, tabName: string) => {
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.webContents.send('switch-tab', tabName);
    }
  });
}

// 文件相关 IPC handlers
export function setupFileHandlers(): void {
  ipcMain.handle('read-markdown', async (event, filename: string) => {
    try {
      const appPath = app.getAppPath();
      const filePath = path.join(appPath, 'src', 'docs', filename);
      const content = await fs.promises.readFile(filePath, 'utf-8');
      return { success: true, content };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      return { success: false, error: errorMessage };
    }
  });
}

// 系统相关 IPC handlers
export function setupSystemHandlers(): void {
  ipcMain.handle('open-external', async (event, url: string) => {
    try {
      await shell.openExternal(url);
    } catch (error) {
      console.error('打开外部链接失败:', error);
    }
  });

  ipcMain.handle('get-current-theme', async () => {
    if (mainWindow && !mainWindow.isDestroyed()) {
      try {
        const theme = await mainWindow.webContents.executeJavaScript(`
          document.body.classList.contains('light-theme') ? 'light' : 'dark'
        `);
        return theme;
      } catch (error) {
        console.error('获取当前主题失败:', error);
        return 'dark';
      }
    }
    return 'dark';
  });

  ipcMain.handle('broadcast-theme-change', async (event, isLightMode: boolean) => {
    const allWindows = BrowserWindow.getAllWindows();
    allWindows.forEach(window => {
      if (window && !window.isDestroyed()) {
        window.webContents.send('theme-changed', isLightMode);
        // 更新窗口背景色（特别是关于窗口）
        const aboutWindow = getAboutWindow();
        if (window === aboutWindow) {
          const backgroundColor = isLightMode ? '#f5f5f7' : '#1d1d1f';
          window.setBackgroundColor(backgroundColor);
        }
      }
    });
  });
}

// 设置相关 IPC handlers
export function setupSettingsHandlers(): void {
  // 获取设置
  ipcMain.handle('get-settings', async () => {
    return await SettingsManager.getSettings();
  });

  // 保存设置
  ipcMain.handle('save-settings', async (event, settings: Partial<AppSettings>) => {
    const oldSettings = await SettingsManager.getSettings();
    await SettingsManager.saveSettings(settings);
    // 如果语言设置发生变化，重新构建菜单
    if (settings.language && settings.language !== oldSettings.language) {
      await rebuildApplicationMenu();
    }
    return { success: true };
  });

  // 检查是否有保存的密码
  ipcMain.handle('has-saved-password', async () => {
    return await KeychainManager.hasPassword();
  });

  // 删除保存的密码
  ipcMain.handle('delete-saved-password', async () => {
    await KeychainManager.deletePassword();
    return { success: true };
  });
}

// 初始化所有 IPC handlers
export function setupIpcHandlers(): void {
  setupNTFSHandlers();
  setupWindowHandlers();
  setupFileHandlers();
  setupSystemHandlers();
  setupSettingsHandlers();
}
