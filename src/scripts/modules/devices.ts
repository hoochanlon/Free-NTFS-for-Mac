// 设备管理模块主文件 - 整合各个子模块
// 注意：不使用 import，避免生成 CommonJS 代码（浏览器环境不支持）

(function() {
  'use strict';

  // 创建全局命名空间
  if (typeof (window as any).AppModules === 'undefined') {
    (window as any).AppModules = {};
  }

  const AppModules = (window as any).AppModules;
  const electronAPI = (window as any).electronAPI;
  const AppUtils = (window as any).AppUtils;

  // 初始化子模块命名空间（子模块会在主模块之前加载）
  if (!AppModules.Devices) {
    AppModules.Devices = {};
  }
  if (!AppModules.Devices.Renderer) {
    AppModules.Devices.Renderer = {};
  }
  if (!AppModules.Devices.Operations) {
    AppModules.Devices.Operations = {};
  }
  if (!AppModules.Devices.Events) {
    AppModules.Devices.Events = {};
  }

  // 确保子模块已加载
  if (!AppModules.Devices.Renderer || !AppModules.Devices.Operations || !AppModules.Devices.Events) {
    console.error('设备管理子模块未正确加载');
    // 如果子模块未加载，创建空对象以避免错误
    if (!AppModules.Devices.Renderer) {
      AppModules.Devices.Renderer = {
        renderDevices: () => {},
        createDeviceItem: () => document.createElement('div')
      };
    }
    if (!AppModules.Devices.Operations) {
      AppModules.Devices.Operations = {};
    }
    if (!AppModules.Devices.Events) {
      AppModules.Devices.Events = {
        bindDeviceEvents: () => {}
      };
    }
  }

  // 保存子模块引用
  const Renderer = AppModules.Devices.Renderer;
  const Operations = AppModules.Devices.Operations;
  const Events = AppModules.Devices.Events;

  // 设备管理主对象（合并到现有对象，而不是覆盖）
  Object.assign(AppModules.Devices, {
    // 设备数据（确保在子模块访问前初始化）
    devices: AppModules.Devices.devices || [] as any[],
    lastDeviceCount: AppModules.Devices.lastDeviceCount || 0,
    lastDeviceState: AppModules.Devices.lastDeviceState || '',

    // 刷新设备列表
    async refreshDevices(
      devicesList: HTMLElement,
      readWriteDevicesList: HTMLElement,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): Promise<void> {
      try {
        AppModules.Devices.devices = await electronAPI.getNTFSDevices();
        Renderer.renderDevices(devicesList, readWriteDevicesList);

        const currentDeviceCount = AppModules.Devices.devices.length;
        const readOnlyCount = AppModules.Devices.devices.filter((d: any) => d.isReadOnly).length;
        const currentState = `${currentDeviceCount}-${readOnlyCount}`;

        // 只在设备状态变化时添加日志
        const stateChanged = currentDeviceCount !== AppModules.Devices.lastDeviceCount ||
                           currentState !== AppModules.Devices.lastDeviceState;

        if (AppModules.Devices.devices.length === 0) {
          AppUtils.UI.updateStatus('active', '等待设备', statusDot, statusText);
          if (stateChanged) {
            AppUtils.Logs.addLog('未检测到 NTFS 设备', 'info');
          }
        } else {
          const readWriteCount = AppModules.Devices.devices.length - readOnlyCount;

          if (readOnlyCount > 0) {
            AppUtils.UI.updateStatus('error', `${readOnlyCount} 个设备只读`, statusDot, statusText);
            if (stateChanged) {
              if (readWriteCount > 0) {
                AppUtils.Logs.addLog(
                  `检测到 ${AppModules.Devices.devices.length} 个设备（${readOnlyCount} 个只读，${readWriteCount} 个读写）`,
                  'info'
                );
              } else {
                AppUtils.Logs.addLog(
                  `检测到 ${AppModules.Devices.devices.length} 个 NTFS 设备（全部只读）`,
                  'warning'
                );
              }
            }
          } else {
            AppUtils.UI.updateStatus('active', `${AppModules.Devices.devices.length} 个设备就绪`, statusDot, statusText);
            if (stateChanged) {
              AppUtils.Logs.addLog(
                `检测到 ${AppModules.Devices.devices.length} 个 NTFS 设备（全部可读写）`,
                'success'
              );
            }
          }
        }

        AppModules.Devices.lastDeviceCount = currentDeviceCount;
        AppModules.Devices.lastDeviceState = currentState;
      } catch (error) {
        AppUtils.UI.updateStatus('error', '检测失败', statusDot, statusText);
        const errorMessage = error instanceof Error ? error.message : String(error);
        AppUtils.Logs.addLog(`刷新设备列表失败: ${errorMessage}`, 'error');
      }
    },

    // 委托给子模块的方法
    renderDevices: Renderer.renderDevices,
    createDeviceItem: Renderer.createDeviceItem,
    mountDevice: Operations.mountDevice,
    unmountDevice: Operations.unmountDevice,
    restoreToReadOnly: Operations.restoreToReadOnly,
    restoreAllToReadOnly: Operations.restoreAllToReadOnly,
    unmountAllDevices: Operations.unmountAllDevices,
    bindDeviceEvents: Events.bindDeviceEvents
  });

})();
