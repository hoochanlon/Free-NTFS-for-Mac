import { BrowserWindow, app } from 'electron';
import * as path from 'path';
import { mainWindow } from './window-manager';

let aboutWindow: BrowserWindow | null = null;

// 获取当前主题
async function getCurrentTheme(): Promise<{ isLightMode: boolean; backgroundColor: string }> {
  let backgroundColor = '#1d1d1f';
  let isLightMode = false;

  if (mainWindow && !mainWindow.isDestroyed()) {
    try {
      const currentTheme = await mainWindow.webContents.executeJavaScript(`
        document.body.classList.contains('light-theme') ? 'light' : 'dark'
      `);
      isLightMode = currentTheme === 'light';
      backgroundColor = isLightMode ? '#f5f5f7' : '#1d1d1f';
    } catch (err) {
      console.warn('获取主窗口主题失败，使用默认深色:', err);
    }
  }

  return { isLightMode, backgroundColor };
}

// 设置关于窗口的主题事件监听
function setupAboutWindowTheme(aboutWindow: BrowserWindow, isLightMode: boolean): void {
  // 在加载文件前注入主题类，避免闪烁
  aboutWindow.webContents.on('did-start-loading', () => {
    if (aboutWindow && !aboutWindow.isDestroyed()) {
      aboutWindow.webContents.executeJavaScript(`
        (function() {
          if (document.documentElement) {
            if (${isLightMode}) {
              document.documentElement.classList.add('light-theme');
            } else {
              document.documentElement.classList.remove('light-theme');
            }
          }
          if (document.body) {
            if (${isLightMode}) {
              document.body.classList.add('light-theme');
            } else {
              document.body.classList.remove('light-theme');
            }
          }
        })();
      `).catch(() => {});
    }
  });

  // 在 DOM 加载前注入主题脚本，避免闪烁
  aboutWindow.webContents.on('dom-ready', () => {
    if (aboutWindow && !aboutWindow.isDestroyed()) {
      aboutWindow.webContents.executeJavaScript(`
        (function() {
          if (document.body) {
            if (${isLightMode}) {
              document.body.classList.add('light-theme');
            } else {
              document.body.classList.remove('light-theme');
            }
          }

          function applyThemeToIcons() {
            const iconLinks = document.querySelectorAll('.about-icon-link');
            iconLinks.forEach(function(link) {
              const icon = link.querySelector('.about-icon');
              if (icon) {
                icon.style.transition = 'opacity 0.3s cubic-bezier(0.4, 0, 0.2, 1)';
              }
            });
          }

          applyThemeToIcons();

          const observer = new MutationObserver(applyThemeToIcons);
          if (document.body) {
            observer.observe(document.body, {
              childList: true,
              subtree: true
            });
          }
        })();
      `).catch((err: any) => {
        console.error('应用主题类失败:', err);
      });
    }
  });

  aboutWindow.webContents.on('did-finish-load', () => {
    console.log('关于窗口加载完成');
    if (aboutWindow && !aboutWindow.isDestroyed()) {
      if (mainWindow && !mainWindow.isDestroyed()) {
        mainWindow.webContents.executeJavaScript(`
          document.body.classList.contains('light-theme') ? 'light' : 'dark'
        `).then((theme: string) => {
          if (aboutWindow && !aboutWindow.isDestroyed()) {
            const isLight = theme === 'light';
            aboutWindow.webContents.executeJavaScript(`
              (function() {
                const AppUtils = window.AppUtils;
                if (AppUtils && AppUtils.Theme) {
                  AppUtils.Theme.updateTheme(${isLight}, document.body, null);
                }
              })();
            `).catch((err: any) => {
              console.error('同步主题到关于窗口失败:', err);
            });
          }
        }).catch((err: any) => {
          console.error('获取主窗口主题失败:', err);
        });
      }
    }
    if (aboutWindow && !aboutWindow.isDestroyed()) {
      aboutWindow.show();
      aboutWindow.focus();
    }
  });
}

// 打开关于窗口
export async function openAboutWindow(): Promise<void> {
  if (aboutWindow && !aboutWindow.isDestroyed()) {
    console.log('关于窗口已存在，聚焦窗口');
    aboutWindow.focus();
    return;
  }

  const appPath = app.getAppPath();
  const aboutPath = path.join(appPath, 'src', 'html', 'about.html');
  console.log('关于窗口路径:', aboutPath);

  // 获取当前主题
  const { isLightMode, backgroundColor } = await getCurrentTheme();

  aboutWindow = new BrowserWindow({
    width: 480,
    height: 400,
    minWidth: 400,
    minHeight: 350,
    maxWidth: 480,
    maxHeight: 400,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true
    },
    frame: false,
    titleBarStyle: 'hidden',
    backgroundColor: backgroundColor,
    parent: mainWindow || undefined,
    resizable: false,
    minimizable: false,
    maximizable: false,
    closable: true,
    show: false,
    title: '关于'
  });

  console.log('关于窗口已创建');

  // 添加错误处理
  aboutWindow.webContents.on('did-fail-load', (event, errorCode, errorDescription, validatedURL) => {
    console.error('关于窗口加载失败:', errorCode, errorDescription, validatedURL);
  });

  // 设置主题事件监听
  setupAboutWindowTheme(aboutWindow, isLightMode);

  try {
    await aboutWindow.loadFile(aboutPath);
    console.log('关于窗口文件加载成功');
  } catch (error) {
    console.error('加载关于窗口文件失败:', error);
    if (aboutWindow) {
      aboutWindow.destroy();
    }
    aboutWindow = null;
    return;
  }

  aboutWindow.once('ready-to-show', () => {
    console.log('关于窗口 ready-to-show 事件触发');
    if (aboutWindow && !aboutWindow.isDestroyed()) {
      aboutWindow.show();
      aboutWindow.focus();
    }
  });

  // 备用方案：延迟显示（如果 ready-to-show 没有触发）
  setTimeout(() => {
    if (aboutWindow && !aboutWindow.isDestroyed() && !aboutWindow.isVisible()) {
      console.log('关于窗口延迟显示（备用方案）');
      aboutWindow.show();
      aboutWindow.focus();
    }
  }, 500);

  aboutWindow.on('closed', () => {
    console.log('关于窗口已关闭');
    aboutWindow = null;
  });
}

// 获取关于窗口实例（用于主题广播）
export function getAboutWindow(): BrowserWindow | null {
  return aboutWindow;
}
