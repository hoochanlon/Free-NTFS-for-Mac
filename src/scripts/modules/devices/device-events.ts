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
