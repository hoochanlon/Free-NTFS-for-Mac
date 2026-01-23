// 设备事件绑定模块
// 注意：不使用 import，避免生成 CommonJS 代码（浏览器环境不支持）

(function() {
  'use strict';

  // 创建全局命名空间
  if (typeof (window as any).AppModules === 'undefined') {
    (window as any).AppModules = {};
  }

  const AppModules = (window as any).AppModules;

  // 初始化命名空间
  if (!AppModules.Devices) {
    AppModules.Devices = {};
  }
  if (!AppModules.Devices.Events) {
    AppModules.Devices.Events = {};
  }

  // 设备事件绑定功能
  AppModules.Devices.Events = {
    // 绑定设备事件
    bindDeviceEvents(devicesList: HTMLElement, readWriteDevicesList: HTMLElement): void {
      // 双击设备项：在 Finder 打开挂载点（主窗口 & 托盘窗口通用）
      // - 只对已挂载（非 unmounted）且有 volume 路径的设备生效
      // - 双击按钮不触发（避免误操作）
      devicesList.querySelectorAll('.device-item').forEach(item => {
        item.addEventListener('dblclick', async (ev: Event) => {
          try {
            const target = ev.target as HTMLElement | null;
            if (target && target.closest('button')) return;

            const disk = (item as HTMLElement).dataset.disk;
            const devices = AppModules.Devices.devices || [];
            const device = devices.find((d: any) => d.disk === disk);
            if (!device) return;
            if (device.isUnmounted) return;

            const volumePath = device.volume; // e.g. /Volumes/MyDisk
            if (volumePath && typeof volumePath === 'string') {
              const electronAPI = (window as any).electronAPI;
              if (electronAPI && typeof electronAPI.openPath === 'function') {
                await electronAPI.openPath(volumePath);
              }
            }
          } catch (error) {
            // 降级：不影响其他交互
            console.warn('[设备事件] 双击打开失败:', error);
          }
        });
      });

      devicesList.querySelectorAll('.mount-btn').forEach(btn => {
        btn.addEventListener('click', () => {
          const disk = (btn as HTMLElement).dataset.disk;
          const device = AppModules.Devices.devices.find((d: any) => d.disk === disk);
          if (device) {
            const statusDot = document.querySelector('.status-dot') as HTMLElement;
            const statusText = document.querySelector('.status-text') as HTMLElement;
            AppModules.Devices.Operations.mountDevice(
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
          const devices = AppModules.Devices.devices || [];
          const device = devices.find((d: any) => d.disk === disk);
          if (device) {
            const statusDot = document.querySelector('.status-dot') as HTMLElement;
            const statusText = document.querySelector('.status-text') as HTMLElement;
            AppModules.Devices.Operations.unmountDevice(
              device,
              devicesList,
              readWriteDevicesList,
              statusDot,
              statusText
            );
          }
        });
      });

      devicesList.querySelectorAll('.restore-readonly-btn').forEach(btn => {
        btn.addEventListener('click', () => {
          const disk = (btn as HTMLElement).dataset.disk;
          const devices = AppModules.Devices.devices || [];
          const device = devices.find((d: any) => d.disk === disk);
          if (device) {
            const statusDot = document.querySelector('.status-dot') as HTMLElement;
            const statusText = document.querySelector('.status-text') as HTMLElement;
            AppModules.Devices.Operations.restoreToReadOnly(
              device,
              devicesList,
              readWriteDevicesList,
              statusDot,
              statusText
            );
          }
        });
      });

      devicesList.querySelectorAll('.reset-btn').forEach(btn => {
        btn.addEventListener('click', () => {
          const disk = (btn as HTMLElement).dataset.disk;
          const devices = AppModules.Devices.devices || [];
          const device = devices.find((d: any) => d.disk === disk);
          if (device) {
            const statusDot = document.querySelector('.status-dot') as HTMLElement;
            const statusText = document.querySelector('.status-text') as HTMLElement;
            AppModules.Devices.Operations.resetDevice(
              device,
              devicesList,
              readWriteDevicesList,
              statusDot,
              statusText
            );
          }
        });
      });

      devicesList.querySelectorAll('.eject-btn').forEach(btn => {
        btn.addEventListener('click', () => {
          const disk = (btn as HTMLElement).dataset.disk;
          const devices = AppModules.Devices.devices || [];
          const device = devices.find((d: any) => d.disk === disk);
          if (device) {
            const statusDot = document.querySelector('.status-dot') as HTMLElement;
            const statusText = document.querySelector('.status-text') as HTMLElement;
            AppModules.Devices.Operations.ejectDevice(
              device,
              devicesList,
              readWriteDevicesList,
              statusDot,
              statusText
            );
          }
        });
      });
    }
  };

})();
