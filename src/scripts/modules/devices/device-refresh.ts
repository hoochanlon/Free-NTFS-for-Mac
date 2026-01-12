// 设备刷新模块
// 负责设备列表的刷新逻辑、状态更新和自动挂载

(function() {
  'use strict';

  if (typeof (window as any).AppModules === 'undefined') {
    (window as any).AppModules = {};
  }
  const AppModules = (window as any).AppModules;
  if (!AppModules.Devices) {
    AppModules.Devices = {};
  }
  if (!AppModules.Devices.Refresh) {
    AppModules.Devices.Refresh = {};
  }

  const electronAPI = window.electronAPI;
  const Utils = AppModules.Devices?.Utils;
  const Renderer = AppModules.Devices?.Renderer;

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

  function showLoading(show: boolean = true): void {
    // 如果是托盘窗口，不显示加载遮罩（无感刷新）
    const isTrayWindow = document.body && document.body.classList.contains('tray-window');
    if (isTrayWindow) {
      return; // 托盘窗口不显示加载遮罩
    }

    if (Utils && Utils.showLoading) {
      Utils.showLoading(show);
      return;
    }
    const loadingOverlay = document.getElementById('loadingOverlay');
    if (loadingOverlay) {
      if (show) {
        loadingOverlay.classList.add('visible');
        // 更新加载文本为"刷新中..."而不是"正在检查..."
        const loadingText = loadingOverlay.querySelector('p');
        if (loadingText) {
          const refreshText = t('tray.refreshing') || t('devices.refreshDevices') || '刷新中...';
          loadingText.textContent = refreshText;
        }
      } else {
        loadingOverlay.classList.remove('visible');
      }
    }
  }

  function renderDevices(devicesList: HTMLElement, devices: any[]): void {
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
        return;
      }
      devicesList.innerHTML = '';
      devices.forEach(device => {
        if (Renderer && Renderer.createDeviceItem) {
          const item = Renderer.createDeviceItem(device);
          devicesList.appendChild(item);
        }
      });
    }
  }

  // 刷新设备列表（优化版：防抖和增量更新）
  let refreshDebounceTimer: number | null = null;
  const REFRESH_DEBOUNCE_MS = 200;

  async function refreshDevices(
    devicesList: HTMLElement,
    force: boolean = false,
    state: {
      devices: any[];
      lastDeviceCount: number;
      lastDeviceState: string;
    }
  ): Promise<any[]> {
    // 防抖：短时间内多次调用只执行最后一次
    if (!force && refreshDebounceTimer !== null) {
      clearTimeout(refreshDebounceTimer);
    }

    const doRefresh = async (): Promise<any[]> => {
      try {
        showLoading(true);
        const oldDevices = [...state.devices];
        const previousDevicePaths = oldDevices.map(d => d.devicePath);
        const devices = await electronAPI.getNTFSDevices();

        // 更新 AppModules.Devices.devices（如果存在）
        if (AppModules.Devices) {
          AppModules.Devices.devices = devices;
        }

        // 增量更新：只更新变化的部分
        // 需要同时对比挂载状态、读写状态和卸载标记，确保托盘/主窗口都能正确刷新 UI
        const oldState = oldDevices.map(d => ({
          disk: d.disk,
          isMounted: d.isMounted,
          isReadOnly: d.isReadOnly,
          isUnmounted: d.isUnmounted || false
        }));
        const newState = devices.map(d => ({
          disk: d.disk,
          isMounted: d.isMounted,
          isReadOnly: d.isReadOnly,
          isUnmounted: d.isUnmounted || false
        }));

        const hasChanged = JSON.stringify(oldState) !== JSON.stringify(newState);

        if (hasChanged || force) {
          renderDevices(devicesList, devices);
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
              const updatedDevices = await electronAPI.getNTFSDevices();
              if (AppModules.Devices) {
                AppModules.Devices.devices = updatedDevices;
              }
              renderDevices(devicesList, updatedDevices);
              return updatedDevices;
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
        const stateChanged = currentDeviceCount !== state.lastDeviceCount || currentState !== state.lastDeviceState;

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

        state.lastDeviceCount = currentDeviceCount;
        state.lastDeviceState = currentState;

        return devices;
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        await addLog(t('messages.refreshFailed', { error: errorMessage }), 'error');
        return state.devices;
      } finally {
        showLoading(false);
      }
    };

    if (!force) {
      return new Promise((resolve) => {
        refreshDebounceTimer = window.setTimeout(async () => {
          const result = await doRefresh();
          resolve(result);
        }, REFRESH_DEBOUNCE_MS);
      });
    } else {
      return doRefresh();
    }
  }

  // 更新设备状态（用于日志）
  async function updateDeviceState(
    devices: any[],
    state: {
      lastDeviceCount: number;
      lastDeviceState: string;
    }
  ): Promise<void> {
    const currentDeviceCount = devices.length;
    const readOnlyCount = devices.filter(d => d.isReadOnly).length;
    const currentState = `${currentDeviceCount}-${readOnlyCount}`;

    const stateChanged = currentDeviceCount !== state.lastDeviceCount || currentState !== state.lastDeviceState;

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

    state.lastDeviceCount = currentDeviceCount;
    state.lastDeviceState = currentState;
  }

  AppModules.Devices.Refresh = {
    refreshDevices,
    updateDeviceState,
    renderDevices
  };

})();
