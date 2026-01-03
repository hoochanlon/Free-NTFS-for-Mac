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

  // 获取翻译文本的辅助函数
  function t(key: string, params?: Record<string, string | number>): string {
    if (AppUtils && AppUtils.I18n) {
      return AppUtils.I18n.t(key, params);
    }
    return key; // 如果 i18n 未初始化，返回 key
  }

  // 初始化命名空间
  if (!AppModules.Devices) {
    AppModules.Devices = {};
  }
  if (!AppModules.Devices.Operations) {
    AppModules.Devices.Operations = {};
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
        AppUtils.UI.showLoading(loadingOverlay, true);
        await await AppUtils.Logs.addLog(t('messages.mounting', { name: device.volumeName }), 'info');
        await await AppUtils.Logs.addLog(t('messages.enterPassword'), 'info');

        const result = await electronAPI.mountDevice(device);

        if (result.success) {
          if (result.result) {
            await await AppUtils.Logs.addLog(result.result, 'success');
          }
          // 等待一小段时间，确保挂载操作完全完成，标记文件已创建
          await new Promise(resolve => setTimeout(resolve, 500));
          await AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText);
        } else {
          await await AppUtils.Logs.addLog(`${t('messages.mountError')}: ${result.error || t('messages.mountError')}`, 'error');
          if (result.error?.includes('密码错误') || result.error?.includes('password')) {
            await await AppUtils.Logs.addLog(t('messages.passwordError'), 'warning');
          } else if (result.error?.includes('用户取消') || result.error?.includes('cancelled')) {
            await await AppUtils.Logs.addLog(t('messages.cancelled'), 'info');
          }
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        await await AppUtils.Logs.addLog(`${t('messages.mountError')}: ${errorMessage}`, 'error');
      } finally {
        AppUtils.UI.showLoading(loadingOverlay, false);
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
        AppUtils.UI.showLoading(loadingOverlay, true);
        await AppUtils.Logs.addLog(t('messages.restoring', { name: device.volumeName }), 'info');
        await AppUtils.Logs.addLog(t('messages.enterPassword'), 'info');

        const result = await electronAPI.restoreToReadOnly(device);

        if (result.success) {
          if (result.result) {
            await await AppUtils.Logs.addLog(result.result, 'success');
          }
          // 等待一小段时间，让系统重新挂载
          await new Promise(resolve => setTimeout(resolve, 1500));
          await AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText);
        } else {
          await AppUtils.Logs.addLog(`${t('messages.restoreError')}: ${result.error || t('messages.restoreError')}`, 'error');
          if (result.error?.includes('密码错误') || result.error?.includes('password')) {
            await AppUtils.Logs.addLog(t('messages.passwordError'), 'warning');
          } else if (result.error?.includes('用户取消') || result.error?.includes('cancelled')) {
            await AppUtils.Logs.addLog(t('messages.cancelled'), 'info');
          }
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        await AppUtils.Logs.addLog(`${t('messages.restoreError')}: ${errorMessage}`, 'error');
      } finally {
        AppUtils.UI.showLoading(loadingOverlay, false);
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
        await AppUtils.Logs.addLog(t('messages.noDevicesToUnmount'), 'info');
        return;
      }

      const deviceNames = readWriteDevices.map((d: any) => d.volumeName).join('、');
      const title = t('devices.restoreAllReadOnly') + '？';
      const message = `将还原以下设备：\n${deviceNames}\n\n*注意：*\n* 设备将恢复为只读模式，无法写入文件\n* 已写入的文件不会丢失，但后续只能读取`;

      const confirmed = await AppUtils.UI.showConfirm(title, message);
      if (!confirmed) {
        return;
      }

      const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;

      try {
        AppUtils.UI.showLoading(loadingOverlay, true);
        await AppUtils.Logs.addLog(t('messages.restoreAllStart', { count: readWriteDevices.length }), 'info');
        await AppUtils.Logs.addLog(t('messages.enterPassword'), 'info');

        let successCount = 0;
        let failCount = 0;

        // 逐个还原设备
        for (const device of readWriteDevices) {
          try {
            await AppUtils.Logs.addLog(`正在还原 ${device.volumeName} 为只读模式...`, 'info');
            const result = await electronAPI.restoreToReadOnly(device);

            if (result.success) {
              successCount++;
              if (result.result) {
                await AppUtils.Logs.addLog(result.result, 'success');
              }
            } else {
              failCount++;
              await AppUtils.Logs.addLog(`还原 ${device.volumeName} 失败: ${result.error || '未知错误'}`, 'error');
            }
          } catch (error) {
            failCount++;
            const errorMessage = error instanceof Error ? error.message : String(error);
            await AppUtils.Logs.addLog(`还原 ${device.volumeName} 失败: ${errorMessage}`, 'error');
          }
        }

        // 等待一小段时间，让系统重新挂载
        await new Promise(resolve => setTimeout(resolve, 1500));

        // 刷新设备列表
        await AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText);

        // 显示总结
        if (successCount > 0) {
          await AppUtils.Logs.addLog(t('messages.restoreAllSuccess', { count: successCount }), 'success');
        }
        if (failCount > 0) {
          await AppUtils.Logs.addLog(t('messages.restoreAllError', { count: failCount }), 'warning');
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        await AppUtils.Logs.addLog(`${t('messages.restoreError')}: ${errorMessage}`, 'error');
      } finally {
        AppUtils.UI.showLoading(loadingOverlay, false);
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
        AppUtils.UI.showLoading(loadingOverlay, true);
        await AppUtils.Logs.addLog(t('messages.unmounting', { name: device.volumeName }), 'info');
        await AppUtils.Logs.addLog('提示：请在弹出的对话框中输入管理员密码', 'info');

        const result = await electronAPI.unmountDevice(device);

        if (result.success) {
          if (result.result) {
            await await AppUtils.Logs.addLog(result.result, 'success');
          }
          await AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText);
        } else {
          await AppUtils.Logs.addLog(`卸载失败: ${result.error || '未知错误'}`, 'error');
          if (result.error?.includes('密码错误')) {
            await AppUtils.Logs.addLog('提示：密码错误，请重试', 'warning');
          } else if (result.error?.includes('用户取消')) {
            await AppUtils.Logs.addLog('提示：已取消操作', 'info');
          }
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        await AppUtils.Logs.addLog(`卸载失败: ${errorMessage}`, 'error');
      } finally {
        AppUtils.UI.showLoading(loadingOverlay, false);
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
        await AppUtils.Logs.addLog(t('messages.noDevicesToMount'), 'info');
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
        AppUtils.UI.showLoading(loadingOverlay, true);
        await AppUtils.Logs.addLog(t('messages.mountAllStart', { count: readOnlyDevices.length }), 'info');
        await AppUtils.Logs.addLog(t('messages.enterPassword'), 'info');

        let successCount = 0;
        let failCount = 0;

        // 逐个配置设备
        for (const device of readOnlyDevices) {
          try {
            await AppUtils.Logs.addLog(`正在配置 ${device.volumeName} 为可读写模式...`, 'info');
            const result = await electronAPI.mountDevice(device);

            if (result.success) {
              successCount++;
              if (result.result) {
                await AppUtils.Logs.addLog(result.result, 'success');
              }
            } else {
              failCount++;
              await AppUtils.Logs.addLog(`配置 ${device.volumeName} 失败: ${result.error || '未知错误'}`, 'error');
            }
          } catch (error) {
            failCount++;
            const errorMessage = error instanceof Error ? error.message : String(error);
            await AppUtils.Logs.addLog(`配置 ${device.volumeName} 失败: ${errorMessage}`, 'error');
          }
        }

        // 刷新设备列表
        await AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText);

        // 显示总结
        if (successCount > 0) {
          await AppUtils.Logs.addLog(t('messages.mountAllSuccess', { count: successCount }), 'success');
        }
        if (failCount > 0) {
          await AppUtils.Logs.addLog(t('messages.mountAllError', { count: failCount }), 'warning');
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        await AppUtils.Logs.addLog(`${t('messages.mountError')}: ${errorMessage}`, 'error');
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
        await AppUtils.Logs.addLog(t('messages.noDevicesToUnmount') || '没有已挂载的设备', 'info');
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
        await AppUtils.Logs.addLog(`开始卸载 ${mountedDevices.length} 个设备...`, 'info');
        await AppUtils.Logs.addLog('提示：请在弹出的对话框中输入管理员密码', 'info');

        let successCount = 0;
        let failCount = 0;

        // 逐个卸载设备
        for (const device of mountedDevices) {
          try {
            await AppUtils.Logs.addLog(`正在卸载 ${device.volumeName}...`, 'info');
            const result = await electronAPI.unmountDevice(device);

            if (result.success) {
              successCount++;
              if (result.result) {
                await AppUtils.Logs.addLog(result.result, 'success');
              }
            } else {
              failCount++;
              await AppUtils.Logs.addLog(`卸载 ${device.volumeName} 失败: ${result.error || '未知错误'}`, 'error');
            }
          } catch (error) {
            failCount++;
            const errorMessage = error instanceof Error ? error.message : String(error);
            await AppUtils.Logs.addLog(`卸载 ${device.volumeName} 失败: ${errorMessage}`, 'error');
          }
        }

        // 刷新设备列表
        await AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText);

        // 显示总结
        if (successCount > 0) {
          await AppUtils.Logs.addLog(t('messages.unmountAllSuccess', { count: successCount }), 'success');
        }
        if (failCount > 0) {
          await AppUtils.Logs.addLog(t('messages.unmountAllError', { count: failCount }), 'warning');
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        await AppUtils.Logs.addLog(`${t('messages.unmountError')}: ${errorMessage}`, 'error');
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
        await AppUtils.Logs.addLog(`正在推出 ${device.volumeName}...`, 'info');

        const result = await electronAPI.ejectDevice(device);

        if (result.success) {
          if (result.result) {
            await await AppUtils.Logs.addLog(result.result, 'success');
          }
          // 等待一小段时间，让系统完全断开设备
          await new Promise(resolve => setTimeout(resolve, 1000));
          await AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText);
        } else {
          await AppUtils.Logs.addLog(`推出失败: ${result.error || '未知错误'}`, 'error');
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        await AppUtils.Logs.addLog(`推出失败: ${errorMessage}`, 'error');
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
        await AppUtils.Logs.addLog(t('messages.noDevicesToUnmount') || '没有已挂载的设备', 'info');
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
        await AppUtils.Logs.addLog(t('messages.ejectAllStart', { count: mountedDevices.length }), 'info');

        let successCount = 0;
        let failCount = 0;

        // 逐个推出设备
        for (const device of mountedDevices) {
          try {
            await AppUtils.Logs.addLog(t('messages.ejecting', { name: device.volumeName }), 'info');
            const result = await electronAPI.ejectDevice(device);

            if (result.success) {
              successCount++;
              if (result.result) {
                await AppUtils.Logs.addLog(result.result, 'success');
              }
            } else {
              failCount++;
              await AppUtils.Logs.addLog(t('messages.ejectError', { name: device.volumeName }) + `: ${result.error || t('messages.unknownError') || '未知错误'}`, 'error');
            }
          } catch (error) {
            failCount++;
            const errorMessage = error instanceof Error ? error.message : String(error);
            await AppUtils.Logs.addLog(t('messages.ejectError', { name: device.volumeName }) + `: ${errorMessage}`, 'error');
          }
        }

        // 等待一小段时间，让系统完全断开设备
        await new Promise(resolve => setTimeout(resolve, 1000));

        // 刷新设备列表
        await AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText);

        // 显示总结
        if (successCount > 0) {
          await AppUtils.Logs.addLog(t('messages.ejectAllSuccess', { count: successCount }), 'success');
        }
        if (failCount > 0) {
          await AppUtils.Logs.addLog(t('messages.ejectAllError', { count: failCount }), 'warning');
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        await AppUtils.Logs.addLog(`${t('messages.ejectAllError', { count: 0 })}: ${errorMessage}`, 'error');
      } finally {
        AppUtils.UI.showLoading(loadingOverlay, false);
      }
    }
  };

})();
