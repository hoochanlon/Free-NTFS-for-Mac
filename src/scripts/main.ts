import { app, BrowserWindow } from 'electron';
import { setupHotReload } from './hot-reload';
import { createMainWindow, mainWindow } from './window-manager';
import { setupIpcHandlers } from './ipc-handlers';
import { setupAppConfig } from './app-config';
import { initTray, destroyTray, updateTrayMenu } from './utils/tray-manager';
import { SettingsManager } from './utils/settings';

// 初始化热重载（开发模式）
setupHotReload();

// 应用生命周期管理
app.whenReady().then(async () => {
  await createMainWindow();
  await setupAppConfig();
  setupIpcHandlers();

  // 检查是否启用托盘模式
  const settings = await SettingsManager.getSettings();
  if (settings.trayMode) {
    try {
      await initTray();
      // 在 macOS 上，托盘模式下隐藏 Dock 图标
      if (process.platform === 'darwin' && app.dock) {
        app.dock.hide();
      }
    } catch (error) {
      console.error('托盘初始化失败:', error);
    }
  }

  // 应用系统自启设置
  app.setLoginItemSettings({
    openAtLogin: settings.autoStart || false,
    openAsHidden: false
  });

  app.on('activate', async () => {
    const settings = await SettingsManager.getSettings();
    // 在托盘模式下，点击托盘图标不应该自动显示窗口
    // 窗口应该通过托盘菜单来显示
    if (settings.trayMode) {
      // 如果所有窗口都关闭了，创建新窗口但不显示
      if (BrowserWindow.getAllWindows().length === 0) {
        await createMainWindow();
        // 在托盘模式下，创建窗口后应该隐藏
        if (mainWindow) {
          mainWindow.hide();
        }
      }
      // 如果窗口存在，不自动显示（让用户通过菜单控制）
      return;
    }

    // 非托盘模式下，正常显示窗口
    if (BrowserWindow.getAllWindows().length === 0) {
      await createMainWindow();
    } else if (mainWindow) {
      mainWindow.show();
      mainWindow.focus();
    }
  });
});

app.on('window-all-closed', async () => {
  const settings = await SettingsManager.getSettings();
  // 如果启用托盘模式，不退出应用
  if (settings.trayMode) {
    // 在 macOS 上，即使所有窗口关闭，应用也应该继续运行（托盘模式）
    if (process.platform === 'darwin') {
      return;
    }
  }
  // 否则正常退出
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

// 应用退出前清理托盘
app.on('before-quit', () => {
  destroyTray();
});
