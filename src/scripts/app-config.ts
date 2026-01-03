import { app, Menu, shell } from 'electron';
import { openAboutWindow } from './about-window';
import { SettingsManager } from './utils/settings';
import { mainWindow } from './window-manager';
import * as fs from 'fs';
import * as path from 'path';

// 翻译数据缓存
let translations: Record<string, any> = {};

// 加载语言文件
async function loadTranslations(lang: string): Promise<void> {
  try {
    const appPath = app.getAppPath();
    const langFile = path.join(appPath, 'src', 'locales', `${lang}.json`);
    if (fs.existsSync(langFile)) {
      const content = await fs.promises.readFile(langFile, 'utf-8');
      translations = JSON.parse(content);
    } else {
      // 如果文件不存在，使用默认的中文
      const defaultLangFile = path.join(appPath, 'src', 'locales', 'zh-CN.json');
      const content = await fs.promises.readFile(defaultLangFile, 'utf-8');
      translations = JSON.parse(content);
    }
  } catch (error) {
    console.error('加载语言文件失败:', error);
    // 使用硬编码的默认值
    translations = {
      menu: {
        about: '关于',
        services: '服务',
        hide: `隐藏 ${app.getName()}`,
        hideOthers: '隐藏其他',
        showAll: '显示全部',
        quit: '退出',
        file: '文件',
        close: '关闭',
        view: '视图',
        reload: '重新加载',
        forceReload: '强制重新加载',
        toggleDevTools: '切换开发者工具',
        actualSize: '实际大小',
        zoomIn: '放大',
        zoomOut: '缩小',
        toggleFullScreen: '切换全屏',
        window: '窗口',
        minimize: '最小化',
        help: '帮助',
        guide: '指南手册',
        github: 'GitHub 仓库地址'
      }
    };
  }
}

// 获取翻译文本
function t(key: string): string | undefined {
  const keys = key.split('.');
  let value: any = translations;
  for (const k of keys) {
    if (value && typeof value === 'object' && k in value) {
      value = value[k];
    } else {
      return undefined; // 如果找不到翻译，返回 undefined，让 || 操作符可以工作
    }
  }
  return typeof value === 'string' ? value : undefined;
}

// 配置关于面板
export function setupAboutPanel(): void {
  app.setAboutPanelOptions({
    applicationName: 'Nigate',
    applicationVersion: 'v1.3.0',
    copyright: '© 2024 Hoochanlon',
    credits: '基于 ntfs-3g 驱动制作'
  });
}

// 配置应用菜单
export async function setupApplicationMenu(): Promise<void> {
  // 获取当前语言设置
  const settings = await SettingsManager.getSettings();
  let lang = settings.language;

  // 如果选择跟随系统，检测系统语言
  if (lang === 'system') {
    const systemLang = app.getLocale();
    if (systemLang.startsWith('ja')) {
      lang = 'ja';
    } else if (systemLang.startsWith('en')) {
      lang = 'en';
    } else if (systemLang.startsWith('zh-TW') || systemLang.startsWith('zh-Hant')) {
      lang = 'zh-TW';
    } else {
      lang = 'zh-CN';
    }
  }

  // 加载翻译
  await loadTranslations(lang);

  const template: Electron.MenuItemConstructorOptions[] = [
    {
      label: app.getName(),
      submenu: [
        {
          label: t('menu.about') || t('app.about') || '关于',
          click: async () => {
            await openAboutWindow();
          }
        },
        { type: 'separator' },
        {
          label: t('menu.services') || '服务',
          role: 'services',
          submenu: []
        },
        { type: 'separator' },
        {
          label: `${t('menu.hide') || '隐藏'} ${app.getName()}`,
          accelerator: 'Command+H',
          role: 'hide'
        },
        {
          label: t('menu.hideOthers') || '隐藏其他',
          accelerator: 'Command+Option+H',
          role: 'hideOthers'
        },
        {
          label: t('menu.showAll') || '显示全部',
          role: 'unhide'
        },
        { type: 'separator' },
        {
          label: t('menu.quit') || '退出',
          accelerator: 'Command+Q',
          click: () => {
            app.quit();
          }
        }
      ]
    },
    {
      label: t('menu.view') || '视图',
      submenu: [
        { label: t('menu.reload') || '重新加载', accelerator: 'CmdOrCtrl+R', role: 'reload' },
        { label: t('menu.forceReload') || '强制重新加载', accelerator: 'CmdOrCtrl+Shift+R', role: 'forceReload' },
        { label: t('menu.toggleDevTools') || '切换开发者工具', accelerator: 'F12', role: 'toggleDevTools' },
        { type: 'separator' },
        { label: t('menu.actualSize') || '实际大小', accelerator: 'CmdOrCtrl+0', role: 'resetZoom' },
        { label: t('menu.zoomIn') || '放大', accelerator: 'CmdOrCtrl+Plus', role: 'zoomIn' },
        { label: t('menu.zoomOut') || '缩小', accelerator: 'CmdOrCtrl+-', role: 'zoomOut' },
        { type: 'separator' },
        { label: t('menu.toggleFullScreen') || '切换全屏', accelerator: 'Ctrl+Command+F', role: 'togglefullscreen' },
        { type: 'separator' },
        { label: t('menu.close') || '关闭', accelerator: 'Command+W', role: 'close' }
      ]
    },
    {
      label: t('menu.window') || '窗口',
      submenu: [
        { label: t('menu.minimize') || '最小化', accelerator: 'Command+M', role: 'minimize' },
        { label: t('menu.close') || '关闭', accelerator: 'Command+W', role: 'close' }
      ]
    },
    {
      label: t('menu.help') || '帮助',
      submenu: [
        {
          label: t('menu.guide') || t('tabs.help') || '指南手册',
          click: async () => {
            if (mainWindow && !mainWindow.isDestroyed()) {
              mainWindow.webContents.send('switch-tab', 'help');
              mainWindow.focus();
            }
          }
        },
        {
          label: t('menu.github') || 'GitHub 仓库地址',
          click: async () => {
            await shell.openExternal('https://github.com/hoochanlon/Free-NTFS-for-Mac/issues');
          }
        }
      ]
    }
  ];

  const menu = Menu.buildFromTemplate(template);
  Menu.setApplicationMenu(menu);
}

// 重新构建菜单（用于语言切换时）
export async function rebuildApplicationMenu(): Promise<void> {
  await setupApplicationMenu();
}

// 初始化应用配置
export async function setupAppConfig(): Promise<void> {
  setupAboutPanel();
  await setupApplicationMenu();
}
