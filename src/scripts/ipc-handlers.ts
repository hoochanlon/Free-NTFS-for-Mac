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
  mainWindow,
  showMainWindowAndCloseTray,
  adjustTrayWindowHeightByDeviceCount
} from './window-manager';
import { openAboutWindow, getAboutWindow } from './about-window';
import { SettingsManager, AppSettings } from './utils/settings';
import { WINDOW_SIZE_CONFIG } from '../config/window-config';
import { KeychainManager } from './utils/keychain';
import { rebuildApplicationMenu } from './app-config';
import { initTray, destroyTray, updateTrayMenu } from './utils/tray-manager';

let quitWindow: BrowserWindow | null = null;

// NTFS 相关 IPC handlers
export function setupNTFSHandlers(): void {
  ipcMain.handle('check-dependencies', async () => {
    return await ntfsManager.checkDependencies();
  });

  ipcMain.handle('get-ntfs-devices', async (event, forceRefresh: boolean = false) => {
    return await ntfsManager.getNTFSDevices(forceRefresh);
  });

  ipcMain.handle('mount-device', async (event, device) => {
    try {
      const result = await ntfsManager.mountDevice(device);
      // 事件驱动：操作完成后立即更新托盘菜单
      setTimeout(() => {
        updateTrayMenu(true); // 强制刷新，确保菜单显示最新状态
      }, 500); // 等待系统状态更新
      return { success: true, result };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      // 即使失败也更新菜单，显示当前状态
      setTimeout(() => {
        updateTrayMenu(true);
      }, 300);
      return { success: false, error: errorMessage };
    }
  });

  ipcMain.handle('unmount-device', async (event, device) => {
    try {
      const result = await ntfsManager.unmountDevice(device);
      // 事件驱动：操作完成后立即更新托盘菜单
      setTimeout(() => {
        updateTrayMenu(true);
      }, 500);
      return { success: true, result };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      setTimeout(() => {
        updateTrayMenu(true);
      }, 300);
      return { success: false, error: errorMessage };
    }
  });

  ipcMain.handle('restore-to-readonly', async (event, device) => {
    try {
      const result = await ntfsManager.restoreToReadOnly(device);
      // 事件驱动：操作完成后立即更新托盘菜单
      // restoreToReadOnly 需要更长时间，等待系统重新挂载
      setTimeout(() => {
        updateTrayMenu(true);
      }, 1500); // 等待系统重新挂载完成
      return { success: true, result };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      setTimeout(() => {
        updateTrayMenu(true);
      }, 500);
      return { success: false, error: errorMessage };
    }
  });

  ipcMain.handle('eject-device', async (event, device) => {
    try {
      const result = await ntfsManager.ejectDevice(device);
      // 事件驱动：操作完成后立即更新托盘菜单
      setTimeout(() => {
        updateTrayMenu(true);
      }, 500);
      return { success: true, result };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      setTimeout(() => {
        updateTrayMenu(true);
      }, 300);
      return { success: false, error: errorMessage };
    }
  });

  // 混合检测相关 IPC handlers
  // 注意：混合检测是全局的，所有窗口共享同一个检测实例
  // 但是每个窗口都需要注册自己的事件监听器来接收设备变化事件
  let hybridDetectionInitialized = false;

  ipcMain.handle('start-hybrid-detection', async (event) => {
    try {
      // 只在第一次调用时初始化混合检测（避免重复初始化）
      if (!hybridDetectionInitialized) {
        await ntfsManager.startHybridDetection((devices) => {
          // 通过事件通知所有窗口（包括已打开的托盘窗口）
          const allWindows = BrowserWindow.getAllWindows();
          console.log(`[混合检测] 设备变化，通知 ${allWindows.length} 个窗口，设备数量:`, devices.length);

          allWindows.forEach((win, index) => {
            if (!win.isDestroyed()) {
              try {
                win.webContents.send('hybrid-detection-device-change', devices);
                console.log(`[混合检测] 已发送事件到窗口 ${index + 1}`);
              } catch (error) {
                // 忽略已关闭窗口的错误
                console.warn(`[混合检测] 发送事件到窗口 ${index + 1} 失败:`, error);
              }
            }
          });
        });
        hybridDetectionInitialized = true;
        console.log('✅ [混合检测] 全局检测已启动');
      } else {
        // 如果已经初始化，立即发送当前设备列表给新窗口
        const currentDevices = await ntfsManager.getNTFSDevices(true);
        if (event && event.sender && !event.sender.isDestroyed()) {
          console.log('[混合检测] 向新窗口发送当前设备列表，设备数量:', currentDevices.length);
          event.sender.send('hybrid-detection-device-change', currentDevices);
        }
      }
      return { success: true };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      return { success: false, error: errorMessage };
    }
  });

  ipcMain.handle('stop-hybrid-detection', async () => {
    try {
      ntfsManager.stopHybridDetection();
      return { success: true };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      return { success: false, error: errorMessage };
    }
  });

  ipcMain.handle('update-window-visibility', async (event, isVisible: boolean) => {
    try {
      ntfsManager.updateWindowVisibility(isVisible);
      return { success: true };
    } catch (error) {
      return { success: false };
    }
  });

  ipcMain.handle('get-detection-mode', async () => {
    return ntfsManager.getDetectionMode();
  });

  ipcMain.handle('check-event-driven-available', async () => {
    return await ntfsManager.checkEventDrivenAvailable();
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

  ipcMain.handle('request-sudo-password', async (event) => {
    return new Promise<void>((resolve) => {
      // 优先使用调用方所属窗口，其次回退到 mainWindow
      const win = BrowserWindow.fromWebContents(event.sender) || mainWindow;

      if (win && !win.isDestroyed()) {
        dialog.showMessageBox(win, {
          type: 'info',
          title: '需要管理员权限',
          message: '挂载 NTFS 设备需要管理员权限。\n\n请在终端中输入您的密码。',
          buttons: ['确定'],
          defaultId: 0
        }).then(() => resolve()).catch(() => resolve());
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
    await openAboutWindow();
  });

  // 打开退出确认窗口
  ipcMain.handle('open-quit-window', async () => {
    try {
      if (quitWindow && !quitWindow.isDestroyed()) {
        quitWindow.focus();
        return;
      }

      const appPath = app.getAppPath();
      const quitPath = path.join(appPath, 'src', 'html', 'quit-confirm.html');

      quitWindow = new BrowserWindow({
        width: 420,
        height: 220,
        resizable: false,
        minimizable: false,
        maximizable: false,
        fullscreenable: false,
        show: false,
        parent: mainWindow || undefined,
        modal: true,
        frame: false,
        titleBarStyle: 'hiddenInset',
        webPreferences: {
          preload: path.join(__dirname, 'preload.js'),
          nodeIntegration: false,
          contextIsolation: true
        }
      });

      quitWindow.on('closed', () => {
        quitWindow = null;
      });

      await quitWindow.loadFile(quitPath);

      quitWindow.once('ready-to-show', () => {
        if (quitWindow && !quitWindow.isDestroyed()) {
          quitWindow.show();
          quitWindow.focus();
        }
      });
    } catch (error) {
      console.error('打开退出窗口失败:', error);
      if (quitWindow && !quitWindow.isDestroyed()) {
        quitWindow.close();
      }
      quitWindow = null;
    }
  });

  ipcMain.handle('close-quit-window', async () => {
    if (quitWindow && !quitWindow.isDestroyed()) {
      quitWindow.close();
      quitWindow = null;
    }
  });

  ipcMain.handle('switch-to-tab', async (event, tabName: string) => {
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.webContents.send('switch-tab', tabName);
    }
  });

  ipcMain.handle('show-main-window', async () => {
    await showMainWindowAndCloseTray();
  });

  // 根据设备数量调整托盘窗口高度
  ipcMain.handle('adjust-tray-window-height-by-device-count', async (event, deviceCount: number) => {
    adjustTrayWindowHeightByDeviceCount(deviceCount);
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
    const backgroundColor = isLightMode ? '#ffffff' : '#1e1e1e';
    allWindows.forEach(window => {
      if (window && !window.isDestroyed()) {
        window.webContents.send('theme-changed', isLightMode);
        // 更新所有模块窗口和托盘设备窗口的背景色
        const aboutWindow = getAboutWindow();
        if (window === aboutWindow) {
          const aboutBgColor = isLightMode ? '#f5f5f7' : '#1d1d1f';
          window.setBackgroundColor(aboutBgColor);
        } else {
          // 检查是否是模块窗口或托盘设备窗口
          // 这些窗口使用devices.html或dependencies.html
          const url = window.webContents.getURL();
          if (url && (url.includes('devices.html') || url.includes('dependencies.html'))) {
            window.setBackgroundColor(backgroundColor);
          }
        }
      }
    });
  });

  // 退出应用
  ipcMain.handle('quit-app', async () => {
    app.quit();
  });
}

// 设置相关 IPC handlers
export function setupSettingsHandlers(): void {
  // 获取设置
  ipcMain.handle('get-settings', async () => {
    return await SettingsManager.getSettings();
  });

  // 获取窗口尺寸配置
  ipcMain.handle('get-window-size-config', async () => {
    return WINDOW_SIZE_CONFIG;
  });

  // 保存设置
  ipcMain.handle('save-settings', async (event, settings: Partial<AppSettings>) => {
    const oldSettings = await SettingsManager.getSettings();
    await SettingsManager.saveSettings(settings);

    // 广播设置变化到所有窗口
    const allWindows = BrowserWindow.getAllWindows();
    allWindows.forEach(window => {
      if (window && !window.isDestroyed()) {
        window.webContents.send('settings-changed', settings);
      }
    });

    // 如果语言设置发生变化，重新构建菜单和托盘菜单
    if (settings.language && settings.language !== oldSettings.language) {
      await rebuildApplicationMenu();
      await updateTrayMenu();
    }
    // 如果托盘模式设置发生变化，初始化或销毁托盘
    if (settings.trayMode !== undefined && settings.trayMode !== oldSettings.trayMode) {
      if (settings.trayMode) {
        await initTray();
        // 在 macOS 上，托盘模式下隐藏 Dock 图标
        if (process.platform === 'darwin' && app.dock) {
          app.dock.hide();
        }
      } else {
        destroyTray();
        // 在 macOS 上，退出托盘模式时显示 Dock 图标
        if (process.platform === 'darwin' && app.dock) {
          app.dock.show();
        }
      }
    }
    // 如果系统自启设置发生变化，更新登录项设置
    if (settings.autoStart !== undefined && settings.autoStart !== oldSettings.autoStart) {
      app.setLoginItemSettings({
        openAtLogin: settings.autoStart,
        openAsHidden: false
      });
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
