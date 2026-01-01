import { app, Menu } from 'electron';
import { openAboutWindow } from './about-window';

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
export function setupApplicationMenu(): void {
  const template: Electron.MenuItemConstructorOptions[] = [
    {
      label: app.getName(),
      submenu: [
        {
          label: `关于 ${app.getName()}`,
          click: async () => {
            await openAboutWindow();
          }
        },
        { type: 'separator' },
        {
          label: '服务',
          role: 'services',
          submenu: []
        },
        { type: 'separator' },
        {
          label: `隐藏 ${app.getName()}`,
          accelerator: 'Command+H',
          role: 'hide'
        },
        {
          label: '隐藏其他',
          accelerator: 'Command+Option+H',
          role: 'hideOthers'
        },
        {
          label: '显示全部',
          role: 'unhide'
        },
        { type: 'separator' },
        {
          label: '退出',
          accelerator: 'Command+Q',
          click: () => {
            app.quit();
          }
        }
      ]
    },
    {
      label: '文件',
      submenu: [
        {
          label: '关闭',
          accelerator: 'Command+W',
          role: 'close'
        }
      ]
    },
    {
      label: '编辑',
      submenu: [
        { label: '撤销', accelerator: 'CmdOrCtrl+Z', role: 'undo' },
        { label: '重做', accelerator: 'Shift+CmdOrCtrl+Z', role: 'redo' },
        { type: 'separator' },
        { label: '剪切', accelerator: 'CmdOrCtrl+X', role: 'cut' },
        { label: '复制', accelerator: 'CmdOrCtrl+C', role: 'copy' },
        { label: '粘贴', accelerator: 'CmdOrCtrl+V', role: 'paste' },
        { label: '全选', accelerator: 'CmdOrCtrl+A', role: 'selectAll' }
      ]
    },
    {
      label: '视图',
      submenu: [
        { label: '重新加载', accelerator: 'CmdOrCtrl+R', role: 'reload' },
        { label: '强制重新加载', accelerator: 'CmdOrCtrl+Shift+R', role: 'forceReload' },
        { label: '切换开发者工具', accelerator: 'F12', role: 'toggleDevTools' },
        { type: 'separator' },
        { label: '实际大小', accelerator: 'CmdOrCtrl+0', role: 'resetZoom' },
        { label: '放大', accelerator: 'CmdOrCtrl+Plus', role: 'zoomIn' },
        { label: '缩小', accelerator: 'CmdOrCtrl+-', role: 'zoomOut' },
        { type: 'separator' },
        { label: '切换全屏', accelerator: 'Ctrl+Command+F', role: 'togglefullscreen' }
      ]
    },
    {
      label: '窗口',
      submenu: [
        { label: '最小化', accelerator: 'Command+M', role: 'minimize' },
        { label: '关闭', accelerator: 'Command+W', role: 'close' }
      ]
    },
    {
      label: '帮助',
      submenu: []
    }
  ];

  const menu = Menu.buildFromTemplate(template);
  Menu.setApplicationMenu(menu);
}

// 初始化应用配置
export function setupAppConfig(): void {
  setupAboutPanel();
  setupApplicationMenu();
}
