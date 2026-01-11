// NTFS设备页面脚本 - 重构版本（使用模块化结构）
// 重构说明：
// - 原始文件：1213 行
// - 重构后：991 行（减少 222 行，约 18%）
// - 功能已拆分为模块：
//   - device-utils.ts (103行): 工具函数（翻译、格式化、日志等）
//   - device-renderer.ts (350行): 设备列表渲染
//   - device-operations.ts (495行): 设备操作（挂载、卸载、推出等）
//   - device-events.ts (103行): 事件绑定
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
  const autoMountBtn = document.getElementById('autoMountBtn') as HTMLButtonElement | null;
  const showMainWindowBtn = document.getElementById('showMainWindowBtn') as HTMLButtonElement | null;
  const refreshDevicesBtn = document.getElementById('refreshDevicesBtn') as HTMLButtonElement | null;
  const mountAllBtn = document.getElementById('mountAllBtn') as HTMLButtonElement | null;
  const restoreAllReadOnlyBtn = document.getElementById('restoreAllReadOnlyBtn') as HTMLButtonElement | null;
  const ejectAllBtn = document.getElementById('ejectAllBtn') as HTMLButtonElement | null;

  // 状态管理
  let devices: any[] = [];
  let autoRefreshInterval: NodeJS.Timeout | null = null;
  let lastDeviceCount = 0;
  let lastDeviceState = '';
  let hybridDetectionStarted: boolean = false;

  // 使用模块化的工具函数
  const Utils = (window as any).AppModules?.Devices?.Utils;
  const Renderer = (window as any).AppModules?.Devices?.Renderer;
  const Operations = (window as any).AppModules?.Devices?.Operations;
  const Events = (window as any).AppModules?.Devices?.Events;

  // 工具函数包装（如果模块未加载，使用降级实现）
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
    // 降级实现
    const time = new Date().toLocaleTimeString('zh-CN');
    const logs = JSON.parse(localStorage.getItem('appLogs') || '[]');
    logs.push({ time, message, type });
    if (logs.length > 1000) {
      logs.shift();
    }
    localStorage.setItem('appLogs', JSON.stringify(logs));
  }

  function showLoading(show: boolean = true): void {
    if (Utils && Utils.showLoading) {
      Utils.showLoading(show);
      return;
    }
    // 降级实现
    if (show) {
      loadingOverlay.classList.add('visible');
    } else {
      loadingOverlay.classList.remove('visible');
    }
  }

  // 刷新设备列表（优化版：防抖和增量更新）
  let refreshDebounceTimer: number | null = null;
  const REFRESH_DEBOUNCE_MS = 200; // 防抖200ms

  async function refreshDevices(force: boolean = false): Promise<void> {
    // 防抖：短时间内多次调用只执行最后一次
    if (!force && refreshDebounceTimer !== null) {
      clearTimeout(refreshDebounceTimer);
    }

    const doRefresh = async () => {
      try {
        const oldDevices = [...devices];
        const previousDevicePaths = oldDevices.map(d => d.devicePath);
        devices = await electronAPI.getNTFSDevices();

        // 更新 AppModules.Devices.devices（如果存在）
        if ((window as any).AppModules?.Devices) {
          (window as any).AppModules.Devices.devices = devices;
        }

        // 增量更新：只更新变化的部分
        const hasChanged = JSON.stringify(oldDevices.map(d => ({ disk: d.disk, isMounted: d.isMounted }))) !==
                          JSON.stringify(devices.map(d => ({ disk: d.disk, isMounted: d.isMounted })));

        if (hasChanged || force) {
          renderDevices();
        }

        const currentDeviceCount = devices.length;

        // 检测新插入的设备并自动挂载
        const currentDevicePaths = devices.map(d => d.devicePath);
        const newDevices = devices.filter(d =>
          !previousDevicePaths.includes(d.devicePath) && d.isReadOnly && !d.isUnmounted
        );

        if (newDevices.length > 0) {
          try {
            const settings = await electronAPI.getSettings();
            if (settings && settings.autoMount) {
              // 自动挂载新插入的只读设备
              for (const device of newDevices) {
                try {
                  await addLog(`检测到新设备 ${device.volumeName}，正在自动配置为可读写...`, 'info');
                  const result = await electronAPI.mountDevice(device);
                  if (result.success) {
                    await addLog(`设备 ${device.volumeName} 自动配置成功`, 'success');
                  } else {
                    await addLog(`设备 ${device.volumeName} 自动配置失败: ${result.error || '未知错误'}`, 'error');
                  }
                } catch (error) {
                  const errorMessage = error instanceof Error ? error.message : String(error);
                  await addLog(`设备 ${device.volumeName} 自动配置失败: ${errorMessage}`, 'error');
                }
              }
              // 重新刷新设备列表以更新状态
              devices = await electronAPI.getNTFSDevices();
              if ((window as any).AppModules?.Devices) {
                (window as any).AppModules.Devices.devices = devices;
              }
              renderDevices();
            }
          } catch (error) {
            console.error('自动挂载失败:', error);
          }
        }

        // 如果是托盘窗口，根据设备数量调整窗口高度
        if (document.body && document.body.classList.contains('tray-window')) {
          setTimeout(async () => {
            try {
              if (electronAPI.adjustTrayWindowHeightByDeviceCount) {
                await electronAPI.adjustTrayWindowHeightByDeviceCount(currentDeviceCount);
              }
            } catch (error) {
              console.error('[设备列表更新] 调整窗口高度失败:', error);
            }
          }, 150);
        }

        const readOnlyCount = devices.filter(d => d.isReadOnly).length;
        const currentState = `${currentDeviceCount}-${readOnlyCount}`;

        // 只在设备状态变化时添加日志
        const stateChanged = currentDeviceCount !== lastDeviceCount || currentState !== lastDeviceState;

        if (devices.length === 0) {
          if (stateChanged) {
            await addLog(t('messages.noDevicesDetected'), 'info');
          }
        } else {
          const readWriteCount = devices.length - readOnlyCount;

          if (readOnlyCount > 0) {
            if (stateChanged) {
              if (readWriteCount > 0) {
                await addLog(t('messages.devicesDetected', { count: devices.length, readOnly: readOnlyCount, readWrite: readWriteCount }), 'info');
              } else {
                await addLog(t('messages.devicesDetectedAllReadOnly', { count: devices.length }), 'warning');
              }
            }
          } else {
            if (stateChanged) {
              await addLog(t('messages.devicesDetectedAllReadWrite', { count: devices.length }), 'success');
            }
          }
        }

        lastDeviceCount = currentDeviceCount;
        lastDeviceState = currentState;
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        await addLog(t('messages.refreshFailed', { error: errorMessage }), 'error');
      } finally {
        showLoading(false);
      }
    };

    if (!force) {
      refreshDebounceTimer = window.setTimeout(doRefresh, REFRESH_DEBOUNCE_MS);
    } else {
      doRefresh();
    }
  }

  // 渲染设备列表（使用模块化的渲染函数）
  function renderDevices(): void {
    if (Renderer && Renderer.renderDevices) {
      // 使用模块化的渲染函数
      Renderer.renderDevices(devicesList, devicesList); // readWriteDevicesList 暂时使用同一个元素
    } else {
      // 降级实现：简单的渲染
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

      devicesList.innerHTML = '';
      devices.forEach(device => {
        if (Renderer && Renderer.createDeviceItem) {
          const item = Renderer.createDeviceItem(device);
          devicesList.appendChild(item);
        }
      });

      // 绑定事件
      if (Events && Events.bindDeviceEvents) {
        Events.bindDeviceEvents(devicesList, devicesList);
      } else {
        // 降级实现：直接绑定事件
        bindDeviceEventsDirectly();
      }
    }
  }

  // 直接绑定设备事件（降级实现）
  function bindDeviceEventsDirectly(): void {
    devicesList.querySelectorAll('.mount-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const disk = (btn as HTMLElement).dataset.disk;
        const device = devices.find(d => d.disk === disk);
        if (device) mountDevice(device);
      });
    });

    devicesList.querySelectorAll('.unmount-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const disk = (btn as HTMLElement).dataset.disk;
        const device = devices.find(d => d.disk === disk);
        if (device) unmountDevice(device);
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

  // 获取状态元素（如果不存在则使用 null，避免错误）
  function getStatusElements(): { statusDot: HTMLElement | null; statusText: HTMLElement | null } {
    return {
      statusDot: document.querySelector('.status-dot') as HTMLElement | null,
      statusText: document.querySelector('.status-text') as HTMLElement | null
    };
  }

  // 设备操作函数（使用模块化的操作函数）
  async function mountDevice(device: any): Promise<void> {
    if (Operations && Operations.mountDevice) {
      const { statusDot, statusText } = getStatusElements();
      await Operations.mountDevice(device, devicesList, devicesList, statusDot || devicesList, statusText || devicesList);
      await refreshDevices();
    } else {
      // 降级实现
      await mountDeviceDirectly(device);
    }
  }

  async function restoreToReadOnly(device: any): Promise<void> {
    if (Operations && Operations.restoreToReadOnly) {
      const { statusDot, statusText } = getStatusElements();
      await Operations.restoreToReadOnly(device, devicesList, devicesList, statusDot || devicesList, statusText || devicesList);
      await refreshDevices();
    } else {
      // 降级实现
      await restoreToReadOnlyDirectly(device);
    }
  }

  async function unmountDevice(device: any): Promise<void> {
    if (Operations && Operations.unmountDevice) {
      const { statusDot, statusText } = getStatusElements();
      await Operations.unmountDevice(device, devicesList, devicesList, statusDot || devicesList, statusText || devicesList);
      await refreshDevices();
    } else {
      // 降级实现
      await unmountDeviceDirectly(device);
    }
  }

  async function ejectDevice(device: any): Promise<void> {
    if (Operations && Operations.ejectDevice) {
      const { statusDot, statusText } = getStatusElements();
      await Operations.ejectDevice(device, devicesList, devicesList, statusDot || devicesList, statusText || devicesList);
      await refreshDevices();
    } else {
      // 降级实现
      await ejectDeviceDirectly(device);
    }
  }

  async function mountAllDevices(): Promise<void> {
    if (Operations && Operations.mountAllDevices) {
      const { statusDot, statusText } = getStatusElements();
      await Operations.mountAllDevices(devicesList, devicesList, statusDot || devicesList, statusText || devicesList);
      await refreshDevices();
    } else {
      // 降级实现
      await mountAllDevicesDirectly();
    }
  }

  async function restoreAllToReadOnly(): Promise<void> {
    if (Operations && Operations.restoreAllToReadOnly) {
      const { statusDot, statusText } = getStatusElements();
      await Operations.restoreAllToReadOnly(devicesList, devicesList, statusDot || devicesList, statusText || devicesList);
      await refreshDevices();
    } else {
      // 降级实现
      await restoreAllToReadOnlyDirectly();
    }
  }

  async function ejectAllDevices(): Promise<void> {
    if (Operations && Operations.ejectAllDevices) {
      const { statusDot, statusText } = getStatusElements();
      await Operations.ejectAllDevices(devicesList, devicesList, statusDot || devicesList, statusText || devicesList);
      await refreshDevices();
    } else {
      // 降级实现
      await ejectAllDevicesDirectly();
    }
  }

  // 降级实现的操作函数（如果模块未加载）
  async function mountDeviceDirectly(device: any): Promise<void> {
    try {
      showLoading(true);
      await addLog(t('messages.mounting', { name: device.volumeName }), 'info');
      const result = await electronAPI.mountDevice(device);
      if (result.success) {
        if (result.result) {
          await addLog(result.result, 'success');
        }
        await new Promise(resolve => setTimeout(resolve, 500));
        await refreshDevices();
      } else {
        await addLog(`${t('messages.mountError')}: ${result.error || t('messages.unknownError')}`, 'error');
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      await addLog(`${t('messages.mountError')}: ${errorMessage}`, 'error');
    } finally {
      showLoading(false);
    }
  }

  async function restoreToReadOnlyDirectly(device: any): Promise<void> {
    try {
      showLoading(true);
      await addLog(t('messages.restoring', { name: device.volumeName }), 'info');
      const result = await electronAPI.restoreToReadOnly(device);
      if (result.success) {
        if (result.result) {
          await addLog(result.result, 'success');
        }
        setTimeout(async () => {
          await refreshDevices();
        }, 2000);
      } else {
        await addLog(`${t('messages.restoreError')}: ${result.error || t('messages.unknownError')}`, 'error');
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      await addLog(`${t('messages.restoreError')}: ${errorMessage}`, 'error');
    } finally {
      showLoading(false);
    }
  }

  async function unmountDeviceDirectly(device: any): Promise<void> {
    try {
      showLoading(true);
      await addLog(t('messages.unmounting', { name: device.volumeName }) || `正在卸载 ${device.volumeName}...`, 'info');
      await addLog('提示：请在弹出的对话框中输入管理员密码', 'info');
      const result = await electronAPI.unmountDevice(device);
      if (result.success) {
        if (result.result) {
          await addLog(result.result, 'success');
        }
        await refreshDevices();
      } else {
        await addLog(`卸载失败: ${result.error || '未知错误'}`, 'error');
        if (result.error?.includes('密码错误')) {
          await addLog('提示：密码错误，请重试', 'warning');
        } else if (result.error?.includes('用户取消')) {
          await addLog('提示：已取消操作', 'info');
        }
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      await addLog(`卸载失败: ${errorMessage}`, 'error');
    } finally {
      showLoading(false);
    }
  }

  async function ejectDeviceDirectly(device: any): Promise<void> {
    try {
      showLoading(true);
      await addLog(t('messages.ejecting', { name: device.volumeName }), 'info');
      const result = await electronAPI.ejectDevice(device);
      if (result.success) {
        if (result.result) {
          await addLog(result.result, 'success');
        }
        await refreshDevices();
      } else {
        await addLog(`${t('messages.ejectError')}: ${result.error || t('messages.unknownError')}`, 'error');
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      await addLog(`${t('messages.ejectError')}: ${errorMessage}`, 'error');
    } finally {
      showLoading(false);
    }
  }

  async function mountAllDevicesDirectly(): Promise<void> {
    const readOnlyDevices = devices.filter(d => d.isReadOnly && !d.isUnmounted);
    if (readOnlyDevices.length === 0) {
      await addLog(t('messages.noDevicesToMount'), 'info');
      return;
    }
    try {
      showLoading(true);
      await addLog(t('messages.mountAllStart', { count: readOnlyDevices.length }), 'info');
      let successCount = 0;
      let failCount = 0;
      for (const device of readOnlyDevices) {
        try {
          const result = await electronAPI.mountDevice(device);
          if (result.success) {
            successCount++;
            await addLog(`${device.volumeName} ${t('messages.mountSuccess')}`, 'success');
          } else {
            failCount++;
            await addLog(`${device.volumeName} ${t('messages.mountError')}: ${result.error || t('messages.unknownError')}`, 'error');
          }
        } catch (error) {
          failCount++;
          const errorMessage = error instanceof Error ? error.message : String(error);
          await addLog(`${device.volumeName} ${t('messages.mountError')}: ${errorMessage}`, 'error');
        }
      }
      if (successCount > 0) {
        await addLog(t('messages.mountAllSuccess', { count: successCount }), 'success');
      }
      if (failCount > 0) {
        await addLog(t('messages.mountAllError', { count: failCount }), 'warning');
      }
      await new Promise(resolve => setTimeout(resolve, 500));
      await refreshDevices();
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      await addLog(`${t('messages.mountError')}: ${errorMessage}`, 'error');
    } finally {
      showLoading(false);
    }
  }

  async function restoreAllToReadOnlyDirectly(): Promise<void> {
    const readWriteDevices = devices.filter(d => !d.isReadOnly && !d.isUnmounted);
    if (readWriteDevices.length === 0) {
      await addLog(t('messages.noDevicesToRestore') || '没有需要还原的设备', 'info');
      return;
    }
    try {
      showLoading(true);
      await addLog(t('messages.restoreAllStart', { count: readWriteDevices.length }), 'info');
      let successCount = 0;
      let failCount = 0;
      for (const device of readWriteDevices) {
        try {
          const result = await electronAPI.restoreToReadOnly(device);
          if (result.success) {
            successCount++;
            await addLog(`${device.volumeName} ${t('messages.restoreSuccess')}`, 'success');
          } else {
            failCount++;
            await addLog(`${device.volumeName} ${t('messages.restoreError')}: ${result.error || t('messages.unknownError')}`, 'error');
          }
        } catch (error) {
          failCount++;
          const errorMessage = error instanceof Error ? error.message : String(error);
          await addLog(`${device.volumeName} ${t('messages.restoreError')}: ${errorMessage}`, 'error');
        }
      }
      if (successCount > 0) {
        await addLog(t('messages.restoreAllSuccess', { count: successCount }), 'success');
      }
      if (failCount > 0) {
        await addLog(t('messages.restoreAllError', { count: failCount }), 'warning');
      }
      setTimeout(async () => {
        await refreshDevices();
      }, 2000);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      await addLog(`${t('messages.restoreError')}: ${errorMessage}`, 'error');
    } finally {
      showLoading(false);
    }
  }

  async function ejectAllDevicesDirectly(): Promise<void> {
    if (devices.length === 0) {
      await addLog(t('messages.noDevicesToEject') || '没有需要推出的设备', 'info');
      return;
    }
    const confirmed = confirm(`${t('devices.ejectAllConfirm')}\n\n⚠️ ${t('devices.ejectAllConfirmNote') || '请确保没有程序正在使用这些设备'}`);
    if (!confirmed) {
      await addLog(t('messages.cancelled'), 'info');
      return;
    }
    try {
      showLoading(true);
      await addLog(t('messages.ejectAllStart', { count: devices.length }), 'info');
      let successCount = 0;
      let failCount = 0;
      for (const device of devices) {
        try {
          const result = await electronAPI.ejectDevice(device);
          if (result.success) {
            successCount++;
            await addLog(`${device.volumeName} ${t('messages.ejectSuccess')}`, 'success');
          } else {
            failCount++;
            await addLog(`${device.volumeName} ${t('messages.ejectError')}: ${result.error || t('messages.unknownError')}`, 'error');
          }
        } catch (error) {
          failCount++;
          const errorMessage = error instanceof Error ? error.message : String(error);
          await addLog(`${device.volumeName} ${t('messages.ejectError')}: ${errorMessage}`, 'error');
        }
      }
      if (successCount > 0) {
        await addLog(t('messages.ejectAllSuccess', { count: successCount }), 'success');
      }
      if (failCount > 0) {
        await addLog(t('messages.ejectAllError', { count: failCount }), 'warning');
      }
      await refreshDevices();
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      await addLog(`${t('messages.ejectError')}: ${errorMessage}`, 'error');
    } finally {
      showLoading(false);
    }
  }

  // 自动刷新（优化版：混合检测 - 事件驱动 + 智能轮询备用）
  async function startAutoRefresh(): Promise<void> {
    // 停止旧的轮询
    if (autoRefreshInterval) {
      clearInterval(autoRefreshInterval);
      autoRefreshInterval = null;
    }

    // 尝试使用混合检测（事件驱动优先）
    try {
      if (electronAPI && typeof electronAPI.startHybridDetection === 'function') {
        const windowType = document.body && document.body.classList.contains('tray-window') ? '托盘窗口' : '主窗口';

        await electronAPI.startHybridDetection((newDevices: any[]) => {
          console.log(`[${windowType}] 设备变化事件触发，设备数量:`, newDevices.length);

          // 立即更新设备列表
          devices = newDevices;

          // 更新 AppModules.Devices.devices（如果存在）
          if ((window as any).AppModules?.Devices) {
            (window as any).AppModules.Devices.devices = devices;
          }

          // 强制重新渲染（确保UI更新）
          renderDevices();
          updateDeviceState();

          // 如果是托盘窗口，额外确保更新
          if (document.body && document.body.classList.contains('tray-window')) {
            console.log(`[${windowType}] UI已更新，当前显示设备数量:`, devices.length);
            // 强制触发重排，确保窗口高度正确
            if (window.electronAPI && typeof window.electronAPI.adjustTrayWindowHeightByDeviceCount === 'function') {
              window.electronAPI.adjustTrayWindowHeightByDeviceCount(devices.length);
            }
          }
        });

        hybridDetectionStarted = true;
        console.log(`✅ [混合检测] 事件监听器已注册 - ${windowType}`);

        // 监听窗口可见性变化
        document.addEventListener('visibilitychange', () => {
          if (electronAPI && typeof electronAPI.updateWindowVisibility === 'function') {
            electronAPI.updateWindowVisibility(!document.hidden);
          }

          // 窗口变为可见时，立即强制刷新设备列表
          if (!document.hidden) {
            setTimeout(() => {
              refreshDevices(true);
            }, 100);
          }
        });

        return;
      }
    } catch (error) {
      console.warn('[混合检测] 启动失败，降级到轮询模式:', error);
    }

    // 降级到智能轮询（如果混合检测不可用）
    console.log('⚠️ [混合检测] 使用智能轮询模式');
    hybridDetectionStarted = false;

    let currentInterval = 500;
    let consecutiveChanges = 0;
    let lastDeviceHash = '';

    const poll = async () => {
      try {
        const oldDeviceHash = JSON.stringify(devices.map(d => ({ disk: d.disk, isMounted: d.isMounted, isReadOnly: d.isReadOnly })));

        await refreshDevices(true);

        const newDeviceHash = JSON.stringify(devices.map(d => ({ disk: d.disk, isMounted: d.isMounted, isReadOnly: d.isReadOnly })));
        const hasChanged = oldDeviceHash !== newDeviceHash;

        // 根据状态调整轮询间隔
        if (hasChanged) {
          consecutiveChanges++;
          currentInterval = 1000;
        } else {
          if (consecutiveChanges > 0) {
            consecutiveChanges = Math.max(0, consecutiveChanges - 1);
          }

          if (devices.length === 0) {
            currentInterval = 30000;
          } else if (consecutiveChanges === 0) {
            currentInterval = 5000;
          }
        }

        if (consecutiveChanges > 3) {
          consecutiveChanges = 0;
          currentInterval = 5000;
        }

        const isVisible = !document.hidden;
        if (!isVisible) {
          currentInterval = 60000;
        }

        lastDeviceHash = newDeviceHash;
        autoRefreshInterval = setTimeout(poll, currentInterval);
      } catch (error) {
        console.error('[智能轮询] 检测失败:', error);
        autoRefreshInterval = setTimeout(poll, 5000);
      }
    };

    poll();
  }

  // 更新设备状态（用于日志）
  async function updateDeviceState(): Promise<void> {
    const currentDeviceCount = devices.length;
    const readOnlyCount = devices.filter(d => d.isReadOnly).length;
    const currentState = `${currentDeviceCount}-${readOnlyCount}`;

    const stateChanged = currentDeviceCount !== lastDeviceCount || currentState !== lastDeviceState;

    if (devices.length === 0) {
      if (stateChanged) {
        await addLog(t('messages.noDevicesDetected'), 'info');
      }
    } else {
      const readWriteCount = devices.length - readOnlyCount;

      if (readOnlyCount > 0) {
        if (stateChanged) {
          if (readWriteCount > 0) {
            await addLog(t('messages.devicesDetected', { count: devices.length, readOnly: readOnlyCount, readWrite: readWriteCount }), 'info');
          } else {
            await addLog(t('messages.devicesDetectedAllReadOnly', { count: devices.length }), 'warning');
          }
        }
      } else {
        if (stateChanged) {
          await addLog(t('messages.devicesDetectedAllReadWrite', { count: devices.length }), 'success');
        }
      }
    }

    lastDeviceCount = currentDeviceCount;
    lastDeviceState = currentState;
  }

  // 初始化
  // 将 refreshDevices 暴露到 window 对象，供外部调用
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
              if (typeof refreshDevices === 'function') {
                refreshDevices();
              }
            }, 100);
          }
        }
      });
    });

    if (document.body) {
      observer.observe(document.body, { attributes: true, attributeFilter: ['class'] });
      if (document.body.classList.contains('tray-window')) {
        setTimeout(() => {
          if (typeof refreshDevices === 'function') {
            refreshDevices();
          }
        }, 100);
      }
    }

    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => {
        if (document.body) {
          observer.observe(document.body, { attributes: true, attributeFilter: ['class'] });
          if (document.body.classList.contains('tray-window')) {
            setTimeout(() => {
              if (typeof refreshDevices === 'function') {
                refreshDevices();
              }
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

    // 监听语言变更事件（修复：使用事件监听而不是回调）
    window.addEventListener('languageChanged', async () => {
      // 延迟一点确保翻译已加载
      await new Promise(resolve => setTimeout(resolve, 100));

      // 更新按钮文本
      updateButtonTexts();

      // 清除设备列表的缓存，强制重新渲染
      if (Renderer && Renderer.lastRenderedDevices) {
        Renderer.lastRenderedDevices = [];
      }

      // 清除设备列表的状态缓存，强制重新渲染（修复：清除 __lastStateKey）
      if (devicesList) {
        (devicesList as any).__lastStateKey = '';
      }

      // 重新渲染设备列表以更新按钮文本和所有翻译
      renderDevices();

      // 如果设备列表不为空，刷新设备状态
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
