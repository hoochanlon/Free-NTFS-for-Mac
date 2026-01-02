// 设备渲染模块
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
  if (!AppModules.Devices.Renderer) {
    AppModules.Devices.Renderer = {};
  }

  // 获取翻译文本的辅助函数
  function t(key: string, params?: Record<string, string | number>): string {
    if ((window as any).AppUtils && (window as any).AppUtils.I18n) {
      return (window as any).AppUtils.I18n.t(key, params);
    }
    return key; // 如果 i18n 未初始化，返回 key
  }

  // 设备渲染功能
  AppModules.Devices.Renderer = {
    // 上次渲染的设备列表（用于比较）
    lastRenderedDevices: [] as any[],

    // 渲染设备列表
    renderDevices(devicesList: HTMLElement, readWriteDevicesList: HTMLElement): void {
      const devices = AppModules.Devices.devices || [];

      // 生成设备标识字符串用于比较
      const currentDeviceKey = devices.map((d: any) => `${d.disk}:${d.isReadOnly}:${d.isUnmounted || false}`).join('|');
      const lastDeviceKey = AppModules.Devices.Renderer.lastRenderedDevices.map((d: any) => `${d.disk}:${d.isReadOnly}:${d.isUnmounted || false}`).join('|');

      // 如果设备列表没有变化，跳过重新渲染
      if (currentDeviceKey === lastDeviceKey && devices.length > 0) {
        return;
      }

      // 更新上次渲染的设备列表
      AppModules.Devices.Renderer.lastRenderedDevices = devices.map((d: any) => ({ ...d }));

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

      // 按状态分组：先显示只读设备，再显示读写设备
      const readOnlyDevices = devices.filter((device: any) => device.isReadOnly);
      const readWriteDevices = devices.filter((device: any) => !device.isReadOnly);

      // 渲染只读设备
      if (readOnlyDevices.length > 0) {
        readOnlyDevices.forEach((device: any) => {
          const item = AppModules.Devices.Renderer.createDeviceItem(device);
          devicesList.appendChild(item);
        });
      }

      // 渲染读写设备
      if (readWriteDevices.length > 0) {
        readWriteDevices.forEach((device: any) => {
          const item = AppModules.Devices.Renderer.createDeviceItem(device);
          devicesList.appendChild(item);
        });
      }

      // 绑定按钮事件
      AppModules.Devices.Events.bindDeviceEvents(devicesList, readWriteDevicesList);
    },

    // 创建设备项
    createDeviceItem(device: any): HTMLElement {
      const item = document.createElement('div');
      item.className = 'device-item';
      if (!device.isReadOnly && !device.isUnmounted) {
        item.classList.add('read-write-device');
      }
      if (device.isUnmounted) {
        item.classList.add('unmounted-device');
      }

      const statusClass = device.isUnmounted ? 'unmounted' : (device.isReadOnly ? 'read-only' : 'read-write');
      const statusText = device.isUnmounted ? t('devices.unmounted') : (device.isReadOnly ? t('devices.readOnly') : t('devices.readWrite'));

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
            <span class="device-info-label">${t('devices.deviceLabel')}</span>
            <span>${device.devicePath}</span>
          </div>
          <div class="device-info-item">
            <span class="device-info-label">${t('devices.mountPointLabel')}</span>
            <span>${device.isUnmounted ? t('devices.notMounted') : device.volume}</span>
          </div>
        </div>
        <div class="device-actions">
          ${device.isUnmounted ? `
            <button class="btn btn-success mount-btn" data-disk="${device.disk}">
              ${t('devices.remount')}
            </button>
            <button class="btn btn-danger eject-btn" data-disk="${device.disk}">
              ${t('devices.eject')}
            </button>
          ` : device.isReadOnly ? `
            <button class="btn btn-success mount-btn" data-disk="${device.disk}">
              ${t('devices.mount')}
            </button>
            <button class="btn btn-info unmount-btn" data-disk="${device.disk}">
              ${t('devices.unmount')}
            </button>
            <button class="btn btn-danger eject-btn" data-disk="${device.disk}">
              ${t('devices.eject')}
            </button>
          ` : `
            <button class="btn btn-secondary restore-readonly-btn" data-disk="${device.disk}">
              ${t('devices.restoreReadOnly')}
            </button>
            <button class="btn btn-info unmount-btn" data-disk="${device.disk}">
              ${t('devices.unmount')}
            </button>
            <button class="btn btn-danger eject-btn" data-disk="${device.disk}">
              ${t('devices.eject')}
            </button>
          `}
        </div>
      `;

      return item;
    }
  };

})();
