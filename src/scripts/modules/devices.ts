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
    lastDevicePaths: AppModules.Devices.lastDevicePaths || [] as string[],

    // 刷新设备列表
    async refreshDevices(
      devicesList: HTMLElement,
      readWriteDevicesList: HTMLElement,
      statusDot: HTMLElement,
      statusText: HTMLElement,
      providedDevices?: any[] // 可选的设备列表（来自事件回调）
    ): Promise<void> {
      try {
        const previousDevices = AppModules.Devices.devices || [];
        const previousDevicePaths = previousDevices.map((d: any) => d.devicePath);

        // 如果提供了新的设备列表（来自事件回调），直接使用；否则重新获取
        if (providedDevices && Array.isArray(providedDevices)) {
          console.log('[主界面] 使用事件提供的设备列表，设备数量:', providedDevices.length);
          AppModules.Devices.devices = providedDevices;
        } else {
          console.log('[主界面] 重新获取设备列表');
          AppModules.Devices.devices = await electronAPI.getNTFSDevices();
        }

        Renderer.renderDevices(devicesList, readWriteDevicesList);

        const currentDeviceCount = AppModules.Devices.devices.length;
        const readOnlyCount = AppModules.Devices.devices.filter((d: any) => d.isReadOnly).length;
        const currentState = `${currentDeviceCount}-${readOnlyCount}`;

        // 检测新插入的设备并自动挂载
        const currentDevicePaths = AppModules.Devices.devices.map((d: any) => d.devicePath);
        const newDevices = AppModules.Devices.devices.filter((d: any) =>
          !previousDevicePaths.includes(d.devicePath) && d.isReadOnly && !d.isUnmounted
        );

        if (newDevices.length > 0) {
          try {
            const settings = await electronAPI.getSettings();
            if (settings.autoMount) {
              // 自动挂载新插入的只读设备
              for (const device of newDevices) {
                try {
                  await AppUtils.Logs.addLog(`检测到新设备 ${device.volumeName}，正在自动配置为可读写...`, 'info');
                  const result = await electronAPI.mountDevice(device);
                  if (result.success) {
                    await AppUtils.Logs.addLog(`设备 ${device.volumeName} 自动配置成功`, 'success');
                  } else {
                    await AppUtils.Logs.addLog(`设备 ${device.volumeName} 自动配置失败: ${result.error || '未知错误'}`, 'error');
                  }
                } catch (error) {
                  const errorMessage = error instanceof Error ? error.message : String(error);
                  await AppUtils.Logs.addLog(`设备 ${device.volumeName} 自动配置失败: ${errorMessage}`, 'error');
                }
              }
              // 重新刷新设备列表以更新状态
              AppModules.Devices.devices = await electronAPI.getNTFSDevices();
              Renderer.renderDevices(devicesList, readWriteDevicesList);
            }
          } catch (error) {
            console.error('自动挂载失败:', error);
          }
        }

        // 只在设备状态变化时添加日志
        const stateChanged = currentDeviceCount !== AppModules.Devices.lastDeviceCount ||
                           currentState !== AppModules.Devices.lastDeviceState;

        // 获取翻译文本的辅助函数
        function t(key: string, params?: Record<string, string | number>): string {
          if (AppUtils && AppUtils.I18n) {
            return AppUtils.I18n.t(key, params);
          }
          return key;
        }

        if (AppModules.Devices.devices.length === 0) {
          AppUtils.UI.updateStatus('active', t('status.waitingDevices'), statusDot, statusText);
          if (stateChanged) {
            await AppUtils.Logs.addLog(t('messages.noDevicesDetected'), 'info');
          }
        } else {
          const readWriteCount = AppModules.Devices.devices.length - readOnlyCount;

          if (readOnlyCount > 0) {
            AppUtils.UI.updateStatus('error', t('status.devicesReadOnly', { count: readOnlyCount }), statusDot, statusText);
            if (stateChanged) {
              if (readWriteCount > 0) {
                await AppUtils.Logs.addLog(
                  t('messages.devicesDetected', {
                    count: AppModules.Devices.devices.length,
                    readOnly: readOnlyCount,
                    readWrite: readWriteCount
                  }),
                  'info'
                );
              } else {
                await AppUtils.Logs.addLog(
                  t('messages.devicesDetectedAllReadOnly', { count: AppModules.Devices.devices.length }),
                  'warning'
                );
              }
            }
          } else {
            AppUtils.UI.updateStatus('active', t('status.devicesReady', { count: AppModules.Devices.devices.length }), statusDot, statusText);
            if (stateChanged) {
              await AppUtils.Logs.addLog(
                t('messages.devicesDetectedAllReadWrite', { count: AppModules.Devices.devices.length }),
                'success'
              );
            }
          }
        }

        AppModules.Devices.lastDeviceCount = currentDeviceCount;
        AppModules.Devices.lastDeviceState = currentState;
        AppModules.Devices.lastDevicePaths = currentDevicePaths;
      } catch (error) {
        // 获取翻译文本的辅助函数
        function t(key: string, params?: Record<string, string | number>): string {
          if (AppUtils && AppUtils.I18n) {
            return AppUtils.I18n.t(key, params);
          }
          return key;
        }
        AppUtils.UI.updateStatus('error', t('status.detectFailed'), statusDot, statusText);
        const errorMessage = error instanceof Error ? error.message : String(error);
        await AppUtils.Logs.addLog(t('messages.refreshFailed', { error: errorMessage }), 'error');
      }
    },

    // 委托给子模块的方法
    renderDevices: Renderer.renderDevices,
    createDeviceItem: Renderer.createDeviceItem,
    mountDevice: Operations.mountDevice,
    unmountDevice: Operations.unmountDevice,
    restoreToReadOnly: Operations.restoreToReadOnly,
    mountAllDevices: Operations.mountAllDevices,
    restoreAllToReadOnly: Operations.restoreAllToReadOnly,
    unmountAllDevices: Operations.unmountAllDevices,
    ejectDevice: Operations.ejectDevice,
    ejectAllDevices: Operations.ejectAllDevices,
    bindDeviceEvents: Events.bindDeviceEvents
  });

})();
