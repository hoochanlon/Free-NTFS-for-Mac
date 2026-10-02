// 密码输入对话框窗口管理器
import { BrowserWindow, ipcMain, app, screen } from 'electron';
import * as path from 'path';
import { mainWindow, trayDevicesWindow } from '../window-manager';

let passwordDialogWindow: BrowserWindow | null = null;

function dismissPasswordDialog(window: BrowserWindow): void {
  if (window.isDestroyed()) return;
  window.setAlwaysOnTop(false);
  window.hide();
  window.destroy();
}

export interface PasswordDialogOptions {
  title: string;
  message: string;
  label?: string;
  cancelText?: string;
  confirmText?: string;
  emptyPasswordText?: string;
  togglePasswordText?: string;
  showPasswordText?: string;
  hidePasswordText?: string;
}

export function createPasswordDialog(options: PasswordDialogOptions): Promise<string | null> {
  return new Promise((resolve) => {
    let settled = false;
    const settle = (password: string | null): void => {
      if (settled) return;
      settled = true;
      resolve(password);
    };

    // 如果已有对话框打开，先关闭
    if (passwordDialogWindow) {
      const previousWindow = passwordDialogWindow;
      passwordDialogWindow = null;
      dismissPasswordDialog(previousWindow);
    }

    // 获取父窗口（优先使用托盘窗口，其次主窗口，最后是当前焦点窗口）
    // 托盘窗口存在且可见时，优先使用它作为父窗口
    let parentWindow: BrowserWindow | null = null;
    if (trayDevicesWindow && !trayDevicesWindow.isDestroyed() && trayDevicesWindow.isVisible()) {
      parentWindow = trayDevicesWindow;
    } else if (mainWindow && !mainWindow.isDestroyed() && mainWindow.isVisible()) {
      parentWindow = mainWindow;
    } else {
      parentWindow = BrowserWindow.getFocusedWindow();
    }

    const parentTheme = parentWindow && !parentWindow.isDestroyed()
      ? parentWindow.webContents.executeJavaScript(`
          document.body.classList.contains('light-theme')
        `).then(Boolean).catch(() => true)
      : Promise.resolve(true);

    // 计算居中位置
    const primaryDisplay = screen.getPrimaryDisplay();
    const { width: screenWidth, height: screenHeight } = primaryDisplay.workAreaSize;
    const dialogWidth = 450;
    const dialogHeight = 280;
    const x = Math.floor((screenWidth - dialogWidth) / 2);
    const y = Math.floor((screenHeight - dialogHeight) / 2);

    // 创建对话框窗口
    // 在托盘场景下，不使用 modal 模式，确保窗口能独立显示
    const isTrayContext = trayDevicesWindow && !trayDevicesWindow.isDestroyed() && trayDevicesWindow.isVisible();
    const hasParent = !!parentWindow && !parentWindow.isDestroyed() && !isTrayContext; // 托盘场景不使用父窗口

    const dialogWindow = new BrowserWindow({
      width: dialogWidth,
      height: dialogHeight,
      // 托盘场景下手动计算位置，确保窗口居中显示
      x: isTrayContext ? x : (hasParent ? undefined : x),
      y: isTrayContext ? y : (hasParent ? undefined : y),
      resizable: false,
      minimizable: false,
      maximizable: false,
      // 托盘场景下不使用 modal，确保窗口能独立显示
      modal: hasParent && !isTrayContext,
      parent: hasParent && !isTrayContext && parentWindow ? parentWindow : undefined,
      frame: false,
      transparent: true,
      hasShadow: false,
      backgroundColor: '#00000000',
      webPreferences: {
        nodeIntegration: true,
        contextIsolation: false
      },
      show: false,
      alwaysOnTop: true, // 始终置顶，确保用户能看到（特别是托盘场景）
      skipTaskbar: false, // 在任务栏显示，方便用户找到
      focusable: true, // 确保窗口可以获得焦点
      acceptFirstMouse: true // macOS 特定：允许点击窗口时自动聚焦
    });
    passwordDialogWindow = dialogWindow;

    // 加载对话框 HTML
    const appPath = app.getAppPath();
    const dialogPath = path.join(appPath, 'src/html/password-dialog.html');

    // 监听窗口加载错误
    dialogWindow.webContents.on('did-fail-load', (event: any, errorCode: number, errorDescription: string) => {
      console.error('[PasswordDialog] 窗口加载失败:', errorCode, errorDescription);
    });

    dialogWindow.loadFile(dialogPath).catch((error: any) => {
      console.error('[PasswordDialog] 加载密码对话框失败:', error);
      dismissPasswordDialog(dialogWindow);
      settle(null);
    });

    // 监听窗口显示事件，确保窗口能正确显示
    dialogWindow.on('show', () => {
      console.log('[PasswordDialog] 窗口显示事件触发');
      if (!dialogWindow.isDestroyed()) {
        dialogWindow.focus();
      }
    });

    // 监听窗口聚焦事件
    dialogWindow.on('focus', () => {
      console.log('[PasswordDialog] 窗口获得焦点');
    });

    // 监听窗口失焦事件（托盘场景下可能被其他窗口遮挡）
    dialogWindow.on('blur', () => {
      console.log('[PasswordDialog] 窗口失去焦点');
      // 如果窗口失去焦点，尝试重新聚焦（延迟一点，避免循环）
      if (!dialogWindow.isDestroyed() && isTrayContext) {
        setTimeout(() => {
          if (!dialogWindow.isDestroyed() && dialogWindow.isVisible()) {
            dialogWindow.focus();
          }
        }, 200);
      }
    });

    // 窗口准备好后显示
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
          message: options.message,
          isLightMode,
          label: options.label || '密码:',
          cancelText: options.cancelText || '取消',
          confirmText: options.confirmText || '确定',
          emptyPasswordText: options.emptyPasswordText || '密码不能为空',
          togglePasswordText: options.togglePasswordText || '显示/隐藏密码',
          showPasswordText: options.showPasswordText || '显示密码',
          hidePasswordText: options.hidePasswordText || '隐藏密码'
        });

        await contentReady;
        const contentHeight = await dialogWindow.webContents.executeJavaScript(
          'Math.ceil(document.querySelector(".dialog-container").getBoundingClientRect().height)'
        );
        if (dialogWindow.isDestroyed()) return;

        const minimumHeight = isTrayContext ? 220 : dialogHeight;
        const finalHeight = Math.max(minimumHeight, Math.ceil(contentHeight));
        dialogWindow.setContentSize(dialogWidth, finalHeight);
        if (!hasParent) {
          dialogWindow.setPosition(x, Math.floor((screenHeight - finalHeight) / 2));
        }
        dialogWindow.show();
        dialogWindow.focus();
        if (isTrayContext) dialogWindow.moveTop();

        console.log('[PasswordDialog] 密码对话框已显示', {
          isTrayContext,
          hasParent,
          parentWindow: hasParent ? (parentWindow === trayDevicesWindow ? '托盘窗口' : '主窗口') : '无',
          position: dialogWindow.getPosition(),
          visible: dialogWindow.isVisible(),
          focused: dialogWindow.isFocused()
        });

        // 托盘场景下，添加超时检测，确保窗口能显示
        if (isTrayContext) {
          setTimeout(() => {
            if (!dialogWindow.isDestroyed()) {
              if (!dialogWindow.isVisible()) {
                console.warn('[PasswordDialog] 窗口未显示，强制显示');
                dialogWindow.show();
              }
              if (!dialogWindow.isFocused()) {
                console.warn('[PasswordDialog] 窗口未聚焦，强制聚焦');
                dialogWindow.focus();
                dialogWindow.moveTop();
              }
            }
          }, 500);
        }
      } catch (error) {
        console.error('[PasswordDialog] 初始化密码对话框失败:', error);
        settle(null);
        dismissPasswordDialog(dialogWindow);
      }
    });

    // 处理对话框响应
    const responseHandler = (event: any, data: { password?: string; canceled: boolean }) => {
      if (event.sender === dialogWindow.webContents) {
        // 移除监听器
        ipcMain.removeListener('password-dialog-response', responseHandler);

        settle(data.canceled ? null : data.password || null);
        if (passwordDialogWindow === dialogWindow) passwordDialogWindow = null;
        dismissPasswordDialog(dialogWindow);
      }
    };

    ipcMain.on('password-dialog-response', responseHandler);

    // 窗口关闭时清理
    dialogWindow.on('closed', () => {
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
