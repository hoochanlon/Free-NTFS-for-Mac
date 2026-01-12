// 密码输入对话框窗口管理器
import { BrowserWindow, ipcMain, app, screen } from 'electron';
import * as path from 'path';
import { mainWindow, trayDevicesWindow } from '../window-manager';

let passwordDialogWindow: BrowserWindow | null = null;

export interface PasswordDialogOptions {
  title: string;
  message: string;
  label?: string;
  cancelText?: string;
  confirmText?: string;
  emptyPasswordText?: string;
}

export function createPasswordDialog(options: PasswordDialogOptions): Promise<string | null> {
  return new Promise((resolve) => {
    // 如果已有对话框打开，先关闭
    if (passwordDialogWindow) {
      passwordDialogWindow.close();
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

    passwordDialogWindow = new BrowserWindow({
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

    // 加载对话框 HTML
    const appPath = app.getAppPath();
    const dialogPath = path.join(appPath, 'src/html/password-dialog.html');

    // 监听窗口加载错误
    passwordDialogWindow.webContents.on('did-fail-load', (event, errorCode, errorDescription) => {
      console.error('[PasswordDialog] 窗口加载失败:', errorCode, errorDescription);
    });

    passwordDialogWindow.loadFile(dialogPath).catch((error) => {
      console.error('[PasswordDialog] 加载密码对话框失败:', error);
      resolve(null);
    });

    // 监听窗口显示事件，确保窗口能正确显示
    passwordDialogWindow.on('show', () => {
      console.log('[PasswordDialog] 窗口显示事件触发');
      if (passwordDialogWindow && !passwordDialogWindow.isDestroyed()) {
        passwordDialogWindow.focus();
      }
    });

    // 监听窗口聚焦事件
    passwordDialogWindow.on('focus', () => {
      console.log('[PasswordDialog] 窗口获得焦点');
    });

    // 监听窗口失焦事件（托盘场景下可能被其他窗口遮挡）
    passwordDialogWindow.on('blur', () => {
      console.log('[PasswordDialog] 窗口失去焦点');
      // 如果窗口失去焦点，尝试重新聚焦（延迟一点，避免循环）
      if (passwordDialogWindow && !passwordDialogWindow.isDestroyed() && isTrayContext) {
        setTimeout(() => {
          if (passwordDialogWindow && !passwordDialogWindow.isDestroyed() && passwordDialogWindow.isVisible()) {
            passwordDialogWindow.focus();
          }
        }, 200);
      }
    });

    // 窗口准备好后显示
    passwordDialogWindow.once('ready-to-show', () => {
      if (passwordDialogWindow) {
        // 确保窗口显示并聚焦（托盘场景下特别重要）
        passwordDialogWindow.show();

        // 强制聚焦和置顶（托盘场景下确保窗口可见）
        setTimeout(() => {
          if (passwordDialogWindow && !passwordDialogWindow.isDestroyed()) {
            passwordDialogWindow.focus();
            passwordDialogWindow.moveTop();
            // macOS 特定：确保窗口在最前面
            if (process.platform === 'darwin') {
              passwordDialogWindow.setAlwaysOnTop(true, 'screen-saver');
              setTimeout(() => {
                if (passwordDialogWindow && !passwordDialogWindow.isDestroyed()) {
                  passwordDialogWindow.setAlwaysOnTop(true, 'normal');
                }
              }, 100);
            }
          }
        }, 100);

        // 发送对话框数据
        passwordDialogWindow.webContents.send('password-dialog-data', {
          title: options.title,
          message: options.message,
          label: options.label || '密码:',
          cancelText: options.cancelText || '取消',
          confirmText: options.confirmText || '确定',
          emptyPasswordText: options.emptyPasswordText || '密码不能为空'
        });

        console.log('[PasswordDialog] 密码对话框已显示', {
          isTrayContext,
          hasParent,
          parentWindow: hasParent ? (parentWindow === trayDevicesWindow ? '托盘窗口' : '主窗口') : '无',
          position: passwordDialogWindow.getPosition(),
          visible: passwordDialogWindow.isVisible(),
          focused: passwordDialogWindow.isFocused()
        });

        // 托盘场景下，添加超时检测，确保窗口能显示
        if (isTrayContext) {
          setTimeout(() => {
            if (passwordDialogWindow && !passwordDialogWindow.isDestroyed()) {
              if (!passwordDialogWindow.isVisible()) {
                console.warn('[PasswordDialog] 窗口未显示，强制显示');
                passwordDialogWindow.show();
              }
              if (!passwordDialogWindow.isFocused()) {
                console.warn('[PasswordDialog] 窗口未聚焦，强制聚焦');
                passwordDialogWindow.focus();
                passwordDialogWindow.moveTop();
              }
            }
          }, 500);
        }
      }
    });

    // 处理对话框响应
    const responseHandler = (event: any, data: { password?: string; canceled: boolean }) => {
      if (passwordDialogWindow && event.sender === passwordDialogWindow.webContents) {
        // 移除监听器
        ipcMain.removeListener('password-dialog-response', responseHandler);

        // 关闭窗口
        passwordDialogWindow.close();
        passwordDialogWindow = null;

        // 返回结果
        if (data.canceled) {
          resolve(null);
        } else {
          resolve(data.password || null);
        }
      }
    };

    ipcMain.once('password-dialog-response', responseHandler);

    // 窗口关闭时清理
    passwordDialogWindow.on('closed', () => {
      if (passwordDialogWindow) {
        ipcMain.removeListener('password-dialog-response', responseHandler);
        passwordDialogWindow = null;
        resolve(null);
      }
    });
  });
}

export function closePasswordDialog(): void {
  if (passwordDialogWindow) {
    passwordDialogWindow.close();
    passwordDialogWindow = null;
  }
}
