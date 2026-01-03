import { BrowserWindow, app, Event } from 'electron';
import * as path from 'path';
import { SettingsManager, WINDOW_SIZE_CONFIG } from './utils/settings';

// 窗口引用
export let mainWindow: BrowserWindow | null = null;
export let logsWindow: BrowserWindow | null = null;
export let aboutWindow: BrowserWindow | null = null;
export const moduleWindows: Map<string, BrowserWindow> = new Map();

// 创建主窗口
export async function createMainWindow(): Promise<BrowserWindow> {
  const appPath = app.getAppPath();

  // 从设置中读取窗口尺寸
  const settings = await SettingsManager.getSettings();
  const windowWidth = settings.windowWidth || WINDOW_SIZE_CONFIG.defaultWidth;
  const windowHeight = settings.windowHeight || WINDOW_SIZE_CONFIG.defaultHeight;

  mainWindow = new BrowserWindow({
    width: windowWidth,
    height: windowHeight,
    minWidth: WINDOW_SIZE_CONFIG.minWidth,
    minHeight: WINDOW_SIZE_CONFIG.minHeight,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true
    },
    titleBarStyle: 'hidden',
    frame: false,
    backgroundColor: '#1e1e1e',
    show: false
  });

  const htmlPath = path.join(appPath, 'src', 'html', 'index.html');

  mainWindow.loadFile(htmlPath).catch((error: Error) => {
    console.error('Failed to load HTML:', error);
    console.error('App path:', appPath);
    console.error('HTML path:', htmlPath);
    console.error('__dirname:', __dirname);
  });

  mainWindow.webContents.on('did-fail-load', (event: Event, errorCode: number, errorDescription: string, validatedURL: string) => {
    console.error('Failed to load page:', errorCode, errorDescription, validatedURL);
  });

  mainWindow.once('ready-to-show', () => {
    if (mainWindow) {
      mainWindow.show();
    }
  });

  // 开发模式下打开 DevTools
  if (process.argv.includes('--dev')) {
    mainWindow.webContents.openDevTools();
  }

  // 监听窗口大小改变，自动保存设置
  let resizeTimeout: NodeJS.Timeout | null = null;
  mainWindow.on('resize', () => {
    if (mainWindow && !mainWindow.isDestroyed()) {
      // 防抖：延迟保存，避免频繁写入
      if (resizeTimeout) {
        clearTimeout(resizeTimeout);
      }
      resizeTimeout = setTimeout(async () => {
        const [width, height] = mainWindow!.getSize();
        await SettingsManager.saveSettings({
          windowWidth: width,
          windowHeight: height
        });
      }, 500); // 500ms 后保存
    }
  });

  return mainWindow;
}

// 创建日志窗口
export async function createLogsWindow(): Promise<BrowserWindow | null> {
  if (logsWindow && !logsWindow.isDestroyed()) {
    logsWindow.focus();
    return logsWindow;
  }

  const appPath = app.getAppPath();
  logsWindow = new BrowserWindow({
    width: 800,
    height: 600,
    minWidth: 600,
    minHeight: 400,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true
    },
    titleBarStyle: 'hidden',
    frame: false,
    backgroundColor: '#1e1e1e',
    parent: mainWindow || undefined,
    show: false
  });

  const logsPath = path.join(appPath, 'src', 'html', 'logs.html');
  await logsWindow.loadFile(logsPath);

  logsWindow.once('ready-to-show', () => {
    if (logsWindow) {
      logsWindow.show();
    }
  });

  logsWindow.on('closed', () => {
    logsWindow = null;
  });

  return logsWindow;
}

// 关闭日志窗口
export function closeLogsWindow(): void {
  if (logsWindow) {
    logsWindow.close();
    logsWindow = null;
  }
}

// 创建模块窗口
export async function createModuleWindow(moduleName: string): Promise<BrowserWindow> {
  if (moduleWindows.has(moduleName)) {
    const existingWindow = moduleWindows.get(moduleName);
    if (existingWindow && !existingWindow.isDestroyed()) {
      existingWindow.focus();
      return existingWindow;
    } else {
      moduleWindows.delete(moduleName);
    }
  }

  const appPath = app.getAppPath();
  const htmlFiles: Record<string, string> = {
    'dependencies': path.join('src', 'html', 'dependencies.html'),
    'devices': path.join('src', 'html', 'devices.html')
  };

  const htmlFile = htmlFiles[moduleName];
  if (!htmlFile) {
    throw new Error(`未知的模块: ${moduleName}`);
  }

  const moduleWindow = new BrowserWindow({
    width: 900,
    height: 700,
    minWidth: 800,
    minHeight: 600,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true
    },
    titleBarStyle: 'hidden',
    frame: false,
    backgroundColor: '#1e1e1e',
    parent: mainWindow || undefined,
    show: false
  });

  const modulePath = path.join(appPath, htmlFile);
  await moduleWindow.loadFile(modulePath);

  moduleWindow.once('ready-to-show', () => {
    if (moduleWindow && !moduleWindow.isDestroyed()) {
      moduleWindow.show();
    }
  });

  moduleWindow.on('closed', () => {
    moduleWindows.delete(moduleName);
  });

  moduleWindows.set(moduleName, moduleWindow);
  return moduleWindow;
}

// 关闭模块窗口
export function closeModuleWindow(window: BrowserWindow): void {
  window.close();
}
