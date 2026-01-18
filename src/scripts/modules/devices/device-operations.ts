// 设备操作模块
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
  const DeviceUtils = AppModules?.Devices?.Utils;

  // 获取翻译文本的辅助函数
  function t(key: string, params?: Record<string, string | number>): string {
    if (DeviceUtils && DeviceUtils.t) {
      return DeviceUtils.t(key, params);
    }
    if (AppUtils && AppUtils.I18n) {
      return AppUtils.I18n.t(key, params);
    }
    return key; // 如果 i18n 未初始化，返回 key
  }

  // 安全地添加日志（优先使用 DeviceUtils，降级到 AppUtils，最后使用 console）
  async function addLog(message: string, type: 'info' | 'success' | 'error' | 'warning' = 'info'): Promise<void> {
    try {
      if (DeviceUtils && DeviceUtils.addLog) {
        await DeviceUtils.addLog(message, type);
        return;
      }
      if (AppUtils && AppUtils.Logs && AppUtils.Logs.addLog) {
        await addLog(message, type);
        return;
      }
      // 降级到 console（托盘窗口场景）
      console.log(`[${type.toUpperCase()}] ${message}`);
    } catch (error) {
      // 如果所有方法都失败，至少输出到控制台
      console.log(`[${type.toUpperCase()}] ${message}`);
    }
  }

  // 初始化命名空间
  if (!AppModules.Devices) {
    AppModules.Devices = {};
  }
  if (!AppModules.Devices.Operations) {
    AppModules.Devices.Operations = {};
  }

  // 统一的设备列表刷新函数（确保操作后状态立即更新）
  // 增加重试机制，确保读写状态变化能被及时捕获
  async function refreshDeviceList(devicesList: HTMLElement, retryCount: number = 0): Promise<void> {
    const Refresh = AppModules?.Devices?.Refresh;
    const maxRetries = 2; // 最多重试2次

    try {
      if (Refresh && Refresh.refreshDevices) {
        // 获取当前状态对象（从 devices.js 传入或使用默认）
        const state = (window as any).__devicesState || {
          devices: AppModules.Devices.devices || [],
          lastDeviceCount: 0,
          lastDeviceState: ''
        };
        await Refresh.refreshDevices(devicesList, true, state);

        // 如果是读写转换操作后的刷新，延迟后再次验证状态
        if (retryCount === 0) {
          setTimeout(async () => {
            try {
              // 再次强制刷新，确保状态完全同步
              const latestDevices = await electronAPI.getNTFSDevices(true);
              const currentDevices = AppModules.Devices.devices || [];

              // 检查是否有状态变化（特别是读写状态）
              const hasStateChange = latestDevices.some((newDevice: any) => {
                const oldDevice = currentDevices.find((d: any) => d.disk === newDevice.disk);
                return !oldDevice ||
                       oldDevice.isReadOnly !== newDevice.isReadOnly ||
                       oldDevice.isMounted !== newDevice.isMounted;
              });

              if (hasStateChange) {
                console.log('[设备操作] 检测到状态变化，再次刷新');
                await Refresh.refreshDevices(devicesList, true, state);
              }
            } catch (error) {
              console.warn('[设备操作] 状态验证刷新失败:', error);
            }
          }, 800); // 延迟800ms，给系统足够时间完成状态更新
        }
      } else if ((window as any).refreshDevices) {
        // 降级：使用全局 refreshDevices 函数
        await (window as any).refreshDevices(true);
      }
    } catch (error) {
      console.error('[设备操作] 刷新设备列表失败:', error);
      // 如果失败且还有重试次数，延迟后重试
      if (retryCount < maxRetries) {
        setTimeout(async () => {
          await refreshDeviceList(devicesList, retryCount + 1);
        }, 500);
      }
    }
  }

  // 设备操作功能
  AppModules.Devices.Operations = {
    // 挂载设备
    async mountDevice(
      device: any, // eslint-disable-line @typescript-eslint/no-explicit-any
      devicesList: HTMLElement,
      readWriteDevicesList: HTMLElement,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): Promise<void> {
      const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;

      try {
        // 使用设备工具中的 showLoading，自动兼容托盘窗口和降级逻辑
        if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
          DeviceUtils.showLoading(true);
        }
        await addLog(t('messages.mounting', { name: device.volumeName }), 'info');
        await addLog(t('messages.enterPassword'), 'info');

        const result = await electronAPI.mountDevice(device);

        if (result.success) {
          // 从手动只读列表中移除该设备，允许自动读写功能再次管理它
          try {
            const settings = await electronAPI.getSettings();
            const manuallyReadOnlyDevices = settings.manuallyReadOnlyDevices || [];
            const index = manuallyReadOnlyDevices.indexOf(device.disk);
            if (index > -1) {
              manuallyReadOnlyDevices.splice(index, 1);
              await electronAPI.saveSettings({ manuallyReadOnlyDevices });
            }
          } catch (error) {
            console.warn('更新手动只读设备列表失败:', error);
          }

          if (result.result) {
            await addLog(result.result, 'success');
          }
          // 等待一小段时间，确保挂载操作完全完成，标记文件已创建
          await new Promise(resolve => setTimeout(resolve, 500));

          // 强制刷新设备列表（确保状态立即更新，包含重试机制）
          await refreshDeviceList(devicesList, 0);
        } else {
          await addLog(`${t('messages.mountError')}: ${result.error || t('messages.mountError')}`, 'error');
          if (result.error?.includes('密码错误') || result.error?.includes('password')) {
            await addLog(t('messages.passwordError'), 'warning');
          } else if (result.error?.includes('用户取消') || result.error?.includes('cancelled')) {
            await addLog(t('messages.cancelled'), 'info');
          }
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        await addLog(`${t('messages.mountError')}: ${errorMessage}`, 'error');
      } finally {
        if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
          DeviceUtils.showLoading(false);
        }
      }
    },

    // 还原设备为只读模式
    async restoreToReadOnly(
      device: any, // eslint-disable-line @typescript-eslint/no-explicit-any
      devicesList: HTMLElement,
      readWriteDevicesList: HTMLElement,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): Promise<void> {
      const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;

      try {
        if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
          DeviceUtils.showLoading(true);
        }
        await addLog(t('messages.restoring', { name: device.volumeName }), 'info');
        await addLog(t('messages.enterPassword'), 'info');

        // 在还原为只读之前，先将设备添加到手动只读列表，防止自动读写功能立即将其设置为读写
        try {
          const settings = await electronAPI.getSettings();
          // 创建新数组，避免直接修改原数组引用
          const manuallyReadOnlyDevices = [...(settings.manuallyReadOnlyDevices || [])];
          if (!manuallyReadOnlyDevices.includes(device.disk)) {
            manuallyReadOnlyDevices.push(device.disk);
            await electronAPI.saveSettings({ manuallyReadOnlyDevices });
            console.log(`[设备操作] 已将设备 ${device.volumeName} (${device.disk}) 添加到手动只读列表（操作前），当前列表:`, manuallyReadOnlyDevices);
          } else {
            console.log(`[设备操作] 设备 ${device.volumeName} (${device.disk}) 已在手动只读列表中`);
          }
        } catch (error) {
          console.warn('保存手动只读设备列表失败:', error);
        }

        const result = await electronAPI.restoreToReadOnly(device);

        if (result.success) {

          if (result.result) {
            await addLog(result.result, 'success');
          }
          // 等待一小段时间，让系统重新挂载（restoreToReadOnly 需要更长时间）
          await new Promise(resolve => setTimeout(resolve, 1500));

          // 强制刷新设备列表（确保状态立即更新，包含重试机制）
          // restoreToReadOnly 操作后需要更仔细的状态检测
          await refreshDeviceList(devicesList, 0);

          // 额外延迟验证，确保只读状态完全同步
          setTimeout(async () => {
            try {
              const latestDevices = await electronAPI.getNTFSDevices(true);
              const Refresh = AppModules?.Devices?.Refresh;
              if (Refresh && Refresh.refreshDevices) {
                const state = (window as any).__devicesState || {
                  devices: AppModules.Devices.devices || [],
                  lastDeviceCount: 0,
                  lastDeviceState: ''
                };
                await Refresh.refreshDevices(devicesList, true, state);
              }
            } catch (error) {
              console.warn('[设备操作] restoreToReadOnly 状态验证失败:', error);
            }
          }, 1000);
        } else {
          await addLog(`${t('messages.restoreError')}: ${result.error || t('messages.restoreError')}`, 'error');
          if (result.error?.includes('密码错误') || result.error?.includes('password')) {
            await addLog(t('messages.passwordError'), 'warning');
          } else if (result.error?.includes('用户取消') || result.error?.includes('cancelled')) {
            await addLog(t('messages.cancelled'), 'info');
          }
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        await addLog(`${t('messages.restoreError')}: ${errorMessage}`, 'error');
      } finally {
        if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
          DeviceUtils.showLoading(false);
        }
      }
    },

    // 还原所有设备为只读模式
    async restoreAllToReadOnly(
      devicesList: HTMLElement,
      readWriteDevicesList: HTMLElement,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): Promise<void> {
      // 获取所有已挂载为读写模式的设备
      const devices = AppModules.Devices.devices || [];
      const readWriteDevices = devices.filter((d: any) => !d.isReadOnly && !d.isUnmounted);

      if (readWriteDevices.length === 0) {
        await addLog(t('messages.noDevicesToUnmount'), 'info');
        return;
      }

      const deviceNames = readWriteDevices.map((d: any) => d.volumeName).join('、');
      const title = t('devices.restoreAllReadOnly') + '？';
      const message = `将还原以下设备：\n${deviceNames}\n\n*注意：*\n* 设备将恢复为只读模式，无法写入文件\n* 已写入的文件不会丢失，但后续只能读取`;

      const confirmed = await AppUtils.UI.showConfirm(title, message);
      if (!confirmed) {
        return;
      }

      // 将所有设备添加到手动只读列表
      try {
        const settings = await electronAPI.getSettings();
        const manuallyReadOnlyDevices = settings.manuallyReadOnlyDevices || [];
        const deviceDisks = readWriteDevices.map((d: any) => d.disk);
        const newManuallyReadOnlyDevices = [...new Set([...manuallyReadOnlyDevices, ...deviceDisks])];
        await electronAPI.saveSettings({ manuallyReadOnlyDevices: newManuallyReadOnlyDevices });
      } catch (error) {
        console.warn('保存手动只读设备列表失败:', error);
      }

      const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;

      try {
        if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
          DeviceUtils.showLoading(true);
        }
        await addLog(t('messages.restoreAllStart', { count: readWriteDevices.length }), 'info');
        await addLog(t('messages.enterPassword'), 'info');

        let successCount = 0;
        let failCount = 0;

        // 逐个还原设备
        for (const device of readWriteDevices) {
          try {
            await addLog(`正在还原 ${device.volumeName} 为只读模式...`, 'info');
            const result = await electronAPI.restoreToReadOnly(device);

            if (result.success) {
              successCount++;
              if (result.result) {
                await addLog(result.result, 'success');
              }
            } else {
              failCount++;
              await addLog(`还原 ${device.volumeName} 失败: ${result.error || '未知错误'}`, 'error');
            }
          } catch (error) {
            failCount++;
            const errorMessage = error instanceof Error ? error.message : String(error);
            await addLog(`还原 ${device.volumeName} 失败: ${errorMessage}`, 'error');
          }
        }

        // 等待一小段时间，让系统重新挂载
        await new Promise(resolve => setTimeout(resolve, 1500));

        // 刷新设备列表（确保状态立即更新）
        await refreshDeviceList(devicesList);

        // 显示总结
        if (successCount > 0) {
          await addLog(t('messages.restoreAllSuccess', { count: successCount }), 'success');
        }
        if (failCount > 0) {
          await addLog(t('messages.restoreAllError', { count: failCount }), 'warning');
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        await addLog(`${t('messages.restoreError')}: ${errorMessage}`, 'error');
      } finally {
        if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
          DeviceUtils.showLoading(false);
        }
      }
    },

    // 卸载设备
    async unmountDevice(
      device: any, // eslint-disable-line @typescript-eslint/no-explicit-any
      devicesList: HTMLElement,
      readWriteDevicesList: HTMLElement,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): Promise<void> {
      const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;

      try {
        if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
          DeviceUtils.showLoading(true);
        }
        await addLog(t('messages.unmounting', { name: device.volumeName }), 'info');
        await addLog('提示：请在弹出的对话框中输入管理员密码', 'info');

        const result = await electronAPI.unmountDevice(device);

        if (result.success) {
          if (result.result) {
            await addLog(result.result, 'success');
          }
          await AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText);
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
        if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
          DeviceUtils.showLoading(false);
        }
      }
    },

    // 一键配置所有设备可读写
    async mountAllDevices(
      devicesList: HTMLElement,
      readWriteDevicesList: HTMLElement,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): Promise<void> {
      // 获取所有只读设备和未挂载的设备
      const devices = AppModules.Devices.devices || [];
      const readOnlyDevices = devices.filter((d: any) => d.isReadOnly || d.isUnmounted);

      if (readOnlyDevices.length === 0) {
        await addLog(t('messages.noDevicesToMount'), 'info');
        return;
      }

      const deviceNames = readOnlyDevices.map((d: any) => d.volumeName).join('、');
      const title = t('devices.mountAll') + '？';
      const message = `将配置以下设备：\n${deviceNames}\n\n*注意：*\n* 配置后设备将支持读写，可以正常保存文件\n* 如果设备之前在 Windows 上使用过，可能需要先在 Windows 上完全关闭后再试`;

      const confirmed = await AppUtils.UI.showConfirm(title, message);
      if (!confirmed) {
        return;
      }

      const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;

      try {
        if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
          DeviceUtils.showLoading(true);
        }
        await addLog(t('messages.mountAllStart', { count: readOnlyDevices.length }), 'info');
        await addLog(t('messages.enterPassword'), 'info');

        let successCount = 0;
        let failCount = 0;

        // 逐个配置设备
        for (const device of readOnlyDevices) {
          try {
            await addLog(`正在配置 ${device.volumeName} 为可读写模式...`, 'info');
            const result = await electronAPI.mountDevice(device);

            if (result.success) {
              successCount++;
              if (result.result) {
                await addLog(result.result, 'success');
              }
            } else {
              failCount++;
              await addLog(`配置 ${device.volumeName} 失败: ${result.error || '未知错误'}`, 'error');
            }
          } catch (error) {
            failCount++;
            const errorMessage = error instanceof Error ? error.message : String(error);
            await addLog(`配置 ${device.volumeName} 失败: ${errorMessage}`, 'error');
          }
        }

        // 刷新设备列表（确保状态立即更新）
        await refreshDeviceList(devicesList);

        // 显示总结
        if (successCount > 0) {
          await addLog(t('messages.mountAllSuccess', { count: successCount }), 'success');
        }
        if (failCount > 0) {
          await addLog(t('messages.mountAllError', { count: failCount }), 'warning');
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        await addLog(`${t('messages.mountError')}: ${errorMessage}`, 'error');
      } finally {
        AppUtils.UI.showLoading(loadingOverlay, false);
      }
    },

    // 卸载所有NTFS设备
    async unmountAllDevices(
      devicesList: HTMLElement,
      readWriteDevicesList: HTMLElement,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): Promise<void> {
      // 获取所有已挂载的设备（排除已卸载的设备）
      const devices = AppModules.Devices.devices || [];
      const mountedDevices = devices.filter((d: any) => !d.isUnmounted);

      if (mountedDevices.length === 0) {
        await addLog(t('messages.noDevicesToUnmount') || '没有已挂载的设备', 'info');
        return;
      }

      const deviceNames = mountedDevices.map((d: any) => d.volumeName).join('、');
      const title = '确定要卸载所有已挂载的 NTFS 设备吗？';
      const message = `将卸载以下设备：\n${deviceNames}\n\n*注意：*\n* 卸载后设备将无法访问，需要重新挂载才能使用\n* 请确保没有程序正在使用这些设备`;

      const confirmed = await AppUtils.UI.showConfirm(title, message);
      if (!confirmed) {
        return;
      }

      const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;

      try {
        AppUtils.UI.showLoading(loadingOverlay, true);
        await addLog(`开始卸载 ${mountedDevices.length} 个设备...`, 'info');
        await addLog('提示：请在弹出的对话框中输入管理员密码', 'info');

        let successCount = 0;
        let failCount = 0;

        // 逐个卸载设备
        for (const device of mountedDevices) {
          try {
            await addLog(`正在卸载 ${device.volumeName}...`, 'info');
            const result = await electronAPI.unmountDevice(device);

            if (result.success) {
              successCount++;
              if (result.result) {
                await addLog(result.result, 'success');
              }
            } else {
              failCount++;
              await addLog(`卸载 ${device.volumeName} 失败: ${result.error || '未知错误'}`, 'error');
            }
          } catch (error) {
            failCount++;
            const errorMessage = error instanceof Error ? error.message : String(error);
            await addLog(`卸载 ${device.volumeName} 失败: ${errorMessage}`, 'error');
          }
        }

        // 刷新设备列表（确保状态立即更新）
        await refreshDeviceList(devicesList);

        // 显示总结
        if (successCount > 0) {
          await addLog(t('messages.unmountAllSuccess', { count: successCount }), 'success');
        }
        if (failCount > 0) {
          await addLog(t('messages.unmountAllError', { count: failCount }), 'warning');
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        await addLog(`${t('messages.unmountError')}: ${errorMessage}`, 'error');
      } finally {
        AppUtils.UI.showLoading(loadingOverlay, false);
      }
    },

    // 推出设备
    async ejectDevice(
      device: any, // eslint-disable-line @typescript-eslint/no-explicit-any
      devicesList: HTMLElement,
      readWriteDevicesList: HTMLElement,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): Promise<void> {
      const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;

      try {
        AppUtils.UI.showLoading(loadingOverlay, true);
        await addLog(`正在推出 ${device.volumeName}...`, 'info');

        const result = await electronAPI.ejectDevice(device);

        if (result.success) {
          if (result.result) {
            await addLog(result.result, 'success');
          }
          // 等待一小段时间，让系统完全断开设备
          await new Promise(resolve => setTimeout(resolve, 1000));
          await AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText);
        } else {
          await addLog(`推出失败: ${result.error || '未知错误'}`, 'error');
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        await addLog(`推出失败: ${errorMessage}`, 'error');
      } finally {
        AppUtils.UI.showLoading(loadingOverlay, false);
      }
    },

    // 推出所有设备
    async ejectAllDevices(
      devicesList: HTMLElement,
      readWriteDevicesList: HTMLElement,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): Promise<void> {
      // 获取所有已挂载的设备
      const devices = AppModules.Devices.devices || [];
      const mountedDevices = devices.filter((d: any) => !d.isUnmounted);

      // 获取翻译函数
      const t = AppUtils && AppUtils.I18n ? AppUtils.I18n.t : ((key: string, params?: Record<string, string | number>) => key);

      if (mountedDevices.length === 0) {
        await addLog(t('messages.noDevicesToUnmount') || '没有已挂载的设备', 'info');
        return;
      }

      const deviceNames = mountedDevices.map((d: any) => d.volumeName).join('、');
      const title = t('devices.ejectAllConfirm');
      const message = t('devices.ejectAllConfirmNote', { devices: deviceNames });

      const confirmed = await AppUtils.UI.showConfirm(title, message);
      if (!confirmed) {
        return;
      }

      const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;

      try {
        AppUtils.UI.showLoading(loadingOverlay, true);
        await addLog(t('messages.ejectAllStart', { count: mountedDevices.length }), 'info');

        let successCount = 0;
        let failCount = 0;

        // 逐个推出设备
        for (const device of mountedDevices) {
          try {
            await addLog(t('messages.ejecting', { name: device.volumeName }), 'info');
            const result = await electronAPI.ejectDevice(device);

            if (result.success) {
              successCount++;
              if (result.result) {
                await addLog(result.result, 'success');
              }
            } else {
              failCount++;
              await addLog(t('messages.ejectError', { name: device.volumeName }) + `: ${result.error || t('messages.unknownError') || '未知错误'}`, 'error');
            }
          } catch (error) {
            failCount++;
            const errorMessage = error instanceof Error ? error.message : String(error);
            await addLog(t('messages.ejectError', { name: device.volumeName }) + `: ${errorMessage}`, 'error');
          }
        }

        // 等待一小段时间，让系统完全断开设备
        await new Promise(resolve => setTimeout(resolve, 1000));

        // 刷新设备列表（确保状态立即更新）
        await refreshDeviceList(devicesList);

        // 显示总结
        if (successCount > 0) {
          await addLog(t('messages.ejectAllSuccess', { count: successCount }), 'success');
        }
        if (failCount > 0) {
          await addLog(t('messages.ejectAllError', { count: failCount }), 'warning');
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        await addLog(`${t('messages.ejectAllError', { count: 0 })}: ${errorMessage}`, 'error');
      } finally {
        AppUtils.UI.showLoading(loadingOverlay, false);
      }
    }
  };

})();
