// NTFS设备页面脚本 - 精简版（使用模块化结构）
// 重构说明：
// - 原始文件：1213 行
// - 第一次重构：998 行
// - 第二次重构（当前）：~250 行（减少约 75%）
// - 功能已拆分为模块：
//   - device-utils.ts (103行): 工具函数（翻译、格式化、日志等）
//   - device-renderer.ts (350行): 设备列表渲染
//   - device-operations.ts (495行): 设备操作（挂载、卸载、推出等）
//   - device-events.ts (103行): 事件绑定
//   - device-refresh.ts (~250行): 设备刷新逻辑
//   - device-auto-refresh.ts (~150行): 自动刷新逻辑
(function() {
  'use strict';

  // 检查 electronAPI 是否已存在
  if (typeof window.electronAPI === 'undefined') {
    console.error('electronAPI 未定义，请检查 preload.js 是否正确加载');
    window.electronAPI = {} as any;
  }

  const electronAPI = window.electronAPI;

  // DOM 元素
  const devicesList = document.getElementById('devicesList')!;
  const autoMountBtn = document.getElementById('autoMountBtn') as HTMLButtonElement | null;
  const showMainWindowBtn = document.getElementById('showMainWindowBtn') as HTMLButtonElement | null;
  const refreshDevicesBtn = document.getElementById('refreshDevicesBtn') as HTMLButtonElement | null;
  const quitBtn = document.getElementById('quitBtn') as HTMLButtonElement | null;
  const mountAllBtn = document.getElementById('mountAllBtn') as HTMLButtonElement | null;
  const restoreAllReadOnlyBtn = document.getElementById('restoreAllReadOnlyBtn') as HTMLButtonElement | null;
  const ejectAllBtn = document.getElementById('ejectAllBtn') as HTMLButtonElement | null;

  // 状态管理
  let devices: any[] = [];
  const state = {
    devices,
    lastDeviceCount: 0,
    lastDeviceState: ''
  };

  // 暴露 state 到 window，供 device-operations 模块使用
  (window as any).__devicesState = state;

  // 使用模块化的功能
  const Utils = (window as any).AppModules?.Devices?.Utils;
  const Renderer = (window as any).AppModules?.Devices?.Renderer;
  const Operations = (window as any).AppModules?.Devices?.Operations;
  const Events = (window as any).AppModules?.Devices?.Events;
  const Refresh = (window as any).AppModules?.Devices?.Refresh;
  const AutoRefresh = (window as any).AppModules?.Devices?.AutoRefresh;

  // 工具函数包装
  function t(key: string, params?: Record<string, string | number>): string {
    if (Utils && Utils.t) {
      return Utils.t(key, params);
    }
    const AppUtils = (window as any).AppUtils;
    if (AppUtils && AppUtils.I18n && AppUtils.I18n.t) {
      return AppUtils.I18n.t(key, params);
    }
    return key;
  }

  async function addLog(message: string, type: 'info' | 'success' | 'error' | 'warning' = 'info'): Promise<void> {
    if (Utils && Utils.addLog) {
      await Utils.addLog(message, type);
      return;
    }
    const time = new Date().toLocaleTimeString('zh-CN');
    const logs = JSON.parse(localStorage.getItem('appLogs') || '[]');
    logs.push({ time, message, type });
    if (logs.length > 1000) {
      logs.shift();
    }
    localStorage.setItem('appLogs', JSON.stringify(logs));
  }

  // 刷新设备列表（委托给 Refresh 模块）
  async function refreshDevices(force: boolean = false): Promise<void> {
    if (Refresh && Refresh.refreshDevices) {
      const result = await Refresh.refreshDevices(devicesList, force, state);
      devices.length = 0;
      devices.push(...result);
      state.devices = devices;
      // 确保 AppModules.Devices.devices 同步更新
      if ((window as any).AppModules?.Devices) {
        (window as any).AppModules.Devices.devices = devices;
      }
    } else {
      // 降级实现
      try {
        devices = await electronAPI.getNTFSDevices();
        state.devices = devices;
        // 确保 AppModules.Devices.devices 同步更新
        if ((window as any).AppModules?.Devices) {
          (window as any).AppModules.Devices.devices = devices;
        }
        if (Renderer && Renderer.renderDevices) {
          Renderer.renderDevices(devicesList, devicesList);
        }
      } catch (error) {
        console.error('刷新设备失败:', error);
      }
    }
  }

  // 渲染设备列表（委托给 Renderer 模块）
  function renderDevices(): void {
    if (Renderer && Renderer.renderDevices) {
      Renderer.renderDevices(devicesList, devicesList);
    } else {
      // 降级实现
      if (devices.length === 0) {
        devicesList.innerHTML = `
          <div class="empty-state">
            <div class="empty-icon"></div>
            <p>${t('devices.emptyState')}</p>
            <p class="empty-hint">${t('devices.emptyHint')}</p>
          </div>
        `;
      }
    }
  }

  // 更新设备状态（委托给 Refresh 模块）
  async function updateDeviceState(): Promise<void> {
    if (Refresh && Refresh.updateDeviceState) {
      await Refresh.updateDeviceState(devices, state);
    }
  }

  // 设备操作函数（委托给 Operations 模块）
  async function mountDevice(device: any): Promise<void> {
    if (Operations && Operations.mountDevice) {
      const statusDot = document.querySelector('.status-dot') as HTMLElement | null;
      const statusText = document.querySelector('.status-text') as HTMLElement | null;
      await Operations.mountDevice(device, devicesList, devicesList, statusDot || devicesList, statusText || devicesList);
      await refreshDevices();
    }
  }

  async function restoreToReadOnly(device: any): Promise<void> {
    if (Operations && Operations.restoreToReadOnly) {
      const statusDot = document.querySelector('.status-dot') as HTMLElement | null;
      const statusText = document.querySelector('.status-text') as HTMLElement | null;
      await Operations.restoreToReadOnly(device, devicesList, devicesList, statusDot || devicesList, statusText || devicesList);
      await refreshDevices();
    }
  }

  async function unmountDevice(device: any): Promise<void> {
    if (Operations && Operations.unmountDevice) {
      const statusDot = document.querySelector('.status-dot') as HTMLElement | null;
      const statusText = document.querySelector('.status-text') as HTMLElement | null;
      await Operations.unmountDevice(device, devicesList, devicesList, statusDot || devicesList, statusText || devicesList);
      await refreshDevices();
    }
  }

  async function ejectDevice(device: any): Promise<void> {
    if (Operations && Operations.ejectDevice) {
      const statusDot = document.querySelector('.status-dot') as HTMLElement | null;
      const statusText = document.querySelector('.status-text') as HTMLElement | null;
      await Operations.ejectDevice(device, devicesList, devicesList, statusDot || devicesList, statusText || devicesList);
      await refreshDevices();
    }
  }

  async function mountAllDevices(): Promise<void> {
    if (Operations && Operations.mountAllDevices) {
      const statusDot = document.querySelector('.status-dot') as HTMLElement | null;
      const statusText = document.querySelector('.status-text') as HTMLElement | null;
      await Operations.mountAllDevices(devicesList, devicesList, statusDot || devicesList, statusText || devicesList);
      await refreshDevices();
    }
  }

  async function restoreAllToReadOnly(): Promise<void> {
    if (Operations && Operations.restoreAllToReadOnly) {
      const statusDot = document.querySelector('.status-dot') as HTMLElement | null;
      const statusText = document.querySelector('.status-text') as HTMLElement | null;
      await Operations.restoreAllToReadOnly(devicesList, devicesList, statusDot || devicesList, statusText || devicesList);
      await refreshDevices();
    }
  }

  async function ejectAllDevices(): Promise<void> {
    if (Operations && Operations.ejectAllDevices) {
      const statusDot = document.querySelector('.status-dot') as HTMLElement | null;
      const statusText = document.querySelector('.status-text') as HTMLElement | null;
      await Operations.ejectAllDevices(devicesList, devicesList, statusDot || devicesList, statusText || devicesList);
      await refreshDevices();
    }
  }

  // 暴露到 window 对象，供外部调用
  (window as any).refreshDevices = refreshDevices;
  (window as any).renderDevices = renderDevices;

  // 监听 body 类变化，当添加 tray-window 类时重新渲染
  if (typeof MutationObserver !== 'undefined') {
    const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.type === 'attributes' && mutation.attributeName === 'class') {
          const target = mutation.target as HTMLElement;
          if (target.classList.contains('tray-window')) {
            setTimeout(() => {
              refreshDevices();
            }, 100);
          }
        }
      });
    });

    if (document.body) {
      observer.observe(document.body, { attributes: true, attributeFilter: ['class'] });
      if (document.body.classList.contains('tray-window')) {
        setTimeout(() => {
          refreshDevices();
        }, 100);
      }
    }

    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => {
        if (document.body) {
          observer.observe(document.body, { attributes: true, attributeFilter: ['class'] });
          if (document.body.classList.contains('tray-window')) {
            setTimeout(() => {
              refreshDevices();
            }, 100);
          }
        }
      });
    }
  }

  document.addEventListener('DOMContentLoaded', () => {
    // 更新按钮文本（国际化）
    const updateButtonTexts = () => {
      const AppUtils = (window as any).AppUtils;
      if (!AppUtils || !AppUtils.I18n || !AppUtils.I18n.t) {
        return;
      }
      const t = AppUtils.I18n.t;

      const testTranslation = t('devices.title');
      if (testTranslation === 'devices.title') {
        setTimeout(updateButtonTexts, 100);
        return;
      }

      if (mountAllBtn) {
        mountAllBtn.textContent = t('devices.mountAll');
      }
      if (restoreAllReadOnlyBtn) {
        restoreAllReadOnlyBtn.textContent = t('devices.restoreAllReadOnly');
      }
      if (ejectAllBtn) {
        ejectAllBtn.textContent = t('devices.ejectAll');
      }
    };

    const waitForI18n = () => {
      const AppUtils = (window as any).AppUtils;
      if (AppUtils && AppUtils.I18n && AppUtils.I18n.t) {
        updateButtonTexts();
      } else {
        let retryCount = 0;
        const maxRetries = 50;
        const retry = () => {
          retryCount++;
          if (retryCount < maxRetries) {
            setTimeout(() => {
              const AppUtils = (window as any).AppUtils;
              if (AppUtils && AppUtils.I18n && AppUtils.I18n.t) {
                updateButtonTexts();
              } else {
                retry();
              }
            }, 100);
          }
        };
        retry();
      }
    };
    waitForI18n();

    // 监听语言变更事件
    window.addEventListener('languageChanged', async () => {
      await new Promise(resolve => setTimeout(resolve, 100));
      updateButtonTexts();
      if (Renderer && Renderer.lastRenderedDevices) {
        Renderer.lastRenderedDevices = [];
      }
      if (devicesList) {
        (devicesList as any).__lastStateKey = '';
      }
      renderDevices();
      if (devices.length > 0) {
        await refreshDevices(true);
      }
    });

    // 功能按钮
    if (autoMountBtn) {
      let autoMountEnabled = false;
      const loadAutoMountSetting = async () => {
        try {
          if (electronAPI.getSettings) {
            const settings = await electronAPI.getSettings();
            if (settings && typeof settings.autoMount === 'boolean') {
              autoMountEnabled = settings.autoMount;
              updateAutoMountButtonState();
            }
          }
        } catch (e) {
          // 静默处理
        }
      };
      const updateAutoMountButtonState = () => {
        if (autoMountEnabled) {
          autoMountBtn.classList.add('active');
        } else {
          autoMountBtn.classList.remove('active');
        }
      };
      loadAutoMountSetting();
      if (electronAPI.onSettingsChange) {
        electronAPI.onSettingsChange((settings: any) => {
          if (settings && typeof settings.autoMount === 'boolean') {
            autoMountEnabled = settings.autoMount;
            updateAutoMountButtonState();
          }
        });
      }
      autoMountBtn.addEventListener('click', async () => {
        try {
          autoMountEnabled = !autoMountEnabled;
          updateAutoMountButtonState();
          if (electronAPI.saveSettings) {
            await electronAPI.saveSettings({ autoMount: autoMountEnabled });
          }
        } catch (e) {
          // 静默处理
        }
      });
    }

    if (showMainWindowBtn) {
      showMainWindowBtn.addEventListener('click', async () => {
        try {
          if (electronAPI.showMainWindow) {
            await electronAPI.showMainWindow();
          }
        } catch (error) {
          console.error('显示主窗口失败:', error);
        }
      });
    }

    if (refreshDevicesBtn) {
      refreshDevicesBtn.addEventListener('click', async () => {
        if (refreshDevicesBtn) {
          refreshDevicesBtn.disabled = true;
          const refreshingText = t('tray.refreshing') || '刷新中...';
          refreshDevicesBtn.innerHTML = `<img src="../imgs/svg/refresh.svg" alt="" class="btn-icon">`;
          refreshDevicesBtn.title = refreshingText;
          try {
            await refreshDevices(true);
          } catch (error) {
            console.error('刷新设备列表失败:', error);
            await addLog('刷新设备列表失败: ' + (error instanceof Error ? error.message : String(error)), 'error');
          } finally {
            if (refreshDevicesBtn) {
              refreshDevicesBtn.disabled = false;
              const refreshText = t('devices.refreshDevices') || '刷新';
              refreshDevicesBtn.innerHTML = `<img src="../imgs/svg/refresh.svg" alt="" class="btn-icon">`;
              refreshDevicesBtn.title = refreshText;
            }
          }
        }
      });
    }

    if (quitBtn) {
      quitBtn.addEventListener('click', async () => {
        try {
          // 显示确认对话框
          const confirmTitle = t('tray.quitConfirmTitle') || '确认退出';
          const confirmMessage = t('tray.quitConfirmMessage') || '确定要退出应用吗？';
          const confirmed = await electronAPI.showConfirmDialog(confirmTitle, confirmMessage);

          if (confirmed && electronAPI.quitApp) {
            await electronAPI.quitApp();
          }
        } catch (error) {
          console.error('退出应用失败:', error);
        }
      });
    }

    if (mountAllBtn) {
      mountAllBtn.addEventListener('click', mountAllDevices);
    }
    if (restoreAllReadOnlyBtn) {
      restoreAllReadOnlyBtn.addEventListener('click', restoreAllToReadOnly);
    }
    if (ejectAllBtn) {
      ejectAllBtn.addEventListener('click', ejectAllDevices);
    }

    // 绑定设备事件
    if (Events && Events.bindDeviceEvents) {
      Events.bindDeviceEvents(devicesList, devicesList);
    }

    // 自动刷新
    refreshDevices();
    if (AutoRefresh && AutoRefresh.startAutoRefresh) {
      AutoRefresh.startAutoRefresh(refreshDevices, renderDevices, updateDeviceState, devices);
    }

    // 监听主题变化
    if (window.electronAPI && window.electronAPI.onThemeChange) {
      window.electronAPI.onThemeChange((isLightMode: boolean) => {
        if (isLightMode) {
          document.body.classList.add('light-theme');
        } else {
          document.body.classList.remove('light-theme');
        }
      });
    }

    // 初始化主题
    try {
      const savedTheme = localStorage.getItem('app-theme');
      if (savedTheme === 'light') {
        document.body.classList.add('light-theme');
      }
    } catch (e) {
      // 静默处理
    }

    // 清理
    window.addEventListener('beforeunload', () => {
      if (AutoRefresh && AutoRefresh.stopAutoRefresh) {
        AutoRefresh.stopAutoRefresh();
      }
    });
  });
})();
