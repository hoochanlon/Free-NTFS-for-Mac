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

  ipcMain.handle('install-dependencies', async () => {
    try {
      const result = await ntfsManager.installDependencies();
      return { success: true, result };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      return { success: false, error: errorMessage };
    }
  });

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

// 初始化所有 IPC handlers
export function setupIpcHandlers(): void {
  setupNTFSHandlers();
  setupWindowHandlers();
  setupFileHandlers();
  setupSystemHandlers();
}
