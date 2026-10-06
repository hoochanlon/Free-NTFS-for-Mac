import { BrowserWindow, app, screen, nativeTheme } from 'electron';
import * as path from 'path';
import { SettingsManager, WINDOW_SIZE_CONFIG } from './utils/settings';
import { isTrayInitialized, getTrayBounds } from './utils/tray-manager';
import ntfsManager from './ntfs-manager';
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
let trayWindowManuallySized = false;

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

const TRAY_THEME_BACKGROUND_COLORS = {
  light: '#F5F4F5',
  dark: '#1d1d1f'
} as const;

type AppTheme = keyof typeof THEME_BACKGROUND_COLORS;

function normalizeTheme(theme: unknown): AppTheme {
  return theme === 'dark' ? 'dark' : 'light';
}

function getThemeBackgroundColor(theme: AppTheme = 'light'): string {
  return THEME_BACKGROUND_COLORS[theme];
}

function getTrayThemeBackgroundColor(theme: AppTheme = 'light'): string {
  return TRAY_THEME_BACKGROUND_COLORS[theme];
}

async function readPersistedTheme(window: BrowserWindow): Promise<AppTheme> {
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

async function readAppliedTheme(window: BrowserWindow): Promise<AppTheme> {
  try {
    const theme = await window.webContents.executeJavaScript(`
      document.documentElement.classList.contains('light-theme') ? 'light' : 'dark'
    `);
    return normalizeTheme(theme);
  } catch {
    return readPersistedTheme(window);
  }
}

async function resolveInitialWindowTheme(): Promise<AppTheme> {
  if (mainWindow && !mainWindow.isDestroyed()) {
    return readAppliedTheme(mainWindow);
  }
  return nativeTheme.shouldUseDarkColors ? 'dark' : 'light';
}

async function applyWindowTheme(window: BrowserWindow, theme?: AppTheme): Promise<void> {
  if (!window || window.isDestroyed()) return;

  const resolvedTheme = theme || await resolveInitialWindowTheme();
  const backgroundColor = window === trayDevicesWindow
    ? getTrayThemeBackgroundColor(resolvedTheme)
    : getThemeBackgroundColor(resolvedTheme);
  window.setBackgroundColor(backgroundColor);

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

/**
 * 隐藏中的托盘窗口会被 Chromium 节流，主题变更要等再次显示才绘制。
 * 切换主题时先在屏幕外以不透明度过完一帧，再恢复隐藏，避免打开时闪出旧主题。
 */
export async function prerenderTrayDevicesTheme(theme: AppTheme): Promise<void> {
  if (!trayDevicesWindow || trayDevicesWindow.isDestroyed() || trayDevicesWindow.isVisible()) return;

  const [width, height] = trayDevicesWindow.getSize();
  trayDevicesWindow.setOpacity(0);
  trayDevicesWindow.setPosition(-10000, -10000, false);
  trayDevicesWindow.showInactive();

  try {
    await trayDevicesWindow.webContents.executeJavaScript(`
      document.documentElement.classList.add('tray-theme-syncing');
    `);
    await applyWindowTheme(trayDevicesWindow, theme);
    await commitTrayDevicesFrame();
    await trayDevicesWindow.webContents.executeJavaScript(`
      document.documentElement.classList.remove('tray-theme-syncing');
    `);
  } finally {
    if (!trayDevicesWindow.isDestroyed()) {
      trayDevicesWindow.hide();
      trayDevicesWindow.setSize(width, height, false);
    }
  }
}

function trayWindowHeightFor(deviceCount: number): number {
  let targetHeight: number;
  if (deviceCount === 1) {
    targetHeight = TRAY_DEVICES_WINDOW_CONFIG.heightFor1Device;
  } else if (deviceCount === 2) {
    targetHeight = TRAY_DEVICES_WINDOW_CONFIG.heightFor2Devices;
  } else {
    targetHeight = TRAY_DEVICES_WINDOW_CONFIG.defaultHeight;
  }

  const { height: screenHeight } = screen.getPrimaryDisplay().workAreaSize;
  return Math.min(
    targetHeight,
    TRAY_DEVICES_WINDOW_CONFIG.maxHeight,
    Math.max(screenHeight - 80, TRAY_DEVICES_WINDOW_CONFIG.minHeight)
  );
}

function positionTrayDevicesWindow(): void {
  if (!trayDevicesWindow || trayDevicesWindow.isDestroyed()) return;

  const trayBounds = getTrayBounds();
  const [currentWidth] = trayDevicesWindow.getSize();
  if (trayBounds && trayBounds.x >= 0 && trayBounds.y >= 0 && trayBounds.width > 0 && trayBounds.height > 0) {
    const trayCenterX = trayBounds.x + (trayBounds.width / 2);
    trayDevicesWindow.setPosition(
      Math.round(trayCenterX - (currentWidth / 2)),
      Math.round(trayBounds.y + trayBounds.height),
      false
    );
    return;
  }

  const primaryDisplay = screen.getPrimaryDisplay();
  const { width: screenWidth } = primaryDisplay.workAreaSize;
  const { x: screenX, y: screenY } = primaryDisplay.workArea;
  trayDevicesWindow.setPosition(
    Math.round(screenX + (screenWidth - currentWidth) / 2),
    screenY,
    false
  );
}

/** 窗口已在屏幕外可见时，强制提交当前帧。 */
async function commitTrayDevicesFrame(): Promise<void> {
  if (!trayDevicesWindow || trayDevicesWindow.isDestroyed()) return;

  await new Promise<void>(resolve => {
    setTimeout(() => {
      trayDevicesWindow?.webContents.invalidate();
      resolve();
    }, 50);
  });
  await new Promise(resolve => setTimeout(resolve, 80));
}

/**
 * 托盘窗口隐藏时 Chromium 不提交绘制。
 * 在屏幕外以不透明度 0 走完一帧，返回时画面已经是最终内容。
 */
async function paintTrayDevicesWindowOffscreen(): Promise<void> {
  if (!trayDevicesWindow || trayDevicesWindow.isDestroyed() || trayDevicesWindow.isVisible()) return;

  const [width, height] = trayDevicesWindow.getSize();
  trayDevicesWindow.setOpacity(0);
  trayDevicesWindow.setPosition(-10000, -10000, false);
  trayDevicesWindow.showInactive();

  try {
    await commitTrayDevicesFrame();
  } finally {
    if (!trayDevicesWindow.isDestroyed()) {
      trayDevicesWindow.hide();
      trayDevicesWindow.setSize(width, height, false);
    }
  }
}

export async function syncHiddenTrayDevicesWindow(devices: unknown[]): Promise<void> {
  if (!trayDevicesWindow || trayDevicesWindow.isDestroyed()) return;

  const visible = trayDevicesWindow.isVisible();
  const payload = JSON.stringify(devices).replace(/</g, '\\u003c');
  if (!visible && !trayWindowManuallySized) {
    trayDevicesWindow.setSize(
      TRAY_DEVICES_WINDOW_CONFIG.defaultWidth,
      trayWindowHeightFor(devices.length),
      false
    );
  }

  try {
    await trayDevicesWindow.webContents.executeJavaScript(`
      (async () => {
        const deadline = Date.now() + 1500;
        const i18n = window.AppUtils && window.AppUtils.I18n;
        while (Date.now() < deadline && (
          typeof window.applyTrayDevicesSnapshot !== 'function' ||
          (i18n && i18n.isReady && !i18n.isReady())
        )) {
          await new Promise(resolve => setTimeout(resolve, 16));
        }
        if (typeof window.applyTrayDevicesSnapshot !== 'function') return false;
        if (typeof window.applyTranslations === 'function') window.applyTranslations();
        return window.applyTrayDevicesSnapshot(${payload});
      })();
    `, true);
    if (!visible) {
      await paintTrayDevicesWindowOffscreen();
    } else if (!trayWindowManuallySized) {
      adjustTrayWindowHeightByDeviceCount(devices.length);
    }
  } catch (error) {
    console.warn('[托盘窗口] 设备状态同步失败:', error);
  }
}

async function revealTrayDevicesWindow(): Promise<void> {
  if (!trayDevicesWindow || trayDevicesWindow.isDestroyed()) return;

  const theme = await resolveInitialWindowTheme();
  const appliedTheme = await readAppliedTheme(trayDevicesWindow);
  if (appliedTheme !== theme) {
    // 主题在隐藏期间没跟上时兜底，正常路径已在切换时预渲染完成
    await prerenderTrayDevicesTheme(theme);
  }

  // 窗口仍不可见。先套用缓存并按设备数定高，再定位显示，避免打开后停在旧画面。
  await syncHiddenTrayDevicesWindow(ntfsManager.getCachedDevices());

  if (!trayDevicesWindow || trayDevicesWindow.isDestroyed()) return;
  positionTrayDevicesWindow();
  trayDevicesWindow.setOpacity(1);
  trayDevicesWindow.show();
  trayDevicesWindow.focus();
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
export async function createTrayDevicesWindow(reveal: boolean = true): Promise<BrowserWindow | null> {
  // 如果窗口已存在且未销毁，切换显示/隐藏
  if (trayDevicesWindow && !trayDevicesWindow.isDestroyed()) {
    if (trayDevicesWindow.isVisible()) {
      trayDevicesWindow.hide();
    } else {
      await revealTrayDevicesWindow();
    }
    return trayDevicesWindow;
  }

  const appPath = app.getAppPath();

  // 获取主显示器的工作区域
  const primaryDisplay = screen.getPrimaryDisplay();
  const { width: screenWidth, height: screenHeight } = primaryDisplay.workAreaSize;
  const { x: screenX, y: screenY } = primaryDisplay.workArea;

  // 使用更小的窗口尺寸，适合托盘弹出
  const windowWidth = TRAY_DEVICES_WINDOW_CONFIG.defaultWidth;
  const windowHeight = Math.min(
    TRAY_DEVICES_WINDOW_CONFIG.defaultHeight,
    TRAY_DEVICES_WINDOW_CONFIG.maxHeight,
    Math.max(screenHeight - 80, TRAY_DEVICES_WINDOW_CONFIG.minHeight)
  );

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
    minHeight: TRAY_DEVICES_WINDOW_CONFIG.minHeight,
    maxWidth: TRAY_DEVICES_WINDOW_CONFIG.maxWidth,
    maxHeight: TRAY_DEVICES_WINDOW_CONFIG.maxHeight,
    x: windowX,
    y: windowY,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true,
      // 托盘窗口大部分时间隐藏，关闭节流才能在切换主题时把新样式画完
      backgroundThrottling: false
    },
    frame: false, // 无边框窗口
    transparent: false,
    backgroundColor: getTrayThemeBackgroundColor(trayTheme),
    resizable: true,
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

  if (process.argv.includes('--dev') && !trayDevicesWindow.webContents.isDevToolsOpened()) {
    trayDevicesWindow.webContents.openDevTools({ mode: 'detach' });
  }

  try {
    await syncHiddenTrayDevicesWindow(ntfsManager.getCachedDevices());
  } catch (error) {
    console.warn('[托盘窗口] 显示前预渲染失败:', error);
  }

  if (reveal && !trayDevicesWindow.isDestroyed()) {
    await revealTrayDevicesWindow();
  }

  trayDevicesWindow.on('resized', () => {
    trayWindowManuallySized = true;
  });

  trayDevicesWindow.on('closed', () => {
    trayDevicesWindow = null;
    trayWindowManuallySized = false;
  });

  return trayDevicesWindow;
}

/**
 * 应用启动后即创建隐藏的托盘窗口。
 * 设备变化只会预渲染已存在的窗口；若等第一次点击才创建，
 * 期间插入的设备不会进入画面，打开后只能看到创建时的空缓存。
 */
export async function ensureTrayDevicesWindow(): Promise<void> {
  if (trayDevicesWindow && !trayDevicesWindow.isDestroyed()) return;

  try {
    await createTrayDevicesWindow(false);
  } catch (error) {
    console.warn('[托盘窗口] 启动时预创建失败:', error);
  }
}

// 切换托盘设备窗口显示/隐藏
export async function toggleTrayDevicesWindow(): Promise<void> {
  if (trayDevicesWindow && !trayDevicesWindow.isDestroyed()) {
    if (trayDevicesWindow.isVisible()) {
      trayDevicesWindow.hide();
    } else {
      await revealTrayDevicesWindow();
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

  if (trayWindowManuallySized) {
    return;
  }

  const [currentWidth, currentHeight] = trayDevicesWindow.getSize();
  const targetHeight = trayWindowHeightFor(deviceCount);

  if (Math.abs(targetHeight - currentHeight) > 5) {
    trayDevicesWindow.setSize(currentWidth, targetHeight, false);
  }
}

export interface PendingMainWindowAction {
  action: string;
  device?: unknown;
}

// 显示主窗口并关闭托盘窗口
export async function showMainWindowAndCloseTray(
  devices: unknown[] = [],
  pendingAction?: PendingMainWindowAction
): Promise<void> {
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

  // 弹窗类操作交给主界面执行，不阻塞托盘侧 IPC
  if (pendingAction) {
    const actionPayload = JSON.stringify(pendingAction).replace(/</g, '\\u003c');
    mainWindow.webContents.executeJavaScript(`
      (async () => {
        const deadline = Date.now() + 1500;
        while (typeof window.runPendingDeviceAction !== 'function' && Date.now() < deadline) {
          await new Promise(resolve => setTimeout(resolve, 16));
        }
        if (typeof window.runPendingDeviceAction === 'function') {
          window.runPendingDeviceAction(${actionPayload});
        }
      })();
    `).catch((error: unknown) => {
      console.warn('[主窗口] 转发托盘操作失败:', error);
    });
  }
}

