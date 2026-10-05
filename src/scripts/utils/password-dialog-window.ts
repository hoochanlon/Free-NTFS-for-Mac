// 密码输入对话框窗口管理器
import { BrowserWindow, ipcMain, app, screen } from 'electron';
import * as path from 'path';
import { mainWindow, trayDevicesWindow, showMainWindowAndCloseTray } from '../window-manager';
import { SettingsManager } from './settings';
import { KeychainManager } from './keychain';

let passwordDialogWindow: BrowserWindow | null = null;

function dismissPasswordDialog(window: BrowserWindow): void {
  if (window.isDestroyed()) return;
  window.setAlwaysOnTop(false);
  window.hide();
  window.destroy();
}

export interface PasswordDialogOptions {
  title: string;
  label?: string;
  cancelText?: string;
  confirmText?: string;
  emptyPasswordText?: string;
  togglePasswordText?: string;
  showPasswordText?: string;
  hidePasswordText?: string;
  savePasswordText?: string;
  savePassword?: boolean;
}

export async function createPasswordDialog(options: PasswordDialogOptions): Promise<string | null> {
  if (trayDevicesWindow && !trayDevicesWindow.isDestroyed() && trayDevicesWindow.isVisible()) {
    await showMainWindowAndCloseTray();
  }

  return new Promise((resolve) => {
    let settled = false;
    const settle = (password: string | null): void => {
      if (settled) return;
      settled = true;
      resolve(password);
    };

    if (passwordDialogWindow) {
      const previousWindow = passwordDialogWindow;
      passwordDialogWindow = null;
      dismissPasswordDialog(previousWindow);
    }

    let parentWindow: BrowserWindow | null = null;
    if (mainWindow && !mainWindow.isDestroyed() && mainWindow.isVisible()) {
      parentWindow = mainWindow;
    } else {
      parentWindow = BrowserWindow.getFocusedWindow();
    }

    const parentTheme = parentWindow && !parentWindow.isDestroyed()
      ? parentWindow.webContents.executeJavaScript(`
          document.body.classList.contains('light-theme')
        `).then(Boolean).catch(() => true)
      : Promise.resolve(true);

    const primaryDisplay = screen.getPrimaryDisplay();
    const { width: screenWidth, height: screenHeight } = primaryDisplay.workAreaSize;
    const dialogWidth = 450;
    const dialogHeight = 280;
    const x = Math.floor((screenWidth - dialogWidth) / 2);
    const y = Math.floor((screenHeight - dialogHeight) / 2);
    const hasParent = !!parentWindow && !parentWindow.isDestroyed();

    const dialogWindow = new BrowserWindow({
      width: dialogWidth,
      height: dialogHeight,
      x: hasParent ? undefined : x,
      y: hasParent ? undefined : y,
      resizable: false,
      minimizable: false,
      maximizable: false,
      modal: hasParent,
      parent: hasParent && parentWindow ? parentWindow : undefined,
      frame: false,
      transparent: true,
      hasShadow: false,
      backgroundColor: '#00000000',
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
    passwordDialogWindow = dialogWindow;

    let hasShown = false;
    const contentSizeHandler = (event: Electron.IpcMainEvent, contentHeight: number): void => {
      if (event.sender !== dialogWindow.webContents || dialogWindow.isDestroyed() || !hasShown || !Number.isFinite(contentHeight)) return;

      const finalHeight = Math.max(dialogHeight, Math.ceil(contentHeight));
      const [, currentHeight] = dialogWindow.getContentSize();
      if (currentHeight === finalHeight) return;

      dialogWindow.setContentSize(dialogWidth, finalHeight);
      if (!hasParent) {
        dialogWindow.setPosition(x, Math.floor((screenHeight - finalHeight) / 2));
      }
    };
    ipcMain.on('password-dialog-content-size', contentSizeHandler);

    const appPath = app.getAppPath();
    const dialogPath = path.join(appPath, 'src/html/password-dialog.html');

    dialogWindow.webContents.on('did-fail-load', (_event: any, errorCode: number, errorDescription: string) => {
      console.error('[PasswordDialog] 窗口加载失败:', errorCode, errorDescription);
    });

    dialogWindow.loadFile(dialogPath).catch((error: any) => {
      console.error('[PasswordDialog] 加载密码对话框失败:', error);
      dismissPasswordDialog(dialogWindow);
      settle(null);
    });

    dialogWindow.once('ready-to-show', async () => {
      if (dialogWindow.isDestroyed()) return;

      try {
        const isLightMode = await parentTheme;
        const contentReady = new Promise<void>((resolveContentReady) => {
          const onContentReady = (event: Electron.IpcMainEvent) => {
            if (event.sender !== dialogWindow.webContents) return;
            clearTimeout(contentReadyTimeout);
            ipcMain.removeListener('password-dialog-content-ready', onContentReady);
            resolveContentReady();
          };
          const contentReadyTimeout = setTimeout(() => {
            ipcMain.removeListener('password-dialog-content-ready', onContentReady);
            resolveContentReady();
          }, 1000);
          ipcMain.on('password-dialog-content-ready', onContentReady);
        });

        dialogWindow.webContents.send('password-dialog-data', {
          title: options.title,
          isLightMode,
          label: options.label || '密码:',
          cancelText: options.cancelText || '取消',
          confirmText: options.confirmText || '确定',
          emptyPasswordText: options.emptyPasswordText || '密码不能为空',
          togglePasswordText: options.togglePasswordText || '显示/隐藏密码',
          showPasswordText: options.showPasswordText || '显示密码',
          hidePasswordText: options.hidePasswordText || '隐藏密码',
          savePasswordText: options.savePasswordText || '保存密码',
          savePassword: options.savePassword === true
        });

        await contentReady;
        const contentHeight = await dialogWindow.webContents.executeJavaScript(
          'Math.ceil(document.querySelector(".dialog-container").getBoundingClientRect().height)'
        );
        if (dialogWindow.isDestroyed()) return;

        const finalHeight = Math.max(dialogHeight, Math.ceil(contentHeight));
        dialogWindow.setContentSize(dialogWidth, finalHeight);
        if (!hasParent) {
          dialogWindow.setPosition(x, Math.floor((screenHeight - finalHeight) / 2));
        }
        dialogWindow.show();
        hasShown = true;
        dialogWindow.focus();
      } catch (error) {
        console.error('[PasswordDialog] 初始化密码对话框失败:', error);
        settle(null);
        dismissPasswordDialog(dialogWindow);
      }
    });

    const responseHandler = (event: any, data: { password?: string; canceled: boolean; savePassword?: boolean }) => {
      if (event.sender === dialogWindow.webContents) {
        ipcMain.removeListener('password-dialog-response', responseHandler);

        if (!data.canceled && typeof data.savePassword === 'boolean') {
          options.savePassword = data.savePassword;
          SettingsManager.saveSettings({ savePassword: data.savePassword })
            .then(() => data.savePassword ? undefined : KeychainManager.deletePassword())
            .then(() => {
              BrowserWindow.getAllWindows().forEach(window => {
                if (!window.isDestroyed()) {
                  window.webContents.send('settings-changed', { savePassword: data.savePassword });
                }
              });
            })
            .catch(error => console.warn('[PasswordDialog] 同步保存密码设置失败:', error));
        }
        settle(data.canceled ? null : data.password || null);
        if (passwordDialogWindow === dialogWindow) passwordDialogWindow = null;
        dismissPasswordDialog(dialogWindow);
      }
    };

    ipcMain.on('password-dialog-response', responseHandler);

    dialogWindow.on('closed', () => {
      ipcMain.removeListener('password-dialog-content-size', contentSizeHandler);
      ipcMain.removeListener('password-dialog-response', responseHandler);
      if (passwordDialogWindow === dialogWindow) passwordDialogWindow = null;
      settle(null);
    });
  });
}

export function closePasswordDialog(): void {
  if (passwordDialogWindow) {
    const dialogWindow = passwordDialogWindow;
    passwordDialogWindow = null;
    dismissPasswordDialog(dialogWindow);
  }
}

