import { Tray, nativeImage, app } from 'electron';
import * as path from 'path';
import * as fs from 'fs';
import { createTrayIcon } from './tray-icons';
import { toggleTrayDevicesWindow, mainWindow } from '../window-manager';

// 托盘图标引用
let tray: Tray | null = null;

// 注意：托盘菜单已完全替换为 BrowserWindow
// 点击托盘图标时会显示 BrowserWindow 窗口，实现真正的实时更新

/**
 * 初始化托盘
 */
export async function initTray(): Promise<void> {
  if (tray) {
    return; // 已经初始化
  }

  try {
    let icon = createTrayIcon();

    // 如果图标为空，尝试使用应用图标
    if (icon.isEmpty()) {
      const appPath = app.getAppPath();
      // 尝试多个可能的应用图标路径
      const appIconPaths = [
        path.join(appPath, '..', '..', 'Contents', 'Resources', 'app.icns'),
        path.join(appPath, '..', '..', 'Resources', 'app.icns'),
        path.join(appPath, 'app.icns')
      ];

      for (const appIconPath of appIconPaths) {
        if (fs.existsSync(appIconPath)) {
          try {
            const appIconImage = nativeImage.createFromPath(appIconPath);
            if (!appIconImage.isEmpty()) {
              icon = appIconImage.resize({ width: 22, height: 22 });
              break;
            }
          } catch (error) {
            // 静默处理图标加载失败
          }
        }
      }
    }

    // 创建托盘（即使图标为空，Electron 也会使用默认图标）
    tray = new Tray(icon);

    // 在 macOS 上，确保图标被设置为模板图标（单色图标，会自动显示为白色）
    if (process.platform === 'darwin' && !icon.isEmpty()) {
      try {
        // 确保使用正确的图标尺寸（macOS 菜单栏标准尺寸）
        const templateIcon = icon.resize({ width: 22, height: 22 });
        // 在 macOS 上，使用 setImage 方法
        // 如果图标是单色的（黑白），系统会自动识别为模板图标并显示为白色
        tray.setImage(templateIcon);
      } catch (error) {
        // 静默处理图标设置失败
      }
    }

    // 设置托盘提示
    tray.setToolTip('Nigate - NTFS 设备管理\n点击显示设备列表');

    // 点击托盘图标时的处理逻辑：如果主窗口显示则聚焦主窗口，否则显示托盘设备窗口
    tray.on('click', async () => {
      try {
        // 检查主窗口是否显示
        if (mainWindow && !mainWindow.isDestroyed() && mainWindow.isVisible()) {
          // 如果主窗口已显示，则聚焦主窗口
          mainWindow.show();
          mainWindow.focus();
        } else {
          // 如果主窗口未显示，则显示托盘设备窗口
          await toggleTrayDevicesWindow();
        }
      } catch (error) {
        console.error('处理托盘点击失败:', error);
      }
    });

    // 在 macOS 上，设置忽略双击事件，只响应单击
    if (process.platform === 'darwin') {
      tray.setIgnoreDoubleClickEvents(true);
    }
  } catch (error) {
    console.error('初始化托盘失败:', error);
    // 清理可能创建的部分托盘对象
    if (tray) {
      try {
        tray.destroy();
      } catch (e) {
        // 忽略销毁错误
      }
      tray = null;
    }
    // 即使失败也不抛出错误，避免影响应用启动
  }
}

/**
 * 更新托盘（已替换为 BrowserWindow，此函数保留用于兼容性）
 * BrowserWindow 会自动实时更新，无需手动调用
 */
export async function updateTrayMenu(forceRefresh: boolean = false): Promise<void> {
  // BrowserWindow 会自动更新，无需手动刷新
}

/**
 * 销毁托盘
 */
export function destroyTray(): void {
  if (tray) {
    tray.destroy();
    tray = null;
  }
}

/**
 * 检查托盘是否已初始化
 */
export function isTrayInitialized(): boolean {
  return tray !== null;
}

/**
 * 获取托盘图标的位置（bounds）
 * 返回托盘图标的 x, y, width, height
 */
export function getTrayBounds(): { x: number; y: number; width: number; height: number } | null {
  if (!tray) {
    return null;
  }
  try {
    return tray.getBounds();
  } catch (error) {
    console.warn('获取托盘位置失败:', error);
    return null;
  }
}
