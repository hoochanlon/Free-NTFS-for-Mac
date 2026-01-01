import { app, BrowserWindow } from 'electron';
import { setupHotReload } from './hot-reload';
import { createMainWindow, mainWindow } from './window-manager';
import { setupIpcHandlers } from './ipc-handlers';
import { setupAppConfig } from './app-config';

// 初始化热重载（开发模式）
setupHotReload();

// 应用生命周期管理
app.whenReady().then(() => {
  createMainWindow();
  setupAppConfig();
  setupIpcHandlers();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createMainWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
