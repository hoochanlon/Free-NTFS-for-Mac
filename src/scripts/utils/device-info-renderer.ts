// 设备信息渲染工具函数（共享模块）
// 统一管理设备信息的 HTML 渲染逻辑，避免重复代码
// 注意：不使用 import，避免生成 CommonJS 代码（浏览器环境不支持）

(function() {
  'use strict';

  // 创建全局命名空间
  if (typeof (window as any).AppModules === 'undefined') {
    (window as any).AppModules = {};
  }
  if (!(window as any).AppModules.Devices) {
    (window as any).AppModules.Devices = {};
  }
  if (!(window as any).AppModules.Devices.Utils) {
    (window as any).AppModules.Devices.Utils = {};
  }

  const AppModules = (window as any).AppModules;

  /**
   * 渲染设备信息的 HTML
   * @param device 设备对象
   * @param t 翻译函数
   * @param formatCapacity 容量格式化函数
   * @returns 设备信息的 HTML 字符串
   */
  function renderDeviceInfoHTML(
    device: any,
    t: (key: string) => string,
    formatCapacity: (bytes: number) => string
  ): string {
    const isUnmounted = device.isUnmounted || false;
    return `
      ${device.capacity ? `
      <div class="device-info-item">
        <span class="device-info-label">${t('devices.capacityLabel')}</span>
        <span>${formatCapacity(device.capacity.used)}/${formatCapacity(device.capacity.total)}</span>
      </div>
      ` : ''}
      <div class="device-info-item">
        <span class="device-info-label">${t('devices.deviceMountPointLabel')}</span>
        <span>${device.devicePath}${isUnmounted ? ` (${t('devices.notMounted')})` : ` → ${device.volume}`}</span>
      </div>
    `;
  }

  // 将函数暴露到全局命名空间
  AppModules.Devices.Utils.renderDeviceInfoHTML = renderDeviceInfoHTML;
})();
