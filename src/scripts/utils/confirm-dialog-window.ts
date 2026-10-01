import { BrowserWindow, ipcMain, app, screen } from 'electron';
import * as path from 'path';

let trayRepairConfirmWindow: BrowserWindow | null = null;

export interface TrayRepairConfirmDialogOptions {
  title: string;
  message: string;
  cancelText: string;
  confirmText: string;
  isLightTheme: boolean;
}

export function createTrayRepairConfirmDialog(options: TrayRepairConfirmDialogOptions): Promise<boolean> {
  if (trayRepairConfirmWindow && !trayRepairConfirmWindow.isDestroyed()) {
    trayRepairConfirmWindow.close();
  }

  const { workArea } = screen.getPrimaryDisplay();
  const width = 520;
  const height = 360;
  const x = workArea.x + Math.floor((workArea.width - width) / 2);
  const y = workArea.y + Math.floor((workArea.height - height) / 2);
  const dialogWindow = new BrowserWindow({
    width,
    height,
    x,
    y,
    resizable: false,
    minimizable: false,
    maximizable: false,
    frame: false,
    transparent: true,
    backgroundColor: '#00000000',
    hasShadow: false,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false
    },
    show: false,
    alwaysOnTop: true,
    skipTaskbar: false,
    focusable: true,
    acceptFirstMouse: true
  });
  trayRepairConfirmWindow = dialogWindow;

  return new Promise((resolve) => {
    let settled = false;
    let shown = false;
    const cleanup = () => {
      ipcMain.removeListener('tray-repair-confirm-response', responseHandler);
      ipcMain.removeListener('tray-repair-confirm-layout', layoutHandler);
      if (trayRepairConfirmWindow === dialogWindow) {
        trayRepairConfirmWindow = null;
      }
    };
    const finish = (confirmed: boolean) => {
      if (settled) return;
      settled = true;
      cleanup();
      if (!dialogWindow.isDestroyed()) {
        dialogWindow.close();
      }
      resolve(confirmed);
    };
    const responseHandler = (event: Electron.IpcMainEvent, data: { confirmed: boolean }) => {
      if (event.sender === dialogWindow.webContents) {
        finish(data.confirmed === true);
      }
    };
    const layoutHandler = (event: Electron.IpcMainEvent, size: { width: number; height: number }) => {
      if (event.sender !== dialogWindow.webContents || dialogWindow.isDestroyed() || shown) return;
      shown = true;

      const padding = 20;
      const width = Math.min(workArea.width - 16, Math.ceil(size.width) + padding * 2);
      const height = Math.min(workArea.height - 16, Math.ceil(size.height) + padding * 2);
      const x = workArea.x + Math.floor((workArea.width - width) / 2);
      const y = workArea.y + Math.floor((workArea.height - height) / 2);
      dialogWindow.setBounds({ x, y, width, height }, false);
      dialogWindow.show();
      dialogWindow.focus();
      dialogWindow.moveTop();
      if (process.platform === 'darwin') {
        dialogWindow.setAlwaysOnTop(true, 'screen-saver');
        setTimeout(() => {
          if (!dialogWindow.isDestroyed()) {
            dialogWindow.setAlwaysOnTop(true, 'normal');
          }
        }, 100);
      }
    };

    ipcMain.on('tray-repair-confirm-response', responseHandler);
    ipcMain.on('tray-repair-confirm-layout', layoutHandler);
    dialogWindow.once('ready-to-show', () => {
      if (dialogWindow.isDestroyed()) return;
      dialogWindow.webContents.send('tray-repair-confirm-data', options);
    });
    dialogWindow.on('blur', () => {
      setTimeout(() => {
        if (!dialogWindow.isDestroyed() && dialogWindow.isVisible()) {
          dialogWindow.focus();
        }
      }, 200);
    });
    dialogWindow.on('closed', () => {
      cleanup();
      if (!settled) {
        settled = true;
        resolve(false);
      }
    });

    const dialogPath = path.join(app.getAppPath(), 'src/html/confirm-dialog.html');
    dialogWindow.loadFile(dialogPath).catch((error: Error) => {
      console.error('[TrayRepairConfirmDialog] 加载确认对话框失败:', error);
      finish(false);
    });
  });
}
