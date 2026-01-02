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
      const message = `确定要将 ${device.volumeName} 配置为可读写模式吗？\n\n` +
                      `注意：\n` +
                      `• 这需要管理员权限，系统会弹出密码输入对话框\n` +
                      `• 如果设备在 Windows 中使用了快速启动，可能需要先在 Windows 中完全关闭设备`;

      if (!confirm(message)) {
        return;
      }

      const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;

      try {
        AppUtils.UI.showLoading(loadingOverlay, true);
        AppUtils.Logs.addLog(`正在挂载 ${device.volumeName}...`, 'info');
        AppUtils.Logs.addLog('提示：请在弹出的对话框中输入管理员密码', 'info');

        const result = await electronAPI.mountDevice(device);

        if (result.success) {
          if (result.result) {
            AppUtils.Logs.addLog(result.result, 'success');
          }
          // 等待一小段时间，确保挂载操作完全完成，标记文件已创建
          await new Promise(resolve => setTimeout(resolve, 500));
          await AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText);
        } else {
          AppUtils.Logs.addLog(`挂载失败: ${result.error || '未知错误'}`, 'error');
          if (result.error?.includes('密码错误')) {
            AppUtils.Logs.addLog('提示：密码错误，请重试', 'warning');
          } else if (result.error?.includes('用户取消')) {
            AppUtils.Logs.addLog('提示：已取消操作', 'info');
          }
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        AppUtils.Logs.addLog(`挂载失败: ${errorMessage}`, 'error');
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
      const message = `确定要将 ${device.volumeName} 还原为只读模式吗？\n\n` +
                      `注意：这需要管理员权限，系统会弹出密码输入对话框`;

      if (!confirm(message)) {
        return;
      }

      const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;

      try {
        AppUtils.UI.showLoading(loadingOverlay, true);
        AppUtils.Logs.addLog(`正在还原 ${device.volumeName} 为只读模式...`, 'info');
        AppUtils.Logs.addLog('提示：请在弹出的对话框中输入管理员密码', 'info');

        const result = await electronAPI.restoreToReadOnly(device);

        if (result.success) {
          if (result.result) {
            AppUtils.Logs.addLog(result.result, 'success');
          }
          // 等待一小段时间，让系统重新挂载
          await new Promise(resolve => setTimeout(resolve, 1500));
          await AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText);
        } else {
          AppUtils.Logs.addLog(`还原失败: ${result.error || '未知错误'}`, 'error');
          if (result.error?.includes('密码错误')) {
            AppUtils.Logs.addLog('提示：密码错误，请重试', 'warning');
          } else if (result.error?.includes('用户取消')) {
            AppUtils.Logs.addLog('提示：已取消操作', 'info');
          }
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        AppUtils.Logs.addLog(`还原失败: ${errorMessage}`, 'error');
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
        AppUtils.Logs.addLog('没有已挂载为读写模式的设备', 'info');
        return;
      }

      const deviceNames = readWriteDevices.map((d: any) => d.volumeName).join('、');
      const message = `确定要将所有已挂载的 NTFS 设备还原为只读模式吗？\n\n` +
                      `将还原以下设备：\n${deviceNames}\n\n` +
                      `注意：这需要管理员权限，系统会弹出密码输入对话框`;

      if (!confirm(message)) {
        return;
      }

      const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;

      try {
        AppUtils.UI.showLoading(loadingOverlay, true);
        AppUtils.Logs.addLog(`开始还原 ${readWriteDevices.length} 个设备为只读模式...`, 'info');
        AppUtils.Logs.addLog('提示：请在弹出的对话框中输入管理员密码', 'info');

        let successCount = 0;
        let failCount = 0;

        // 逐个还原设备
        for (const device of readWriteDevices) {
          try {
            AppUtils.Logs.addLog(`正在还原 ${device.volumeName} 为只读模式...`, 'info');
            const result = await electronAPI.restoreToReadOnly(device);

            if (result.success) {
              successCount++;
              if (result.result) {
                AppUtils.Logs.addLog(result.result, 'success');
              }
            } else {
              failCount++;
              AppUtils.Logs.addLog(`还原 ${device.volumeName} 失败: ${result.error || '未知错误'}`, 'error');
            }
          } catch (error) {
            failCount++;
            const errorMessage = error instanceof Error ? error.message : String(error);
            AppUtils.Logs.addLog(`还原 ${device.volumeName} 失败: ${errorMessage}`, 'error');
          }
        }

        // 等待一小段时间，让系统重新挂载
        await new Promise(resolve => setTimeout(resolve, 1500));

        // 刷新设备列表
        await AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText);

        // 显示总结
        if (successCount > 0) {
          AppUtils.Logs.addLog(`成功还原 ${successCount} 个设备为只读模式`, 'success');
        }
        if (failCount > 0) {
          AppUtils.Logs.addLog(`失败 ${failCount} 个设备`, 'warning');
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        AppUtils.Logs.addLog(`还原所有设备失败: ${errorMessage}`, 'error');
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
      const message = `确定要卸载 ${device.volumeName} 吗？\n\n` +
                      `注意：这需要管理员权限，系统会弹出密码输入对话框`;

      if (!confirm(message)) {
        return;
      }

      const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;

      try {
        AppUtils.UI.showLoading(loadingOverlay, true);
        AppUtils.Logs.addLog(`正在卸载 ${device.volumeName}...`, 'info');
        AppUtils.Logs.addLog('提示：请在弹出的对话框中输入管理员密码', 'info');

        const result = await electronAPI.unmountDevice(device);

        if (result.success) {
          if (result.result) {
            AppUtils.Logs.addLog(result.result, 'success');
          }
          await AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText);
        } else {
          AppUtils.Logs.addLog(`卸载失败: ${result.error || '未知错误'}`, 'error');
          if (result.error?.includes('密码错误')) {
            AppUtils.Logs.addLog('提示：密码错误，请重试', 'warning');
          } else if (result.error?.includes('用户取消')) {
            AppUtils.Logs.addLog('提示：已取消操作', 'info');
          }
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        AppUtils.Logs.addLog(`卸载失败: ${errorMessage}`, 'error');
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
      // 获取所有已挂载为读写模式的设备
      const devices = AppModules.Devices.devices || [];
      const readWriteDevices = devices.filter((d: any) => !d.isReadOnly);

      if (readWriteDevices.length === 0) {
        AppUtils.Logs.addLog('没有已挂载为读写模式的设备', 'info');
        return;
      }

      const deviceNames = readWriteDevices.map((d: any) => d.volumeName).join('、');
      const message = `确定要卸载所有已挂载的 NTFS 设备吗？\n\n` +
                      `将卸载以下设备：\n${deviceNames}\n\n` +
                      `注意：这需要管理员权限，系统会弹出密码输入对话框`;

      if (!confirm(message)) {
        return;
      }

      const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;

      try {
        AppUtils.UI.showLoading(loadingOverlay, true);
        AppUtils.Logs.addLog(`开始卸载 ${readWriteDevices.length} 个设备...`, 'info');
        AppUtils.Logs.addLog('提示：请在弹出的对话框中输入管理员密码', 'info');

        let successCount = 0;
        let failCount = 0;

        // 逐个卸载设备
        for (const device of readWriteDevices) {
          try {
            AppUtils.Logs.addLog(`正在卸载 ${device.volumeName}...`, 'info');
            const result = await electronAPI.unmountDevice(device);

            if (result.success) {
              successCount++;
              if (result.result) {
                AppUtils.Logs.addLog(result.result, 'success');
              }
            } else {
              failCount++;
              AppUtils.Logs.addLog(`卸载 ${device.volumeName} 失败: ${result.error || '未知错误'}`, 'error');
            }
          } catch (error) {
            failCount++;
            const errorMessage = error instanceof Error ? error.message : String(error);
            AppUtils.Logs.addLog(`卸载 ${device.volumeName} 失败: ${errorMessage}`, 'error');
          }
        }

        // 刷新设备列表
        await AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText);

        // 显示总结
        if (successCount > 0) {
          AppUtils.Logs.addLog(`成功卸载 ${successCount} 个设备`, 'success');
        }
        if (failCount > 0) {
          AppUtils.Logs.addLog(`失败 ${failCount} 个设备`, 'warning');
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        AppUtils.Logs.addLog(`卸载所有设备失败: ${errorMessage}`, 'error');
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
      const message = `确定要推出 ${device.volumeName} 吗？\n\n` +
                      `注意：\n` +
                      `• 推出后设备将从系统中完全断开\n` +
                      `• 设备将从列表中移除，需要重新插入才能使用\n` +
                      `• 请确保没有程序正在使用该设备`;

      if (!confirm(message)) {
        return;
      }

      const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;

      try {
        AppUtils.UI.showLoading(loadingOverlay, true);
        AppUtils.Logs.addLog(`正在推出 ${device.volumeName}...`, 'info');

        const result = await electronAPI.ejectDevice(device);

        if (result.success) {
          if (result.result) {
            AppUtils.Logs.addLog(result.result, 'success');
          }
          // 等待一小段时间，让系统完全断开设备
          await new Promise(resolve => setTimeout(resolve, 1000));
          await AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText);
        } else {
          AppUtils.Logs.addLog(`推出失败: ${result.error || '未知错误'}`, 'error');
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        AppUtils.Logs.addLog(`推出失败: ${errorMessage}`, 'error');
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

      if (mountedDevices.length === 0) {
        AppUtils.Logs.addLog('没有已挂载的设备', 'info');
        return;
      }

      const deviceNames = mountedDevices.map((d: any) => d.volumeName).join('、');
      const message = `确定要推出所有 NTFS 设备吗？\n\n` +
                      `将推出以下设备：\n${deviceNames}\n\n` +
                      `注意：\n` +
                      `• 推出后设备将从系统中完全断开\n` +
                      `• 设备将从列表中移除，需要重新插入才能使用\n` +
                      `• 请确保没有程序正在使用这些设备`;

      if (!confirm(message)) {
        return;
      }

      const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;

      try {
        AppUtils.UI.showLoading(loadingOverlay, true);
        AppUtils.Logs.addLog(`开始推出 ${mountedDevices.length} 个设备...`, 'info');

        let successCount = 0;
        let failCount = 0;

        // 逐个推出设备
        for (const device of mountedDevices) {
          try {
            AppUtils.Logs.addLog(`正在推出 ${device.volumeName}...`, 'info');
            const result = await electronAPI.ejectDevice(device);

            if (result.success) {
              successCount++;
              if (result.result) {
                AppUtils.Logs.addLog(result.result, 'success');
              }
            } else {
              failCount++;
              AppUtils.Logs.addLog(`推出 ${device.volumeName} 失败: ${result.error || '未知错误'}`, 'error');
            }
          } catch (error) {
            failCount++;
            const errorMessage = error instanceof Error ? error.message : String(error);
            AppUtils.Logs.addLog(`推出 ${device.volumeName} 失败: ${errorMessage}`, 'error');
          }
        }

        // 等待一小段时间，让系统完全断开设备
        await new Promise(resolve => setTimeout(resolve, 1000));

        // 刷新设备列表
        await AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText);

        // 显示总结
        if (successCount > 0) {
          AppUtils.Logs.addLog(`成功推出 ${successCount} 个设备`, 'success');
        }
        if (failCount > 0) {
          AppUtils.Logs.addLog(`失败 ${failCount} 个设备`, 'warning');
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        AppUtils.Logs.addLog(`推出所有设备失败: ${errorMessage}`, 'error');
      } finally {
        AppUtils.UI.showLoading(loadingOverlay, false);
      }
    }
  };

})();
