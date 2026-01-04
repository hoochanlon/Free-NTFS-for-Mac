// NTFS设备页面脚本
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
  const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;
  const autoMountCheckbox = document.getElementById('autoMountCheckbox') as HTMLInputElement | null;
  const showMainWindowBtn = document.getElementById('showMainWindowBtn') as HTMLButtonElement | null;
  const mountAllBtn = document.getElementById('mountAllBtn') as HTMLButtonElement | null;
  const restoreAllReadOnlyBtn = document.getElementById('restoreAllReadOnlyBtn') as HTMLButtonElement | null;
  const ejectAllBtn = document.getElementById('ejectAllBtn') as HTMLButtonElement | null;

  // 状态管理
  let devices: any[] = [];
  let autoRefreshInterval: NodeJS.Timeout | null = null;
  let lastDeviceCount = 0;
  let lastDeviceState = '';

  type LogType = 'info' | 'success' | 'error' | 'warning';

  // 获取翻译文本的辅助函数
  function t(key: string, params?: Record<string, string | number>): string {
    const AppUtils = (window as any).AppUtils;
    if (AppUtils && AppUtils.I18n && AppUtils.I18n.t) {
      return AppUtils.I18n.t(key, params);
    }
    // 如果 i18n 未初始化，返回 key
    return key;
  }

  // 格式化容量显示
  function formatCapacity(bytes: number): string {
    if (bytes < 1024) {
      return `${bytes} B`;
    } else if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(1)} KB`;
    } else if (bytes < 1024 * 1024 * 1024) {
      return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    } else {
      return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
    }
  }

  // 添加日志
  function addLog(message: string, type: LogType = 'info'): void {
    const time = new Date().toLocaleTimeString('zh-CN');
    const logs = JSON.parse(localStorage.getItem('appLogs') || '[]');
    logs.push({ time, message, type });
    // 限制日志数量
    if (logs.length > 1000) {
      logs.shift();
    }
    localStorage.setItem('appLogs', JSON.stringify(logs));
  }

  // 显示/隐藏加载遮罩
  function showLoading(show: boolean = true): void {
    if (show) {
      loadingOverlay.classList.add('visible');
    } else {
      loadingOverlay.classList.remove('visible');
    }
  }

  // 刷新设备列表
  async function refreshDevices(): Promise<void> {
    try {
      devices = await electronAPI.getNTFSDevices();
      renderDevices();

      const currentDeviceCount = devices.length;
      const readOnlyCount = devices.filter(d => d.isReadOnly).length;
      const currentState = `${currentDeviceCount}-${readOnlyCount}`;

      // 只在设备状态变化时添加日志
      const stateChanged = currentDeviceCount !== lastDeviceCount || currentState !== lastDeviceState;

      if (devices.length === 0) {
        if (stateChanged) {
          addLog(t('messages.noDevicesDetected'), 'info');
        }
      } else {
        const readWriteCount = devices.length - readOnlyCount;

        if (readOnlyCount > 0) {
          if (stateChanged) {
            if (readWriteCount > 0) {
              addLog(t('messages.devicesDetected', { count: devices.length, readOnly: readOnlyCount, readWrite: readWriteCount }), 'info');
            } else {
              addLog(t('messages.devicesDetectedAllReadOnly', { count: devices.length }), 'warning');
            }
          }
        } else {
          if (stateChanged) {
            addLog(t('messages.devicesDetectedAllReadWrite', { count: devices.length }), 'success');
          }
        }
      }

      lastDeviceCount = currentDeviceCount;
      lastDeviceState = currentState;
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      addLog(t('messages.refreshFailed', { error: errorMessage }), 'error');
    }
  }

  // 渲染设备列表
  function renderDevices(): void {
    if (devices.length === 0) {
      devicesList.innerHTML = `
        <div class="empty-state">
          <div class="empty-icon"></div>
          <p>${t('devices.emptyState')}</p>
          <p class="empty-hint">${t('devices.emptyHint')}</p>
        </div>
      `;
      return;
    }

    // 保存当前选中的设备（如果有）
    const selectedDisk = (document.querySelector('.device-item.selected') as HTMLElement)?.dataset?.disk;

    // 生成设备状态的唯一标识，用于判断是否需要更新
    const deviceStateKey = devices.map(d => `${d.disk}:${d.isReadOnly}:${d.isUnmounted}`).join('|');
    const lastStateKey = (devicesList as any).__lastStateKey || '';

    // 如果设备状态没有变化，且已有DOM元素，则跳过重新渲染
    if (deviceStateKey === lastStateKey && devicesList.querySelectorAll('.device-item').length === devices.length) {
      return;
    }

    (devicesList as any).__lastStateKey = deviceStateKey;

    devicesList.innerHTML = '';

    devices.forEach(device => {
      const item = document.createElement('div');
      item.className = 'device-item';
      item.setAttribute('data-disk', device.disk);

      // 添加读写设备样式类
      if (!device.isReadOnly && !device.isUnmounted) {
        item.classList.add('read-write-device');
      }
      if (device.isUnmounted) {
        item.classList.add('unmounted-device');
      }

      const isUnmounted = device.isUnmounted || false;
      const statusClass = isUnmounted ? 'unmounted' : (device.isReadOnly ? 'read-only' : 'read-write');
      const statusText = isUnmounted ? t('devices.unmounted') : (device.isReadOnly ? t('devices.readOnly') : t('devices.readWrite'));

      item.innerHTML = `
        <div class="device-header">
          <div class="device-name">
            <span class="device-icon"></span>
            ${device.volumeName}
          </div>
          <span class="device-status ${statusClass}">${statusText}</span>
        </div>
        <div class="device-info">
          <div class="device-info-item">
            <span class="device-info-label">${t('devices.deviceLabel')}</span>
            <span>${device.devicePath}</span>
          </div>
          <div class="device-info-item">
            <span class="device-info-label">${t('devices.mountPointLabel')}</span>
            <span>${isUnmounted ? t('devices.notMounted') : device.volume}</span>
          </div>
          ${device.capacity ? `
          <div class="device-info-item">
            <span class="device-info-label">${t('devices.capacityLabel')}</span>
            <span>${formatCapacity(device.capacity.used)} / ${formatCapacity(device.capacity.total)}</span>
          </div>
          ` : ''}
        </div>
        <div class="device-actions">
          ${isUnmounted ? `
            <button class="btn btn-success mount-btn" data-disk="${device.disk}">
              ${t('devices.remount')}
            </button>
            <button class="btn btn-danger eject-btn" data-disk="${device.disk}">
              ${t('devices.eject')}
            </button>
          ` : device.isReadOnly ? `
            <button class="btn btn-success mount-btn" data-disk="${device.disk}">
              ${t('devices.mount')}
            </button>
            <button class="btn btn-danger eject-btn" data-disk="${device.disk}">
              ${t('devices.eject')}
            </button>
          ` : `
            <button class="btn btn-secondary restore-readonly-btn" data-disk="${device.disk}">
              ${t('devices.restoreReadOnly')}
            </button>
            <button class="btn btn-danger eject-btn" data-disk="${device.disk}">
              ${t('devices.eject')}
            </button>
          `}
        </div>
      `;

      devicesList.appendChild(item);
    });

    // 恢复选中状态
    if (selectedDisk) {
      const selectedItem = devicesList.querySelector(`[data-disk="${selectedDisk}"]`) as HTMLElement;
      if (selectedItem) {
        selectedItem.classList.add('selected');
      }
    }

    // 绑定按钮事件
    devicesList.querySelectorAll('.mount-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const disk = (btn as HTMLElement).dataset.disk;
        const device = devices.find(d => d.disk === disk);
        if (device) mountDevice(device);
      });
    });

    devicesList.querySelectorAll('.restore-readonly-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const disk = (btn as HTMLElement).dataset.disk;
        const device = devices.find(d => d.disk === disk);
        if (device) restoreToReadOnly(device);
      });
    });

    devicesList.querySelectorAll('.eject-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const disk = (btn as HTMLElement).dataset.disk;
        const device = devices.find(d => d.disk === disk);
        if (device) ejectDevice(device);
      });
    });
  }

  // 挂载设备（配置为可读写）
  async function mountDevice(device: any): Promise<void> {
    try {
      showLoading(true);
      addLog(t('messages.mounting', { name: device.volumeName }), 'info');
      addLog(t('messages.enterPassword'), 'info');

      const result = await electronAPI.mountDevice(device);

      if (result.success) {
        if (result.result) {
          addLog(result.result, 'success');
        }
        // 等待一小段时间，确保挂载操作完全完成
        await new Promise(resolve => setTimeout(resolve, 500));
        await refreshDevices();
      } else {
        addLog(`${t('messages.mountError')}: ${result.error || t('messages.unknownError')}`, 'error');
        if (result.error?.includes('密码错误') || result.error?.includes('password')) {
          addLog(t('messages.passwordError'), 'warning');
        } else if (result.error?.includes('用户取消') || result.error?.includes('cancel')) {
          addLog(t('messages.cancelled'), 'info');
        }
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      addLog(`${t('messages.mountError')}: ${errorMessage}`, 'error');
    } finally {
      showLoading(false);
    }
  }

  // 还原为只读
  async function restoreToReadOnly(device: any): Promise<void> {
    try {
      showLoading(true);
      addLog(t('messages.restoring', { name: device.volumeName }), 'info');
      addLog(t('messages.enterPassword'), 'info');

      const result = await electronAPI.restoreToReadOnly(device);

      if (result.success) {
        if (result.result) {
          addLog(result.result, 'success');
        }
        // restoreToReadOnly需要等待系统重新挂载
        setTimeout(async () => {
          await refreshDevices();
        }, 2000);
      } else {
        addLog(`${t('messages.restoreError')}: ${result.error || t('messages.unknownError')}`, 'error');
        if (result.error?.includes('密码错误') || result.error?.includes('password')) {
          addLog(t('messages.passwordError'), 'warning');
        } else if (result.error?.includes('用户取消') || result.error?.includes('cancel')) {
          addLog(t('messages.cancelled'), 'info');
        }
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      addLog(`${t('messages.restoreError')}: ${errorMessage}`, 'error');
    } finally {
      showLoading(false);
    }
  }

  // 推出设备
  async function ejectDevice(device: any): Promise<void> {
    try {
      showLoading(true);
      addLog(t('messages.ejecting', { name: device.volumeName }), 'info');
      addLog(t('messages.enterPassword'), 'info');

      const result = await electronAPI.ejectDevice(device);

      if (result.success) {
        if (result.result) {
          addLog(result.result, 'success');
        }
        await refreshDevices();
      } else {
        addLog(`${t('messages.ejectError')}: ${result.error || t('messages.unknownError')}`, 'error');
        if (result.error?.includes('密码错误') || result.error?.includes('password')) {
          addLog(t('messages.passwordError'), 'warning');
        } else if (result.error?.includes('用户取消') || result.error?.includes('cancel')) {
          addLog(t('messages.cancelled'), 'info');
        }
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      addLog(`${t('messages.ejectError')}: ${errorMessage}`, 'error');
    } finally {
      showLoading(false);
    }
  }

  // 全读写
  async function mountAllDevices(): Promise<void> {
    const readOnlyDevices = devices.filter(d => d.isReadOnly && !d.isUnmounted);
    if (readOnlyDevices.length === 0) {
      addLog(t('messages.noDevicesToMount'), 'info');
      return;
    }
    try {
      showLoading(true);
      addLog(t('messages.mountAllStart', { count: readOnlyDevices.length }), 'info');
      let successCount = 0;
      let failCount = 0;
      for (const device of readOnlyDevices) {
        try {
          const result = await electronAPI.mountDevice(device);
          if (result.success) {
            successCount++;
            addLog(`${device.volumeName} ${t('messages.mountSuccess')}`, 'success');
          } else {
            failCount++;
            addLog(`${device.volumeName} ${t('messages.mountError')}: ${result.error || t('messages.unknownError')}`, 'error');
          }
        } catch (error) {
          failCount++;
          const errorMessage = error instanceof Error ? error.message : String(error);
          addLog(`${device.volumeName} ${t('messages.mountError')}: ${errorMessage}`, 'error');
        }
      }
      if (successCount > 0) {
        addLog(t('messages.mountAllSuccess', { count: successCount }), 'success');
      }
      if (failCount > 0) {
        addLog(t('messages.mountAllError', { count: failCount }), 'warning');
      }
      await new Promise(resolve => setTimeout(resolve, 500));
      await refreshDevices();
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      addLog(`${t('messages.mountError')}: ${errorMessage}`, 'error');
    } finally {
      showLoading(false);
    }
  }

  // 全只读
  async function restoreAllToReadOnly(): Promise<void> {
    const readWriteDevices = devices.filter(d => !d.isReadOnly && !d.isUnmounted);
    if (readWriteDevices.length === 0) {
      addLog(t('messages.noDevicesToRestore') || '没有需要还原的设备', 'info');
      return;
    }
    try {
      showLoading(true);
      addLog(t('messages.restoreAllStart', { count: readWriteDevices.length }), 'info');
      let successCount = 0;
      let failCount = 0;
      for (const device of readWriteDevices) {
        try {
          const result = await electronAPI.restoreToReadOnly(device);
          if (result.success) {
            successCount++;
            addLog(`${device.volumeName} ${t('messages.restoreSuccess')}`, 'success');
          } else {
            failCount++;
            addLog(`${device.volumeName} ${t('messages.restoreError')}: ${result.error || t('messages.unknownError')}`, 'error');
          }
        } catch (error) {
          failCount++;
          const errorMessage = error instanceof Error ? error.message : String(error);
          addLog(`${device.volumeName} ${t('messages.restoreError')}: ${errorMessage}`, 'error');
        }
      }
      if (successCount > 0) {
        addLog(t('messages.restoreAllSuccess', { count: successCount }), 'success');
      }
      if (failCount > 0) {
        addLog(t('messages.restoreAllError', { count: failCount }), 'warning');
      }
      setTimeout(async () => {
        await refreshDevices();
      }, 2000);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      addLog(`${t('messages.restoreError')}: ${errorMessage}`, 'error');
    } finally {
      showLoading(false);
    }
  }

  // 全推出
  async function ejectAllDevices(): Promise<void> {
    if (devices.length === 0) {
      addLog(t('messages.noDevicesToEject') || '没有需要推出的设备', 'info');
      return;
    }
    const confirmed = confirm(`${t('devices.ejectAllConfirm')}\n\n⚠️ ${t('devices.ejectAllConfirmNote') || '请确保没有程序正在使用这些设备'}`);
    if (!confirmed) {
      addLog(t('messages.cancelled'), 'info');
      return;
    }
    try {
      showLoading(true);
      addLog(t('messages.ejectAllStart', { count: devices.length }), 'info');
      let successCount = 0;
      let failCount = 0;
      for (const device of devices) {
        try {
          const result = await electronAPI.ejectDevice(device);
          if (result.success) {
            successCount++;
            addLog(`${device.volumeName} ${t('messages.ejectSuccess')}`, 'success');
          } else {
            failCount++;
            addLog(`${device.volumeName} ${t('messages.ejectError')}: ${result.error || t('messages.unknownError')}`, 'error');
          }
        } catch (error) {
          failCount++;
          const errorMessage = error instanceof Error ? error.message : String(error);
          addLog(`${device.volumeName} ${t('messages.ejectError')}: ${errorMessage}`, 'error');
        }
      }
      if (successCount > 0) {
        addLog(t('messages.ejectAllSuccess', { count: successCount }), 'success');
      }
      if (failCount > 0) {
        addLog(t('messages.ejectAllError', { count: failCount }), 'warning');
      }
      await refreshDevices();
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      addLog(`${t('messages.ejectError')}: ${errorMessage}`, 'error');
    } finally {
      showLoading(false);
    }
  }

  // 自动刷新
  function startAutoRefresh(): void {
    // 每 5 秒刷新一次设备列表
    autoRefreshInterval = setInterval(() => {
      refreshDevices();
    }, 5000);
  }

  // 初始化
  document.addEventListener('DOMContentLoaded', () => {
    // 更新按钮文本（国际化）
    const updateButtonTexts = () => {
      const AppUtils = (window as any).AppUtils;
      if (!AppUtils || !AppUtils.I18n || !AppUtils.I18n.t) {
        return;
      }
      const t = AppUtils.I18n.t;

      if (mountAllBtn) {
        mountAllBtn.textContent = t('devices.mountAll');
      }
      if (restoreAllReadOnlyBtn) {
        restoreAllReadOnlyBtn.textContent = t('devices.restoreAllReadOnly');
      }
      if (ejectAllBtn) {
        ejectAllBtn.textContent = t('devices.ejectAll');
      }
      if (autoMountCheckbox) {
        const label = autoMountCheckbox.parentElement?.querySelector('span');
        if (label) {
          label.textContent = t('devices.autoMount');
        }
      }
    };

    // 等待 i18n 初始化完成后再更新文本
    const waitForI18n = () => {
      const AppUtils = (window as any).AppUtils;
      if (AppUtils && AppUtils.I18n && AppUtils.I18n.t) {
        updateButtonTexts();
        // 监听语言变化，重新更新文本
        if (AppUtils.I18n.onLanguageChange) {
          AppUtils.I18n.onLanguageChange(() => {
            updateButtonTexts();
          });
        }
      } else {
        // 如果 i18n 还未初始化，延迟重试（最多等待 5 秒）
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

    // 功能按钮
    if (autoMountCheckbox) {
      // 从设置读取自动挂载配置
      const loadAutoMountSetting = async () => {
        try {
          if (electronAPI.getSettings) {
            const settings = await electronAPI.getSettings();
            if (settings && typeof settings.autoMount === 'boolean') {
              autoMountCheckbox.checked = settings.autoMount;
            }
          }
        } catch (e) {
          // 静默处理
        }
      };

      // 初始加载
      loadAutoMountSetting();

      // 监听设置变化事件
      if (electronAPI.onSettingsChange) {
        electronAPI.onSettingsChange((settings: any) => {
          if (settings && typeof settings.autoMount === 'boolean') {
            autoMountCheckbox.checked = settings.autoMount;
          }
        });
      }

      autoMountCheckbox.addEventListener('change', async (e) => {
        try {
          if (electronAPI.saveSettings) {
            await electronAPI.saveSettings({ autoMount: (e.target as HTMLInputElement).checked });
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
    if (mountAllBtn) {
      mountAllBtn.addEventListener('click', mountAllDevices);
    }
    if (restoreAllReadOnlyBtn) {
      restoreAllReadOnlyBtn.addEventListener('click', restoreAllToReadOnly);
    }
    if (ejectAllBtn) {
      ejectAllBtn.addEventListener('click', ejectAllDevices);
    }

    // 自动刷新
    refreshDevices();
    startAutoRefresh();

    // 监听主题变化
    if (window.electronAPI && window.electronAPI.onThemeChange) {
      window.electronAPI.onThemeChange((isLightMode: boolean) => {
        // 更新body的class
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
      if (autoRefreshInterval) {
        clearInterval(autoRefreshInterval);
      }
    });
  });
})();
