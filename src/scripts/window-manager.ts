import { BrowserWindow, app } from 'electron';
import * as path from 'path';

// 窗口引用
export let mainWindow: BrowserWindow | null = null;
export let logsWindow: BrowserWindow | null = null;
export let aboutWindow: BrowserWindow | null = null;
export const moduleWindows: Map<string, BrowserWindow> = new Map();

// 创建主窗口
export function createMainWindow(): BrowserWindow {
  const appPath = app.getAppPath();

  mainWindow = new BrowserWindow({
    width: 900,
    height: 700,
    minWidth: 840,
    minHeight: 660,
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

  mainWindow.loadFile(htmlPath).catch((error) => {
    console.error('Failed to load HTML:', error);
    console.error('App path:', appPath);
    console.error('HTML path:', htmlPath);
    console.error('__dirname:', __dirname);
  });

  mainWindow.webContents.on('did-fail-load', (event, errorCode, errorDescription, validatedURL) => {
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
