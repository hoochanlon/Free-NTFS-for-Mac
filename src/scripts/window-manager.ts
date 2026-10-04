import { BrowserWindow, app, screen, nativeTheme } from 'electron';
import * as path from 'path';
import { SettingsManager, WINDOW_SIZE_CONFIG } from './utils/settings';
import { isTrayInitialized, getTrayBounds } from './utils/tray-manager';
import {
  MODULE_WINDOW_CONFIG,
  LOGS_WINDOW_CONFIG,
  TRAY_DEVICES_WINDOW_CONFIG
} from '../config/window-config';

// 窗口引用
export let mainWindow: BrowserWindow | null = null;
export let logsWindow: BrowserWindow | null = null;
export let aboutWindow: BrowserWindow | null = null;
export let trayDevicesWindow: BrowserWindow | null = null;
export const moduleWindows: Map<string, BrowserWindow> = new Map();

// 创建主窗口
export async function createMainWindow(): Promise<BrowserWindow> {
  const appPath = app.getAppPath();

  // 从设置中读取窗口尺寸
  const settings = await SettingsManager.getSettings();
  const windowWidth = settings.windowWidth || WINDOW_SIZE_CONFIG.defaultWidth;
  const windowHeight = settings.windowHeight || WINDOW_SIZE_CONFIG.defaultHeight;

  const initialTheme = await resolveInitialWindowTheme();

  mainWindow = new BrowserWindow({
    width: windowWidth,
    height: windowHeight,
    minWidth: WINDOW_SIZE_CONFIG.minWidth,
    minHeight: WINDOW_SIZE_CONFIG.minHeight,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true,
      backgroundThrottling: false
    },
    // 主界面保留自定义标题栏（有系统红黄绿按钮）
    titleBarStyle: 'hidden',
    frame: false,
    backgroundColor: getThemeBackgroundColor(initialTheme),
    show: false
  });

  const htmlPath = path.join(appPath, 'src', 'html', 'index.html');

  // 在 DOM 准备好时立即更新背景色，避免残影
  // 使用 dom-ready 事件，在 DOM 准备好但页面还未完全渲染时更新
  mainWindow.webContents.once('dom-ready', () => {
    if (mainWindow) {
      void applyWindowTheme(mainWindow, initialTheme);
    }
  });

  mainWindow.loadFile(htmlPath).catch((error: Error) => {
    console.error('Failed to load HTML:', error);
    console.error('App path:', appPath);
    console.error('HTML path:', htmlPath);
    console.error('__dirname:', __dirname);
  });

  mainWindow.webContents.on('did-fail-load', (_event: any, errorCode: number, errorDescription: string, validatedURL: string) => {
    console.error('Failed to load page:', errorCode, errorDescription, validatedURL);
  });

  mainWindow.once('ready-to-show', () => {
    if (mainWindow) {
      // 确保背景色已更新（双重保险）
      void applyWindowTheme(mainWindow);
      // 首次创建窗口时总是显示
      // 只有在托盘模式下，用户关闭窗口后，再次通过 activate 事件创建时才隐藏
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

  // 监听窗口关闭事件，如果启用托盘模式则最小化到托盘
  mainWindow.on('close', async (event: any) => {
    const settings = await SettingsManager.getSettings();
    if (settings.trayMode && isTrayInitialized()) {
      // 如果启用托盘模式，隐藏窗口而不是关闭
      event.preventDefault();
      mainWindow?.hide();
    }
    // 否则正常关闭窗口
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
    ...LOGS_WINDOW_CONFIG,
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

const THEME_BACKGROUND_COLORS = {
  light: '#ffffff',
  dark: '#1d1d1f'
} as const;

type AppTheme = keyof typeof THEME_BACKGROUND_COLORS;

function normalizeTheme(theme: unknown): AppTheme {
  return theme === 'dark' ? 'dark' : 'light';
}

function getThemeBackgroundColor(theme: AppTheme = 'light'): string {
  return THEME_BACKGROUND_COLORS[theme];
}

async function readWindowTheme(window: BrowserWindow): Promise<AppTheme> {
  try {
    const theme = await window.webContents.executeJavaScript(`
      (function() {
        try {
          return localStorage.getItem('app-theme') === 'dark' ? 'dark' : 'light';
        } catch (e) {
          return 'light';
        }
      })();
    `);
    return normalizeTheme(theme);
  } catch {
    return 'light';
  }
}

async function resolveInitialWindowTheme(): Promise<AppTheme> {
  if (mainWindow && !mainWindow.isDestroyed()) {
    return readWindowTheme(mainWindow);
  }
  return nativeTheme.shouldUseDarkColors ? 'dark' : 'light';
}

async function applyWindowTheme(window: BrowserWindow, theme?: AppTheme): Promise<void> {
  if (!window || window.isDestroyed()) return;

  const resolvedTheme = theme || await readWindowTheme(window);
  window.setBackgroundColor(getThemeBackgroundColor(resolvedTheme));

  await window.webContents.executeJavaScript(`
    (function() {
      const isLight = ${resolvedTheme === 'light'};
      document.documentElement.classList.toggle('light-theme', isLight);
      if (document.body) {
        document.body.classList.toggle('light-theme', isLight);
      }
      try {
        localStorage.setItem('app-theme', isLight ? 'light' : 'dark');
      } catch (e) {}
    })();
  `).catch(() => {});
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

  const moduleTheme = await resolveInitialWindowTheme();
  const moduleWindow = new BrowserWindow({
    ...MODULE_WINDOW_CONFIG,
    // 允许用户自由调整窗口大小，不设置最大尺寸限制
    resizable: true,
    // 移除 parent 属性，允许窗口独立调整大小
    // parent: mainWindow || undefined, // 注释掉，避免子窗口调整大小受限
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true
    },
    titleBarStyle: 'hidden',
    frame: false,
    backgroundColor: getThemeBackgroundColor(moduleTheme),
    show: false
  });

  const modulePath = path.join(appPath, htmlFile);
  await moduleWindow.loadFile(modulePath);

  moduleWindow.webContents.on('dom-ready', () => {
    void applyWindowTheme(moduleWindow, moduleTheme);
  });

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

// 创建托盘设备窗口（替代菜单，实现真正的实时更新）
export async function createTrayDevicesWindow(): Promise<BrowserWindow | null> {
  // 如果窗口已存在且未销毁，切换显示/隐藏
  if (trayDevicesWindow && !trayDevicesWindow.isDestroyed()) {
    if (trayDevicesWindow.isVisible()) {
      trayDevicesWindow.hide();
    } else {
      // 在显示窗口前，先强制刷新设备列表（确保显示最新状态）
      try {
        await trayDevicesWindow.webContents.executeJavaScript(`
          if (typeof window !== 'undefined' && window.refreshDevices) {
            window.refreshDevices(true);
          }
        `);
      } catch (error) {
        // 忽略错误，继续显示窗口
      }

      await applyWindowTheme(trayDevicesWindow);
      trayDevicesWindow.setOpacity(1);
      trayDevicesWindow.show();
      trayDevicesWindow.focus();
    }
    return trayDevicesWindow;
  }

  const appPath = app.getAppPath();

  // 获取主显示器的工作区域
  const primaryDisplay = screen.getPrimaryDisplay();
  const { width: screenWidth, height: screenHeight } = primaryDisplay.workAreaSize;
  const { x: screenX, y: screenY } = primaryDisplay.workArea;

  // 使用更小的窗口尺寸，适合托盘弹出
  // 初始宽度使用最小宽度（因为窗口是固定大小的）
  const windowWidth = TRAY_DEVICES_WINDOW_CONFIG.minWidth;
  const windowHeight = Math.min(TRAY_DEVICES_WINDOW_CONFIG.maxHeight, screenHeight - 80);

  // 计算窗口位置（在托盘下方）
  let windowX: number;
  let windowY: number;

  // 尝试获取托盘图标的位置
  const trayBounds = getTrayBounds();

  if (trayBounds && trayBounds.x >= 0 && trayBounds.y >= 0 && trayBounds.width > 0 && trayBounds.height > 0) {
    // 将窗口放在托盘图标下方，水平居中对齐，完全贴合
    const trayCenterX = trayBounds.x + (trayBounds.width / 2);
    windowX = Math.round(trayCenterX - (windowWidth / 2));
    windowY = Math.round(trayBounds.y + trayBounds.height); // 完全贴合托盘底部，0间距
  } else {
    // 如果无法获取托盘位置，使用屏幕顶部中央
    windowX = screenX + (screenWidth - windowWidth) / 2;
    windowY = screenY;
  }

  const trayTheme = await resolveInitialWindowTheme();
  trayDevicesWindow = new BrowserWindow({
    width: windowWidth,
    height: windowHeight,
    minWidth: TRAY_DEVICES_WINDOW_CONFIG.minWidth,
    minHeight: TRAY_DEVICES_WINDOW_CONFIG.heightFor1Device, // 使用1个设备的高度作为最小高度，允许窗口更小
    maxWidth: TRAY_DEVICES_WINDOW_CONFIG.maxWidth,
    maxHeight: TRAY_DEVICES_WINDOW_CONFIG.maxHeight,
    x: windowX,
    y: windowY,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true
    },
    frame: false, // 无边框窗口
    transparent: false,
    backgroundColor: getThemeBackgroundColor(trayTheme),
    resizable: false, // 固定大小，像系统菜单
    movable: false, // 托盘弹窗固定位置，不允许用户拖动
    minimizable: false, // 托盘弹窗不需要最小化
    maximizable: false, // 托盘弹窗不需要最大化
    alwaysOnTop: false,
    skipTaskbar: true, // 不在任务栏显示
    show: false,
    hasShadow: true,
    opacity: 0, // 初始透明度为0，避免残影
    // macOS 特定设置
    ...(process.platform === 'darwin' ? {
      visualEffectState: 'active'
    } : {})
  });

  // 在窗口创建后立即设置一个标识，用于在页面中识别
  trayDevicesWindow.webContents.on('did-attach-webview', () => {
    // 这个事件可能不会触发，但保留作为备用
  });

  // 直接使用主窗口的设备页面，保持界面一致性
  const trayDevicesPath = path.join(appPath, 'src', 'html', 'devices.html');

  // 监听加载错误
  trayDevicesWindow.webContents.on('did-fail-load', (_event: any, errorCode: number, errorDescription: string, validatedURL: string) => {
    console.error('托盘设备窗口加载失败:', errorCode, errorDescription, validatedURL);
  });

  // 在页面开始加载时就注入脚本，确保类在 DOM 准备好之前就添加
  trayDevicesWindow.webContents.on('dom-ready', () => {
    if (!trayDevicesWindow || trayDevicesWindow.isDestroyed()) return;
    void applyWindowTheme(trayDevicesWindow, trayTheme);
    trayDevicesWindow.webContents.executeJavaScript(`
      if (document.body) {
        document.body.classList.add('tray-window');
      }
    `).catch(() => {});
  });

  await trayDevicesWindow.loadFile(trayDevicesPath).catch((error: Error) => {
    console.error('加载托盘设备窗口失败:', error);
    console.error('App path:', appPath);
    console.error('HTML path:', trayDevicesPath);
  });

  // 开发模式下为托盘窗口打开 DevTools（方便调试）
  // 说明：托盘窗口初始是 show:false + opacity:0，放到 ready-to-show 更稳定
  const shouldOpenTrayDevTools = process.argv.includes('--dev');

  // 在页面加载完成后更新背景色和添加标识
  trayDevicesWindow.webContents.once('did-finish-load', async () => {
    if (trayDevicesWindow) {
      // 确保类已添加
      await trayDevicesWindow.webContents.executeJavaScript(`
        if (document.body && !document.body.classList.contains('tray-window')) {
          document.body.classList.add('tray-window');
        }
      `).catch(() => {});

      // 等待一小段时间确保类已添加，然后触发设备列表重新渲染
      setTimeout(async () => {
        if (trayDevicesWindow && !trayDevicesWindow.isDestroyed()) {
          try {
            await trayDevicesWindow.webContents.executeJavaScript(`
              // 确保类已添加
              if (document.body && !document.body.classList.contains('tray-window')) {
                document.body.classList.add('tray-window');
              }
              // 触发设备列表重新渲染以应用新样式
              if (typeof window !== 'undefined' && window.refreshDevices) {
                window.refreshDevices();
              } else if (typeof window !== 'undefined' && window.renderDevices) {
                window.renderDevices();
              }
            `);
          } catch (error) {
            // 窗口可能已关闭，静默处理
          }
        }
      }, 200);

      void applyWindowTheme(trayDevicesWindow, trayTheme);

      // 在窗口加载完成后，尝试重新获取托盘位置并调整窗口位置
      // 因为在 macOS 上，托盘位置可能在窗口创建时还未完全初始化
      setTimeout(() => {
        if (trayDevicesWindow && !trayDevicesWindow.isDestroyed()) {
          const trayBounds = getTrayBounds();
          if (trayBounds && trayBounds.x >= 0 && trayBounds.y >= 0 && trayBounds.width > 0 && trayBounds.height > 0) {
            const [currentWidth] = trayDevicesWindow.getSize();
            const trayCenterX = trayBounds.x + (trayBounds.width / 2);
            // 窗口水平居中对齐托盘图标，顶部紧贴托盘底部（像系统菜单）
            const newX = Math.round(trayCenterX - (currentWidth / 2));
            const newY = Math.round(trayBounds.y + trayBounds.height);

            trayDevicesWindow.setPosition(newX, newY, false);
          }
        }
      }, 100); // 延迟100ms，确保托盘位置已初始化
    }
  });

  trayDevicesWindow.once('ready-to-show', async () => {
    if (trayDevicesWindow) {
      // DevTools：仅开发模式下打开（使用 detach，避免被主窗口 DevTools 混淆）
      if (shouldOpenTrayDevTools && !trayDevicesWindow.webContents.isDevToolsOpened()) {
        console.log('[TrayWindow] Opening DevTools (detach)...');
        trayDevicesWindow.webContents.openDevTools({ mode: 'detach' });
      }

      await applyWindowTheme(trayDevicesWindow, trayTheme);

      // 在显示前重新计算位置，确保贴合托盘（像系统菜单一样）
      const trayBounds = getTrayBounds();
      if (trayBounds && trayBounds.x >= 0 && trayBounds.y >= 0 && trayBounds.width > 0 && trayBounds.height > 0) {
        const [currentWidth] = trayDevicesWindow.getSize();
        // 计算托盘中心点
        const trayCenterX = trayBounds.x + (trayBounds.width / 2);
        // 窗口水平居中对齐托盘图标
        const newX = Math.round(trayCenterX - (currentWidth / 2));
        // 窗口顶部紧贴托盘底部（0间距，像系统菜单）
        const newY = Math.round(trayBounds.y + trayBounds.height);
        trayDevicesWindow.setPosition(newX, newY, false);
      }
      // 先设置不透明，再显示，避免残影
      trayDevicesWindow.setOpacity(1);
      trayDevicesWindow.show();
      trayDevicesWindow.focus();
    }
  });

  // 窗口关闭时清理引用
  trayDevicesWindow.on('closed', () => {
    trayDevicesWindow = null;
  });

  return trayDevicesWindow;
}

// 切换托盘设备窗口显示/隐藏
export async function toggleTrayDevicesWindow(): Promise<void> {
  if (trayDevicesWindow && !trayDevicesWindow.isDestroyed()) {
    if (trayDevicesWindow.isVisible()) {
      trayDevicesWindow.hide();
    } else {
      // 在显示窗口前，先强制刷新设备列表（确保显示最新状态）
      try {
        await trayDevicesWindow.webContents.executeJavaScript(`
          if (typeof window !== 'undefined' && window.refreshDevices) {
            window.refreshDevices(true);
          }
        `);
      } catch (error) {
        // 忽略错误，继续显示窗口
      }

      // 每次显示时都重新计算位置，确保贴合托盘（像系统菜单一样）
      const trayBounds = getTrayBounds();
      if (trayBounds && trayBounds.x >= 0 && trayBounds.y >= 0 && trayBounds.width > 0 && trayBounds.height > 0) {
        const [currentWidth] = trayDevicesWindow.getSize();
        const trayCenterX = trayBounds.x + (trayBounds.width / 2);
        // 窗口水平居中对齐托盘图标，顶部紧贴托盘底部（像系统菜单）
        const newX = Math.round(trayCenterX - (currentWidth / 2));
        const newY = Math.round(trayBounds.y + trayBounds.height);
        trayDevicesWindow.setPosition(newX, newY, false);
      }
      await applyWindowTheme(trayDevicesWindow);
      trayDevicesWindow.setOpacity(1);
      trayDevicesWindow.show();
      trayDevicesWindow.focus();
    }
  } else {
    await createTrayDevicesWindow();
  }
}

// 根据设备数量调整托盘窗口高度
export function adjustTrayWindowHeightByDeviceCount(deviceCount: number): void {
  if (!trayDevicesWindow || trayDevicesWindow.isDestroyed()) {
    console.log('[调整窗口高度] 窗口不存在或已销毁');
    return;
  }

  let targetHeight: number;

  if (deviceCount === 1) {
    // 1个设备：使用硬编码的较小高度
    targetHeight = TRAY_DEVICES_WINDOW_CONFIG.heightFor1Device;
  } else if (deviceCount === 2) {
    // 2个设备：使用硬编码的中等高度
    targetHeight = TRAY_DEVICES_WINDOW_CONFIG.heightFor2Devices;
  } else {
    // 3个设备及以上：使用配置的最大高度
    targetHeight = TRAY_DEVICES_WINDOW_CONFIG.maxHeight;
  }

  // 获取屏幕高度，确保窗口不会超出屏幕
  const primaryDisplay = screen.getPrimaryDisplay();
  const { height: screenHeight } = primaryDisplay.workAreaSize;
  const maxAllowedHeight = screenHeight - 80; // 留出一些边距
  targetHeight = Math.min(targetHeight, maxAllowedHeight);

  // 注意：不强制使用 minHeight，允许窗口更小（1个或2个设备时）
  // 但确保不超过 maxHeight
  targetHeight = Math.min(targetHeight, TRAY_DEVICES_WINDOW_CONFIG.maxHeight);

  // 调整窗口高度
  const [currentWidth, currentHeight] = trayDevicesWindow.getSize();

  console.log('[调整窗口高度]', {
    deviceCount,
    currentHeight,
    targetHeight,
    heightFor1Device: TRAY_DEVICES_WINDOW_CONFIG.heightFor1Device,
    heightFor2Devices: TRAY_DEVICES_WINDOW_CONFIG.heightFor2Devices,
    maxHeight: TRAY_DEVICES_WINDOW_CONFIG.maxHeight
  });

  // 只有当目标高度与当前高度不同时才调整
  if (Math.abs(targetHeight - currentHeight) > 5) {
    trayDevicesWindow.setSize(currentWidth, targetHeight, false);
    console.log('[调整窗口高度] 已调整到:', targetHeight);
  } else {
    console.log('[调整窗口高度] 高度无需调整，当前高度:', currentHeight);
  }
}

// 显示主窗口并关闭托盘窗口
export async function showMainWindowAndCloseTray(devices: unknown[] = []): Promise<void> {
  if (!mainWindow || mainWindow.isDestroyed()) {
    await createMainWindow();
  }
  if (!mainWindow || mainWindow.isDestroyed()) return;

  const devicePayload = JSON.stringify(devices).replace(/</g, '\\u003c');
  try {
    const rendered = await mainWindow.webContents.executeJavaScript(`
      (async () => {
        const devices = ${devicePayload};
        const deadline = Date.now() + 1500;
        while (typeof window.applyDevicesBeforeShow !== 'function' && Date.now() < deadline) {
          await new Promise(resolve => setTimeout(resolve, 16));
        }
        if (typeof window.applyDevicesBeforeShow !== 'function') return false;

        await window.applyDevicesBeforeShow(devices);
        await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
        return document.querySelectorAll('#devicesList .device-item').length === devices.length;
      })();
    `, true);
    if (rendered !== true && devices.length > 0) {
      console.warn('[主窗口] 显示前设备未完成渲染');
    }
  } catch (error) {
    console.warn('[主窗口] 显示前同步设备失败:', error);
  }

  mainWindow.show();
  mainWindow.focus();

  if (trayDevicesWindow && !trayDevicesWindow.isDestroyed()) {
    trayDevicesWindow.hide();
  }
}

