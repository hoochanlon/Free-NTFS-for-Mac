// 主页脚本
(function() {
  'use strict';

  // 检查 electronAPI 是否已存在
  if (typeof window.electronAPI === 'undefined') {
    console.error('electronAPI 未定义，请检查 preload.js 是否正确加载');
    window.electronAPI = {} as any;
  }

  const electronAPI = window.electronAPI;

  // DOM 元素
  const dependenciesModule = document.getElementById('dependenciesModule')!;
  const devicesModule = document.getElementById('devicesModule')!;
  const logsModule = document.getElementById('logsModule')!;
  const viewLogsBtn = document.getElementById('viewLogsBtn') as HTMLButtonElement;
  const depsBadge = document.getElementById('depsBadge')!;
  const devicesBadge = document.getElementById('devicesBadge')!;

  // 打开模块页面
  async function openModule(moduleName: string): Promise<void> {
    try {
      if (electronAPI.openModuleWindow) {
        await electronAPI.openModuleWindow(moduleName);
      }
    } catch (error) {
      console.error(`打开${moduleName}模块失败:`, error);
    }
  }

  // 打开日志窗口
  async function openLogsWindow(): Promise<void> {
    try {
      if (electronAPI.openLogsWindow) {
        await electronAPI.openLogsWindow();
      }
    } catch (error) {
      console.error('打开日志窗口失败:', error);
    }
  }

  // 检查依赖状态
  async function checkDependenciesStatus(): Promise<void> {
    try {
      const deps = await electronAPI.checkDependencies();
      const allInstalled = deps.swift && deps.brew && deps.macfuse && deps.ntfs3g;

      if (allInstalled) {
        depsBadge.textContent = '✓ 已就绪';
        depsBadge.className = 'module-badge ready';
      } else {
        depsBadge.textContent = '⚠ 缺少依赖';
        depsBadge.className = 'module-badge warning';
      }
    } catch (error) {
      depsBadge.textContent = '✗ 检查失败';
      depsBadge.className = 'module-badge error';
    }
  }

  // 检查设备状态
  async function checkDevicesStatus(): Promise<void> {
    try {
      const devices = await electronAPI.getNTFSDevices();
      if (devices.length === 0) {
        devicesBadge.textContent = '等待设备';
        devicesBadge.className = 'module-badge';
      } else {
        const readOnlyCount = devices.filter(d => d.isReadOnly).length;
        if (readOnlyCount > 0) {
          devicesBadge.textContent = `${readOnlyCount} 个只读`;
          devicesBadge.className = 'module-badge warning';
        } else {
          devicesBadge.textContent = `${devices.length} 个设备就绪`;
          devicesBadge.className = 'module-badge ready';
        }
      }
    } catch (error) {
      devicesBadge.textContent = '检查失败';
      devicesBadge.className = 'module-badge error';
    }
  }

  // 初始化
  document.addEventListener('DOMContentLoaded', () => {
    // 事件监听
    dependenciesModule.addEventListener('click', () => openModule('dependencies'));
    devicesModule.addEventListener('click', () => openModule('devices'));
    logsModule.addEventListener('click', () => openLogsWindow());
    viewLogsBtn.addEventListener('click', () => openLogsWindow());

    // 检查状态
    checkDependenciesStatus();
    checkDevicesStatus();

    // 定期更新状态
    setInterval(() => {
      checkDependenciesStatus();
      checkDevicesStatus();
    }, 5000);
  });
})();
