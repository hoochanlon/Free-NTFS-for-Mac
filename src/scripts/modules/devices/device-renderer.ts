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

    // 渲染设备列表（整合了 devices.ts 中的复杂渲染逻辑）
    renderDevices(devicesList: HTMLElement, readWriteDevicesList: HTMLElement): void {
      const devices = AppModules.Devices.devices || [];

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

      // 保存当前选中的设备（如果有）
      const selectedDisk = (document.querySelector('.device-item.selected') as HTMLElement)?.dataset?.disk;

      // 检查是否是托盘窗口（用于判断是否需要重新渲染）
      const isTrayWindow = document.body && document.body.classList.contains('tray-window');
      const lastIsTrayWindow = (devicesList as any).__lastIsTrayWindow;

      // 生成设备状态的唯一标识，用于判断是否需要更新
      // 包含容量信息，确保容量变化时能触发重新渲染
      // 同时包含当前语言，确保语言变更时能触发重新渲染
      const currentLanguage = ((window as any).AppUtils && (window as any).AppUtils.I18n)
        ? ((window as any).AppUtils.I18n.getLanguage ? (window as any).AppUtils.I18n.getLanguage() : 'en')
        : 'en';
      const deviceStateKey = devices.map((d: any) => {
        const capacityInfo = d.capacity ? `${d.capacity.total}:${d.capacity.available || 0}:${d.capacity.used || 0}` : 'no-capacity';
        return `${d.disk}:${d.isReadOnly}:${d.isUnmounted || false}:${capacityInfo}`;
      }).join('|') + `|lang:${currentLanguage}`;
      const lastStateKey = (devicesList as any).__lastStateKey || '';

      // 如果设备状态没有变化，且窗口类型没有变化，且已有DOM元素，则跳过重新渲染
      if (deviceStateKey === lastStateKey &&
          isTrayWindow === lastIsTrayWindow &&
          devicesList.querySelectorAll('.device-item').length === devices.length) {
        return;
      }

      // 保存当前窗口类型和状态
      (devicesList as any).__lastIsTrayWindow = isTrayWindow;
      (devicesList as any).__lastStateKey = deviceStateKey;

      devicesList.innerHTML = '';

      // 渲染所有设备
      devices.forEach((device: any) => {
          const item = AppModules.Devices.Renderer.createDeviceItem(device);
          devicesList.appendChild(item);
        });

      // 恢复选中状态
      if (selectedDisk) {
        const selectedItem = devicesList.querySelector(`[data-disk="${selectedDisk}"]`) as HTMLElement;
        if (selectedItem) {
          selectedItem.classList.add('selected');
        }
      }

      // 绑定按钮事件
      AppModules.Devices.Events.bindDeviceEvents(devicesList, readWriteDevicesList);
    },

    // 创建设备项（整合了 devices.ts 中的复杂容量计算逻辑）
    createDeviceItem(device: any): HTMLElement {
      const item = document.createElement('div');
      item.className = 'device-item';
      item.setAttribute('data-disk', device.disk);

      // 添加读写设备样式类
      if (!device.isReadOnly && !device.isUnmounted) {
        item.classList.add('read-write-device');
      }
      if (device.isUnmounted) {
        item.classList.add('unmounted-device');
      }

      const isUnmounted = device.isUnmounted || false;
      const statusClass = isUnmounted ? 'unmounted' : (device.isReadOnly ? 'read-only' : 'read-write');
      const statusText = isUnmounted ? t('devices.unmounted') : (device.isReadOnly ? t('devices.readOnly') : t('devices.readWrite'));

      // 检查是否是托盘窗口
      const isTrayWindow = document.body && document.body.classList.contains('tray-window');

      // 计算容量百分比和使用空间（Windows 风格）- 整合自 devices.ts
      let capacityPercent = 0;
      let availableText = '';
      let totalText = '';

      if (device.capacity && device.capacity.total > 0) {
        const total = device.capacity.total;
        let used = device.capacity.used || 0;
        let available = device.capacity.available || 0;

        // 计算逻辑：始终优先使用 available 来计算 used（更可靠）
        if (available > 0) {
          used = total - available;
          if (used < 0) {
            used = 0;
            available = total;
          }
        } else if (device.capacity.used && device.capacity.used > 0) {
          used = device.capacity.used;
          available = total - used;
          if (available < 0) {
            available = 0;
            used = total;
          }
        } else {
          used = 0;
          available = total;
        }

        // 最终验证：确保 used + available 约等于 total
        const sum = used + available;
        const diff = Math.abs(sum - total);
        if (diff > total * 0.01) {
          if (available > 0 && available < total) {
            used = total - available;
          } else if (used > 0 && used < total) {
            available = total - used;
          }
        }

        // 确保数据不为负数且不超过 total
        used = Math.max(0, Math.min(total, used));
        available = Math.max(0, Math.min(total, available));

        // 计算使用率百分比（用于进度条和颜色）
        if (total > 0) {
          capacityPercent = Math.max(0, Math.min(100, Math.round((used / total) * 100)));
          if (isNaN(capacityPercent) || capacityPercent < 0 || capacityPercent > 100) {
        capacityPercent = Math.max(0, Math.min(100, Math.round((used / total) * 100)));
          }
        }

        availableText = formatCapacity(available);
        totalText = formatCapacity(total);
        item.setAttribute('data-capacity-percent', capacityPercent.toString());
      }

      // 托盘窗口使用卡片样式，主窗口使用原来的样式
      // 在渲染前再次验证 capacityPercent（防止变量作用域问题）
      let finalCapacityPercent = capacityPercent;
      if (isTrayWindow) {
        if (device.capacity && device.capacity.total > 0) {
          const total = device.capacity.total;
          const available = device.capacity.available || 0;
          const used = device.capacity.used || 0;
          let calculatedUsed = used;

          // 重新计算以确保正确
          if (available > 0) {
            calculatedUsed = total - available;
          } else if (used > 0) {
            calculatedUsed = used;
          }

          if (total > 0 && calculatedUsed >= 0) {
            const recalculatedPercent = Math.round((calculatedUsed / total) * 100);
            finalCapacityPercent = Math.max(0, Math.min(100, recalculatedPercent));
          }
        }

        // 托盘窗口：显示磁盘名称、容量条和操作按钮
        item.innerHTML = `
          <div class="device-card-tray">
            <div class="device-icon-large">
              <img src="../imgs/ico/drive.svg" alt="${device.volumeName}" class="device-icon-svg">
            </div>
            <div class="device-card-content">
              <div class="device-name-large">${device.volumeName}</div>
              ${device.capacity && device.capacity.total > 0 && availableText && totalText ? `
              <div class="device-capacity-info-windows">
                <span class="capacity-text-windows">${availableText} ${t('devices.available')}, ${t('devices.total')} ${totalText}</span>
              </div>
              <div class="capacity-bar-windows">
                <div class="capacity-bar-fill-windows" data-percent="${finalCapacityPercent}" data-width="${finalCapacityPercent}" title="${t('devices.usageRate')}: ${finalCapacityPercent}%"></div>
              </div>
              ` : ''}
              <div class="device-actions-tray">
                ${isUnmounted ? `
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

        // 渲染后立即设置进度条宽度（避免 CSP 阻止内联样式）
        if (device.capacity && device.capacity.total > 0) {
          setTimeout(() => {
            const fillElement = item.querySelector('.capacity-bar-fill-windows') as HTMLElement;
            if (fillElement) {
              const percent = fillElement.getAttribute('data-width');
              if (percent) {
                fillElement.style.width = `${percent}%`;
              }
            }
          }, 0);
        }
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
              return `
            ${device.capacity ? `
            <div class="device-info-item">
              <span class="device-info-label">${t('devices.capacityLabel')}</span>
                  <span>${formatCapacity(device.capacity.used || 0)}/${formatCapacity(device.capacity.total)}</span>
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

      // 只在主窗口添加操作按钮，托盘窗口不显示
        const actionsHTML = `
          <div class="device-actions">
            ${isUnmounted ? `
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
