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
  // 自动读写：记录本窗口已经尝试过的设备，避免刷新/多回调导致重复弹密码框
  const autoMountAttemptedDisks: Set<string> =
    (AppModules.Devices && (AppModules.Devices as any).autoMountAttemptedDisks) ||
    new Set<string>();
  if (AppModules.Devices) {
    (AppModules.Devices as any).autoMountAttemptedDisks = autoMountAttemptedDisks;
  }
  // 自动读写冷却：用户刚刚手动设为只读时，短时间内禁止自动挂载
  const autoMountCooldown: Map<string, number> =
    (AppModules.Devices && (AppModules.Devices as any).autoMountCooldown) || new Map<string, number>();
  if (AppModules.Devices) {
    (AppModules.Devices as any).autoMountCooldown = autoMountCooldown;
  }

  // 手动只读追踪：让“手动只读”仅在插拔周期内生效，拔出 9 秒后自动恢复默认
  const MANUAL_GRACE_MS = 9 * 1000;
  const manualLastSeen: Map<string, number> =
    (AppModules.Devices && (AppModules.Devices as any).manualLastSeen) || new Map<string, number>();
  let manualPruneTimer: number | null =
    (AppModules.Devices && (AppModules.Devices as any).manualPruneTimer) || null;
  if (AppModules.Devices) {
    (AppModules.Devices as any).manualLastSeen = manualLastSeen;
    (AppModules.Devices as any).manualPruneTimer = manualPruneTimer;
  }

  async function pruneManuallyReadOnlyDevices(manualList: string[], devices: any[]): Promise<string[]> {
    if (!manualList || manualList.length === 0) return [];
    const now = Date.now();

    const currentIds = new Set<string>();
    devices.forEach(d => {
      const ids = [d.volumeUuid, d.disk].filter(Boolean) as string[];
      ids.forEach(id => {
        if (manualList.includes(id)) {
          currentIds.add(id);
          manualLastSeen.set(id, now);
        }
      });
    });

    // 新加入的手动记录确保有 lastSeen 时间
    manualList.forEach(id => {
      if (!manualLastSeen.has(id)) {
        manualLastSeen.set(id, now);
      }
    });

    const pruned = manualList.filter(id => {
      if (currentIds.has(id)) return true;
      const lastSeen = manualLastSeen.get(id) || 0;
      return now - lastSeen <= MANUAL_GRACE_MS;
    });
    const deduped = Array.from(new Set(pruned));

    // 如存在离线项，宽限期后再尝试一次清理，避免事件缺失导致残留
    const hasOffline = deduped.some(id => !currentIds.has(id));
    if (hasOffline) {
      if (manualPruneTimer) window.clearTimeout(manualPruneTimer);
      manualPruneTimer = window.setTimeout(async () => {
        manualPruneTimer = null;
        try {
          const latestDevices = await electronAPI.getNTFSDevices(true);
          const latestSettings = await electronAPI.getSettings();
          const latestManual = latestSettings?.manuallyReadOnlyDevices || [];
          await pruneManuallyReadOnlyDevices(latestManual, latestDevices);
        } catch (error) {
          console.warn('[设备刷新] 延迟清理手动只读失败:', error);
        }
      }, MANUAL_GRACE_MS + 300);
      if (AppModules.Devices) {
        (AppModules.Devices as any).manualPruneTimer = manualPruneTimer;
      }
    }

    if (deduped.length !== manualList.length || deduped.some((v, i) => v !== manualList[i])) {
      try {
        await electronAPI.saveSettings({ manuallyReadOnlyDevices: deduped });
        console.log(`[设备刷新] 已整理手动只读列表: ${manualList.length} -> ${deduped.length}`);
      } catch (error) {
        console.warn('[设备刷新] 保存手动只读列表失败:', error);
      }
    }
    return deduped;
  }

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
  const EVENT_DRIVEN_DEBOUNCE_MS = 50; // 事件驱动模式下使用更短的防抖时间

  async function refreshDevices(
    devicesList: HTMLElement,
    force: boolean = false,
    state: {
      devices: any[];
      lastDeviceCount: number;
      lastDeviceState: string;
    },
    providedDevices?: any[] // 如果提供了设备列表，说明是事件驱动模式
  ): Promise<any[]> {
    // 如果提供了设备列表（事件驱动模式），使用更短的防抖时间，并且跳过防抖直接执行
    const debounceMs = providedDevices ? EVENT_DRIVEN_DEBOUNCE_MS : REFRESH_DEBOUNCE_MS;
    const shouldSkipDebounce = providedDevices !== undefined; // 事件驱动模式下跳过防抖

    // 防抖：短时间内多次调用只执行最后一次
    if (!force && refreshDebounceTimer !== null) {
      clearTimeout(refreshDebounceTimer);
    }

    const doRefresh = async (): Promise<any[]> => {
      try {
        showLoading(true);
        // 优先使用 AppModules.Devices.devices（全局共享，更可靠），如果没有则使用 state.devices
        const previousGlobalDevices = AppModules.Devices && AppModules.Devices.devices ? AppModules.Devices.devices : state.devices;
        const oldDevices = [...previousGlobalDevices];
        const previousDevicePaths = oldDevices.map(d => d.devicePath);
        // 如果提供了设备列表（事件驱动模式），直接使用；否则从API获取
        const devices = providedDevices || await electronAPI.getNTFSDevices(force);

        // 更新 AppModules.Devices.devices（如果存在）
        if (AppModules.Devices) {
          AppModules.Devices.devices = devices;
        }
        // 同时更新 state.devices，保持同步
        state.devices = devices;

        // 增量更新：只更新变化的部分
        // 需要同时对比挂载状态、读写状态和卸载标记，确保托盘/主窗口都能正确刷新 UI
        // 首先检查设备数量变化（设备移除或新增）
        const deviceCountChanged = oldDevices.length !== devices.length;

        // 检查设备列表是否有变化（通过 disk 标识）
        const oldDeviceDisks = new Set(oldDevices.map(d => d.disk));
        const newDeviceDisks = new Set(devices.map(d => d.disk));
        const deviceListChanged = deviceCountChanged ||
          [...oldDeviceDisks].some(disk => !newDeviceDisks.has(disk)) ||
          [...newDeviceDisks].some(disk => !oldDeviceDisks.has(disk));

        // 检查设备状态变化
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

        // 使用 Map 来比较状态，更准确
        const oldStateMap = new Map(oldState.map(s => [s.disk, s]));
        const newStateMap = new Map(newState.map(s => [s.disk, s]));
        let stateChanged = false;

        // 检查状态变化
        for (const [disk, newS] of newStateMap) {
          const oldS = oldStateMap.get(disk);
          if (!oldS ||
              oldS.isMounted !== newS.isMounted ||
              oldS.isReadOnly !== newS.isReadOnly ||
              oldS.isUnmounted !== newS.isUnmounted) {
            stateChanged = true;
            break;
          }
        }

        // 如果有设备被移除，也要检查
        for (const [disk] of oldStateMap) {
          if (!newStateMap.has(disk)) {
            stateChanged = true;
            break;
          }
        }

        const hasChanged = deviceListChanged || stateChanged;

        // 如果有变化或强制刷新，更新UI
        if (hasChanged || force) {
          renderDevices(devicesList, devices);
        }

        const currentDeviceCount = devices.length;

        // 自动读写：清理已移除设备的尝试记录，确保下次插入还能自动挂载
        const currentDiskSet = new Set(devices.map(d => d.disk));
        for (const disk of Array.from(autoMountAttemptedDisks)) {
          if (!currentDiskSet.has(disk)) {
            autoMountAttemptedDisks.delete(disk);
          }
        }

        // 读取设置中的“手动只读”列表
        // 说明：
        // - 这里不再做自动清理 / 宽限期回收，避免用户设为只读后又被自动读写抢回
        // - 只在用户主动执行“配置为可读写”“全读写”等操作时，才从手动只读列表中移除（见 device-operations.ts / ipc-handlers.ts）
        let settings: any = null;
        let manuallyReadOnlyDevices: string[] = [];
        try {
          settings = await electronAPI.getSettings();
          manuallyReadOnlyDevices = settings?.manuallyReadOnlyDevices || [];
        } catch (error) {
          console.warn('[设备刷新] 获取设置失败:', error);
        }

        // 自动挂载候选：任何“只读且未卸载”的设备（不依赖“新设备检测”，避免多处刷新导致漏触发）
        const candidates = devices.filter(d => d.isReadOnly && !d.isUnmounted);

        if (candidates.length > 0) {
          try {
            // 自动读写开启时，后台自动挂载新插入设备（状态保护仅用于防误触按钮，不应阻断后台自动挂载）
            if (settings && settings.autoMount) {
              // 自动挂载候选只读设备（跳过用户手动设置为只读 & 已尝试过的设备 & 冷却期内的设备）
              for (const device of candidates) {
                const now = Date.now();
                const inCooldown =
                  (device.volumeUuid && (autoMountCooldown.get(device.volumeUuid) || 0) > now) ||
                  (device.disk && (autoMountCooldown.get(device.disk) || 0) > now);
                if (inCooldown) {
                  continue;
                }
                // 如果设备在手动只读列表中，跳过自动挂载
                const manualId = (device as any).volumeUuid || device.disk;
                if (manuallyReadOnlyDevices.includes(manualId) || manuallyReadOnlyDevices.includes(device.disk)) {
                  continue;
                }
                // 已尝试过则跳过，避免重复弹框/重复执行
                if (autoMountAttemptedDisks.has(device.disk)) {
                  continue;
                }
                try {
                  autoMountAttemptedDisks.add(device.disk);
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
              // 重新刷新设备列表以更新状态（强制刷新，确保获取最新状态）
              const updatedDevices = await electronAPI.getNTFSDevices(true);
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
        const deviceStateChanged = currentDeviceCount !== state.lastDeviceCount || currentState !== state.lastDeviceState;

        if (devices.length === 0) {
          if (deviceStateChanged) {
            await addLog(t('messages.noDevicesDetected'), 'info');
          }
        } else {
          const readWriteCount = devices.length - readOnlyCount;

          if (readOnlyCount > 0) {
            if (deviceStateChanged) {
              if (readWriteCount > 0) {
                await addLog(t('messages.devicesDetected', { count: devices.length, readOnly: readOnlyCount, readWrite: readWriteCount }), 'info');
              } else {
                await addLog(t('messages.devicesDetectedAllReadOnly', { count: devices.length }), 'warning');
              }
            }
          } else {
            if (deviceStateChanged) {
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

    // 如果提供了设备列表（事件驱动模式），跳过防抖直接执行，加快响应
    if (shouldSkipDebounce || force) {
      // 清除可能存在的防抖定时器
      if (refreshDebounceTimer !== null) {
        clearTimeout(refreshDebounceTimer);
        refreshDebounceTimer = null;
      }
      return doRefresh();
    } else {
      return new Promise((resolve) => {
        refreshDebounceTimer = window.setTimeout(async () => {
          const result = await doRefresh();
          resolve(result);
        }, debounceMs);
      });
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
