import { app } from 'electron';
import * as path from 'path';
import * as fs from 'fs';
import { mainWindow } from './window-manager';

// 热重载功能（仅开发模式）
export function setupHotReload(): void {
  if (!process.argv.includes('--dev')) {
    return;
  }

  // 方法1: 使用 electron-reloader（如果已安装）
  try {
    require('electron-reloader')(module, {
      debug: true,
      watchRenderer: true,
      ignore: ['node_modules', 'scripts', '*.log']
    });
    // 热重载已启用，静默模式
  } catch (err) {
    // 方法2: 手动实现热重载（监听 HTML/CSS/JS 文件变化）

    const appPath = app.getAppPath();
    const watchFiles = [
      path.join(appPath, 'src', 'html', 'index.html'),
      path.join(appPath, 'styles.css'),
      path.join(appPath, 'scripts', 'renderer.js')
    ];

    watchFiles.forEach(file => {
      if (fs.existsSync(file)) {
        fs.watchFile(file, { interval: 500 }, () => {
          if (mainWindow && !mainWindow.isDestroyed()) {
            mainWindow.reload();
          }
        });
      }
    });
  }
}
