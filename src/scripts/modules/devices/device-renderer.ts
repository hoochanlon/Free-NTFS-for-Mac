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

  // 格式化容量显示
  function formatCapacity(bytes: number): string {
    if (bytes < 1024) {
      return `${bytes} B`;
    } else if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(1)} KB`;
    } else if (bytes < 1024 * 1024 * 1024) {
      return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    } else {
      return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
    }
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

      // 计算容量百分比和使用空间（Windows 风格）
      let capacityPercent = 0;
      let availableText = '';
      let totalText = '';
      if (device.capacity && device.capacity.total > 0) {
        const total = device.capacity.total;
        let used = device.capacity.used || 0;
        let available = device.capacity.available || 0;

        // 计算逻辑：始终优先使用 available 来计算 used（更可靠）
        // 因为 available 通常比 used 更准确，且不容易出错
        // 注意：即使 available 接近 total（比如 99.9%），也应该使用它来计算
        if (available > 0) {
          // 如果 available 存在，直接使用它来计算 used
          // 这是最可靠的方法，因为 available 通常更准确
          used = total - available;
          // 确保 used 不为负数
          if (used < 0) {
            used = 0;
            available = total;
          }
        } else if (device.capacity.used && device.capacity.used > 0) {
          // 如果只有 used 值（available 不存在或无效），使用它
          used = device.capacity.used;
          available = total - used;
          if (available < 0) {
            available = 0;
            used = total;
          }
        } else {
          // 如果都无法获取，至少显示总容量
          used = 0;
          available = total;
        }

        // 最终验证：确保 used + available 约等于 total
        const sum = used + available;
        const diff = Math.abs(sum - total);
        if (diff > total * 0.01) {
          // 如果差异超过 1%，重新计算
          if (available > 0) {
            used = total - available;
          } else if (used > 0) {
            available = total - used;
          }
        }

        // 计算使用率百分比（用于进度条和颜色）
        // 确保百分比在 0-100 之间
        capacityPercent = Math.max(0, Math.min(100, Math.round((used / total) * 100)));
        availableText = formatCapacity(available);
        totalText = formatCapacity(total);
        // 设置 data 属性用于样式选择器
        item.setAttribute('data-capacity-percent', capacityPercent.toString());
      }

      // 检查是否是托盘窗口
      const isTrayWindow = document.body && document.body.classList.contains('tray-window');

      // 托盘窗口使用卡片样式，主窗口使用原来的样式
      if (isTrayWindow) {
        // 托盘窗口：显示磁盘名称、容量条和操作按钮
        item.innerHTML = `
          <div class="device-card-tray">
            <div class="device-icon-large">
              <img src="../imgs/ico/drive.svg" alt="${device.volumeName}" class="device-icon-svg">
            </div>
            <div class="device-card-content">
              <div class="device-name-large">${device.volumeName}</div>
              ${device.capacity ? `
              <div class="device-capacity-info-windows">
                <span class="capacity-text-windows">${availableText} ${t('devices.available')}, ${t('devices.total')} ${totalText}</span>
              </div>
              <div class="capacity-bar-windows">
                <div class="capacity-bar-fill-windows" style="width: ${capacityPercent}%; min-width: ${capacityPercent > 0 ? '2px' : '0'};" title="${t('devices.usageRate')}: ${capacityPercent}%"></div>
              </div>
              ` : ''}
              <div class="device-actions-tray">
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
                  <button class="btn btn-danger eject-btn" data-disk="${device.disk}">
                    ${t('devices.eject')}
                  </button>
                ` : `
                  <button class="btn btn-secondary restore-readonly-btn" data-disk="${device.disk}">
                    ${t('devices.restoreReadOnly')}
                  </button>
                  <button class="btn btn-danger eject-btn" data-disk="${device.disk}">
                    ${t('devices.eject')}
                  </button>
                `}
              </div>
            </div>
          </div>
        `;
      } else {
        item.innerHTML = `
          <div class="device-header">
            <div class="device-name">
              <span class="device-icon"></span>
              ${device.volumeName}
            </div>
            <span class="device-status ${statusClass}">${statusText}</span>
          </div>
          <div class="device-info">
            ${(() => {
              // 使用共享的设备信息渲染函数（统一管理，避免重复代码）
              const Utils = AppModules.Devices?.Utils;
              if (Utils && Utils.renderDeviceInfoHTML) {
                return Utils.renderDeviceInfoHTML(device, t, formatCapacity);
              }
              // 如果共享函数不存在，使用本地实现（向后兼容）
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
            })()}
          </div>
        `;
      }

      // 只在主窗口添加操作按钮，托盘窗口不显示
      if (!isTrayWindow) {
        const actionsHTML = `
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

        item.innerHTML += actionsHTML;
      }

      return item;
    }
  };

})();
