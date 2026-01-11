// 密码输入对话框窗口管理器
import { BrowserWindow, ipcMain, app, screen } from 'electron';
import * as path from 'path';
import { mainWindow } from '../window-manager';

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

    // 获取父窗口（如果有）
    const parentWindow = mainWindow || BrowserWindow.getFocusedWindow();

    // 计算居中位置
    const primaryDisplay = screen.getPrimaryDisplay();
    const { width: screenWidth, height: screenHeight } = primaryDisplay.workAreaSize;
    const dialogWidth = 450;
    const dialogHeight = 280;
    const x = Math.floor((screenWidth - dialogWidth) / 2);
    const y = Math.floor((screenHeight - dialogHeight) / 2);

    // 创建对话框窗口
    passwordDialogWindow = new BrowserWindow({
      width: dialogWidth,
      height: dialogHeight,
      x: parentWindow ? undefined : x,
      y: parentWindow ? undefined : y,
      resizable: false,
      minimizable: false,
      maximizable: false,
      modal: true,
      parent: parentWindow || undefined,
      frame: false,
      transparent: true,
      backgroundColor: '#00000000',
      webPreferences: {
        nodeIntegration: true,
        contextIsolation: false
      },
      show: false,
      alwaysOnTop: true
    });

    // 加载对话框 HTML
    const appPath = app.getAppPath();
    const dialogPath = path.join(appPath, 'src/html/password-dialog.html');
    passwordDialogWindow.loadFile(dialogPath);

    // 窗口准备好后显示
    passwordDialogWindow.once('ready-to-show', () => {
      if (passwordDialogWindow) {
        passwordDialogWindow.show();
        // 发送对话框数据
        passwordDialogWindow.webContents.send('password-dialog-data', {
          title: options.title,
          message: options.message,
          label: options.label || '密码:',
          cancelText: options.cancelText || '取消',
          confirmText: options.confirmText || '确定',
          emptyPasswordText: options.emptyPasswordText || '密码不能为空'
        });
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
