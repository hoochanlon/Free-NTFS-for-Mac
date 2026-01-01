// 设备管理模块
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

  // 设备管理
  AppModules.Devices = {
    // 设备数据
    devices: [] as any[],
    lastDeviceCount: 0,
    lastDeviceState: '',

    // 刷新设备列表
    async refreshDevices(
      devicesList: HTMLElement,
      readWriteDevicesList: HTMLElement,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): Promise<void> {
      try {
        AppModules.Devices.devices = await electronAPI.getNTFSDevices();
        AppModules.Devices.renderDevices(devicesList, readWriteDevicesList);

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

    // 渲染设备列表
    renderDevices(devicesList: HTMLElement, readWriteDevicesList: HTMLElement): void {
      if (AppModules.Devices.devices.length === 0) {
        devicesList.innerHTML = `
          <div class="empty-state">
            <div class="empty-icon"></div>
            <p>未检测到 NTFS 设备</p>
            <p class="empty-hint">请插入 NTFS 格式的移动存储设备</p>
          </div>
        `;
        AppModules.Devices.renderReadWriteDevices(readWriteDevicesList);
        return;
      }

      devicesList.innerHTML = '';

      AppModules.Devices.devices.forEach((device: any) => {
        const item = document.createElement('div');
        item.className = 'device-item';

        const statusClass = device.isReadOnly ? 'read-only' : 'read-write';
        const statusText = device.isReadOnly ? '只读' : '读写';

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
              <span class="device-info-label">设备:</span>
              <span>${device.devicePath}</span>
            </div>
            <div class="device-info-item">
              <span class="device-info-label">挂载点:</span>
              <span>${device.volume}</span>
            </div>
          </div>
          <div class="device-actions">
            ${device.isReadOnly ? `
              <button class="btn btn-success mount-btn" data-disk="${device.disk}">
                挂载为读写
              </button>
            ` : `
              <button class="btn btn-danger unmount-btn" data-disk="${device.disk}">
                卸载
              </button>
            `}
          </div>
        `;

        devicesList.appendChild(item);
      });

      // 绑定按钮事件
      devicesList.querySelectorAll('.mount-btn').forEach(btn => {
        btn.addEventListener('click', () => {
          const disk = (btn as HTMLElement).dataset.disk;
          const device = AppModules.Devices.devices.find((d: any) => d.disk === disk);
          if (device) {
            const statusDot = document.querySelector('.status-dot') as HTMLElement;
            const statusText = document.querySelector('.status-text') as HTMLElement;
            AppModules.Devices.mountDevice(
              device,
              devicesList,
              readWriteDevicesList,
              statusDot,
              statusText
            );
          }
        });
      });

      devicesList.querySelectorAll('.unmount-btn').forEach(btn => {
        btn.addEventListener('click', () => {
          const disk = (btn as HTMLElement).dataset.disk;
          const device = AppModules.Devices.devices.find((d: any) => d.disk === disk);
          if (device) {
            const statusDot = document.querySelector('.status-dot') as HTMLElement;
            const statusText = document.querySelector('.status-text') as HTMLElement;
            AppModules.Devices.unmountDevice(
              device,
              devicesList,
              readWriteDevicesList,
              statusDot,
              statusText
            );
          }
        });
      });

      // 渲染已可读写的设备列表
      AppModules.Devices.renderReadWriteDevices(readWriteDevicesList);
    },

    // 渲染已可读写的设备列表
    renderReadWriteDevices(readWriteDevicesList: HTMLElement): void {
      const readWriteDevices = AppModules.Devices.devices.filter(
        (device: any) => device.isMounted && !device.isReadOnly
      );

      if (readWriteDevices.length === 0) {
        readWriteDevicesList.innerHTML = `
          <div class="empty-state">
            <div class="empty-icon"></div>
            <p>暂无已可读写的设备</p>
            <p class="empty-hint">已挂载为读写模式的设备将显示在这里</p>
          </div>
        `;
        return;
      }

      readWriteDevicesList.innerHTML = '';

      readWriteDevices.forEach((device: any) => {
        const item = document.createElement('div');
        item.className = 'device-item read-write-device';

        item.innerHTML = `
          <div class="device-header">
            <div class="device-name">
              <span class="device-icon"></span>
              ${device.volumeName}
            </div>
            <span class="device-status read-write">读写</span>
          </div>
          <div class="device-info">
            <div class="device-info-item">
              <span class="device-info-label">设备:</span>
              <span>${device.devicePath}</span>
            </div>
            <div class="device-info-item">
              <span class="device-info-label">挂载点:</span>
              <span>${device.volume}</span>
            </div>
          </div>
          <div class="device-actions">
            <button class="btn btn-danger unmount-btn" data-disk="${device.disk}">
              卸载
            </button>
          </div>
        `;

        readWriteDevicesList.appendChild(item);
      });

      // 绑定卸载按钮事件
      readWriteDevicesList.querySelectorAll('.unmount-btn').forEach(btn => {
        btn.addEventListener('click', () => {
          const disk = (btn as HTMLElement).dataset.disk;
          const device = AppModules.Devices.devices.find((d: any) => d.disk === disk);
          if (device) {
            AppModules.Devices.unmountDevice(
              device,
              document.getElementById('devicesList')!,
              readWriteDevicesList,
              document.querySelector('.status-dot') as HTMLElement,
              document.querySelector('.status-text') as HTMLElement
            );
          }
        });
      });
    },

    // 挂载设备
    async mountDevice(
      device: any, // eslint-disable-line @typescript-eslint/no-explicit-any
      devicesList: HTMLElement,
      readWriteDevicesList: HTMLElement,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): Promise<void> {
      const message = `确定要将 ${device.volumeName} 挂载为读写模式吗？\n\n` +
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
    }
  };

})();
