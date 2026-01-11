// 设备工具模块
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
  if (!AppModules.Devices.Utils) {
    AppModules.Devices.Utils = {};
  }

  type LogType = 'info' | 'success' | 'error' | 'warning';

  // 设备工具功能
  AppModules.Devices.Utils = {
    // 获取翻译文本的辅助函数
    t(key: string, params?: Record<string, string | number>): string {
      const AppUtils = (window as any).AppUtils;
      if (AppUtils && AppUtils.I18n && AppUtils.I18n.t) {
        return AppUtils.I18n.t(key, params);
      }
      // 如果 i18n 未初始化，返回 key
      return key;
    },

    // 格式化容量显示
    formatCapacity(bytes: number): string {
      if (bytes < 1024) {
        return `${bytes} B`;
      } else if (bytes < 1024 * 1024) {
        return `${(bytes / 1024).toFixed(1)} KB`;
      } else if (bytes < 1024 * 1024 * 1024) {
        return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
      } else {
        return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
      }
    },

    // 添加日志（使用 AppUtils.Logs 如果可用，否则使用 localStorage）
    async addLog(message: string, type: LogType = 'info'): Promise<void> {
      const AppUtils = (window as any).AppUtils;
      if (AppUtils && AppUtils.Logs && AppUtils.Logs.addLog) {
        await AppUtils.Logs.addLog(message, type);
        return;
      }
      // 降级到 localStorage（向后兼容）
      const time = new Date().toLocaleTimeString('zh-CN');
      const logs = JSON.parse(localStorage.getItem('appLogs') || '[]');
      logs.push({ time, message, type });
      // 限制日志数量
      if (logs.length > 1000) {
        logs.shift();
      }
      localStorage.setItem('appLogs', JSON.stringify(logs));
    },

    // 显示/隐藏加载遮罩
    showLoading(show: boolean = true): void {
      // 如果是托盘窗口，不显示加载遮罩（无感刷新）
      const isTrayWindow = document.body && document.body.classList.contains('tray-window');
      if (isTrayWindow) {
        return; // 托盘窗口不显示加载遮罩
      }

      const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;
      if (!loadingOverlay) return;

      const AppUtils = (window as any).AppUtils;
      // 获取翻译函数
      const getTranslation = (key: string, fallback: string): string => {
        if (AppUtils && AppUtils.I18n && AppUtils.I18n.t) {
          return AppUtils.I18n.t(key) || fallback;
        }
        return fallback;
      };

      if (AppUtils && AppUtils.UI && AppUtils.UI.showLoading) {
        // 刷新设备时显示"刷新中..."而不是"正在检查..."
        const refreshText = show ? (getTranslation('tray.refreshing', getTranslation('devices.refreshDevices', '刷新中...'))) : undefined;
        AppUtils.UI.showLoading(loadingOverlay, show, refreshText);
      } else {
        // 降级到直接操作（向后兼容）
        if (show) {
          loadingOverlay.classList.add('visible');
          // 更新加载文本
          const loadingText = loadingOverlay.querySelector('p');
          if (loadingText) {
            const refreshText = getTranslation('tray.refreshing', getTranslation('devices.refreshDevices', '刷新中...'));
            loadingText.textContent = refreshText;
          }
        } else {
          loadingOverlay.classList.remove('visible');
        }
      }
    },

    // 渲染设备信息 HTML（用于主窗口）
    renderDeviceInfoHTML(device: any, t: (key: string, params?: Record<string, string | number>) => string, formatCapacity: (bytes: number) => string): string {
      const isUnmounted = device.isUnmounted || false;
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
    }
  };

})();
