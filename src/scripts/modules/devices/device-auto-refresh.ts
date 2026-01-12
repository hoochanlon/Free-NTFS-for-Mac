// 设备自动刷新模块
// 负责混合检测（事件驱动 + 智能轮询备用）

(function() {
  'use strict';

  if (typeof (window as any).AppModules === 'undefined') {
    (window as any).AppModules = {};
  }
  const AppModules = (window as any).AppModules;
  if (!AppModules.Devices) {
    AppModules.Devices = {};
  }
  if (!AppModules.Devices.AutoRefresh) {
    AppModules.Devices.AutoRefresh = {};
  }

  const electronAPI = window.electronAPI;

  let autoRefreshInterval: NodeJS.Timeout | null = null;
  let hybridDetectionStarted: boolean = false;
  let hybridDetectionCallback: ((devices: any[]) => void) | null = null;

  function stopAutoRefresh(): void {
    if (autoRefreshInterval) {
      clearInterval(autoRefreshInterval);
      autoRefreshInterval = null;
    }
    hybridDetectionStarted = false;
    hybridDetectionCallback = null;
  }

  async function startAutoRefresh(
    refreshDevicesFn: (force: boolean) => Promise<void>,
    renderDevicesFn: () => void,
    updateDeviceStateFn: () => Promise<void>,
    devices: any[]
  ): Promise<void> {
    // 停止旧的轮询
    stopAutoRefresh();

    // 尝试使用混合检测（事件驱动优先）
    try {
      if (electronAPI && typeof electronAPI.startHybridDetection === 'function') {
        const windowType = document.body && document.body.classList.contains('tray-window') ? '托盘窗口' : '主窗口';

        // 如果已经注册过回调，先不重复注册（避免重复调用 startHybridDetection）
        if (hybridDetectionStarted && hybridDetectionCallback) {
          console.log(`[${windowType}] 混合检测已启动，跳过重复注册`);
          return;
        }

        const callback = async (newDevices: any[]) => {
          console.log(`[${windowType}] 设备变化事件触发，设备数量:`, newDevices.length, '设备列表:', newDevices.map((d: any) => d.volumeName || d.disk));

          // 确保 newDevices 是有效的数组
          if (!Array.isArray(newDevices)) {
            console.error(`[${windowType}] 设备列表不是数组:`, newDevices);
            return;
          }

          // 立即更新设备列表
          devices.length = 0;
          devices.push(...newDevices);

          // 更新 AppModules.Devices.devices（如果存在）
          if (AppModules.Devices) {
            AppModules.Devices.devices = devices;
          }

          // 强制刷新设备列表（确保UI更新和状态同步）
          try {
            await refreshDevicesFn(true);
            console.log(`[${windowType}] 设备列表已刷新，当前设备数量:`, devices.length);
          } catch (error) {
            console.error(`[${windowType}] 刷新设备列表失败:`, error);
          }

          // 如果是托盘窗口，额外确保更新
          if (document.body && document.body.classList.contains('tray-window')) {
            console.log(`[${windowType}] UI已更新，当前显示设备数量:`, devices.length);
            // 强制触发重排，确保窗口高度正确
            if (window.electronAPI && typeof window.electronAPI.adjustTrayWindowHeightByDeviceCount === 'function') {
              window.electronAPI.adjustTrayWindowHeightByDeviceCount(devices.length);
            }
          }
        };

        hybridDetectionCallback = callback;

        await electronAPI.startHybridDetection(callback);

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
              refreshDevicesFn(true);
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

        await refreshDevicesFn(true);

        const newDeviceHash = JSON.stringify(devices.map(d => ({ disk: d.disk, isMounted: d.isMounted, isReadOnly: d.isReadOnly })));
        const hasChanged = oldDeviceHash !== newDeviceHash;

        // 根据状态调整轮询间隔
        if (hasChanged) {
          consecutiveChanges++;
          // 状态变化时，快速刷新（1秒），确保托盘窗口能立即看到变化
          currentInterval = 1000;
        } else {
          if (consecutiveChanges > 0) {
            consecutiveChanges = Math.max(0, consecutiveChanges - 1);
          }

          if (devices.length === 0) {
            currentInterval = 30000;
          } else if (consecutiveChanges === 0) {
            // 托盘窗口场景下，使用更短的轮询间隔（2秒），确保状态变化能快速反映
            const isTrayWindow = document.body && document.body.classList.contains('tray-window');
            currentInterval = isTrayWindow ? 2000 : 5000;
          }
        }

        if (consecutiveChanges > 3) {
          consecutiveChanges = 0;
          const isTrayWindow = document.body && document.body.classList.contains('tray-window');
          currentInterval = isTrayWindow ? 2000 : 5000;
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

  AppModules.Devices.AutoRefresh = {
    startAutoRefresh,
    stopAutoRefresh,
    get hybridDetectionStarted() { return hybridDetectionStarted; }
  };

})();
