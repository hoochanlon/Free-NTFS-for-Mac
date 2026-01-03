import { app, BrowserWindow } from 'electron';
import { setupHotReload } from './hot-reload';
import { createMainWindow, mainWindow } from './window-manager';
import { setupIpcHandlers } from './ipc-handlers';
import { setupAppConfig } from './app-config';

// 初始化热重载（开发模式）
setupHotReload();

// 应用生命周期管理
app.whenReady().then(async () => {
  await createMainWindow();
  setupAppConfig();
  setupIpcHandlers();

  app.on('activate', async () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      await createMainWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
