// NTFS设备页面脚本
(function() {
  'use strict';

  // 检查 electronAPI 是否已存在
  if (typeof window.electronAPI === 'undefined') {
    console.error('electronAPI 未定义，请检查 preload.js 是否正确加载');
    window.electronAPI = {} as any;
  }

  const electronAPI = window.electronAPI;

  // DOM 元素
  const devicesList = document.getElementById('devicesList')!;
  const refreshBtn = document.getElementById('refreshBtn') as HTMLButtonElement;
  const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;
  const closeBtn = document.getElementById('closeBtn') as HTMLButtonElement;

  // 状态管理
  let devices: any[] = [];
  let autoRefreshInterval: NodeJS.Timeout | null = null;
  let lastDeviceCount = 0;
  let lastDeviceState = '';

  type LogType = 'info' | 'success' | 'error' | 'warning';

  // 添加日志
  function addLog(message: string, type: LogType = 'info'): void {
    const time = new Date().toLocaleTimeString('zh-CN');
    const logs = JSON.parse(localStorage.getItem('appLogs') || '[]');
    logs.push({ time, message, type });
    // 限制日志数量
    if (logs.length > 1000) {
      logs.shift();
    }
    localStorage.setItem('appLogs', JSON.stringify(logs));
  }

  // 显示/隐藏加载遮罩
  function showLoading(show: boolean = true): void {
    if (show) {
      loadingOverlay.classList.add('visible');
    } else {
      loadingOverlay.classList.remove('visible');
    }
  }

  // 刷新设备列表
  async function refreshDevices(): Promise<void> {
    try {
      devices = await electronAPI.getNTFSDevices();
      renderDevices();

      const currentDeviceCount = devices.length;
      const readOnlyCount = devices.filter(d => d.isReadOnly).length;
      const currentState = `${currentDeviceCount}-${readOnlyCount}`;

      // 只在设备状态变化时添加日志
      const stateChanged = currentDeviceCount !== lastDeviceCount || currentState !== lastDeviceState;

      if (devices.length === 0) {
        if (stateChanged) {
          addLog('未检测到 NTFS 设备', 'info');
        }
      } else {
        const readWriteCount = devices.length - readOnlyCount;

        if (readOnlyCount > 0) {
          if (stateChanged) {
            if (readWriteCount > 0) {
              addLog(`检测到 ${devices.length} 个设备（${readOnlyCount} 个只读，${readWriteCount} 个读写）`, 'info');
            } else {
              addLog(`检测到 ${devices.length} 个 NTFS 设备（全部只读）`, 'warning');
            }
          }
        } else {
          if (stateChanged) {
            addLog(`检测到 ${devices.length} 个 NTFS 设备（全部可读写）`, 'success');
          }
        }
      }

      lastDeviceCount = currentDeviceCount;
      lastDeviceState = currentState;
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      addLog(`刷新设备列表失败: ${errorMessage}`, 'error');
    }
  }

  // 渲染设备列表
  function renderDevices(): void {
    if (devices.length === 0) {
      devicesList.innerHTML = `
        <div class="empty-state">
          <div class="empty-icon">💾</div>
          <p>未检测到 NTFS 设备</p>
          <p class="empty-hint">请插入 NTFS 格式的移动存储设备</p>
        </div>
      `;
      return;
    }

    devicesList.innerHTML = '';

    devices.forEach(device => {
      const item = document.createElement('div');
      item.className = 'device-item';

      const statusClass = device.isReadOnly ? 'read-only' : 'read-write';
      const statusText = device.isReadOnly ? '只读' : '读写';

      item.innerHTML = `
        <div class="device-header">
          <div class="device-name">
            <span class="device-icon">💿</span>
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
        const device = devices.find(d => d.disk === disk);
        if (device) mountDevice(device);
      });
    });

    devicesList.querySelectorAll('.unmount-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const disk = (btn as HTMLElement).dataset.disk;
        const device = devices.find(d => d.disk === disk);
        if (device) unmountDevice(device);
      });
    });
  }

  // 挂载设备
  async function mountDevice(device: any): Promise<void> {
    const message = `确定要将 ${device.volumeName} 挂载为读写模式吗？\n\n` +
                    `⚠️ 注意：\n` +
                    `• 这需要管理员权限，系统会弹出密码输入对话框\n` +
                    `• 如果设备在 Windows 中使用了快速启动，可能需要先在 Windows 中完全关闭设备`;

    if (!confirm(message)) {
      return;
    }

    try {
      showLoading(true);
      addLog(`正在挂载 ${device.volumeName}...`, 'info');
      addLog('提示：请在弹出的对话框中输入管理员密码', 'info');

      const result = await electronAPI.mountDevice(device);

      if (result.success) {
        if (result.result) {
          addLog(result.result, 'success');
        }
        await refreshDevices();
      } else {
        addLog(`挂载失败: ${result.error || '未知错误'}`, 'error');
        if (result.error?.includes('密码错误')) {
          addLog('提示：密码错误，请重试', 'warning');
        } else if (result.error?.includes('用户取消')) {
          addLog('提示：已取消操作', 'info');
        }
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      addLog(`挂载失败: ${errorMessage}`, 'error');
    } finally {
      showLoading(false);
    }
  }

  // 卸载设备
  async function unmountDevice(device: any): Promise<void> {
    const message = `确定要卸载 ${device.volumeName} 吗？\n\n` +
                    `⚠️ 注意：这需要管理员权限，系统会弹出密码输入对话框`;

    if (!confirm(message)) {
      return;
    }

    try {
      showLoading(true);
      addLog(`正在卸载 ${device.volumeName}...`, 'info');
      addLog('提示：请在弹出的对话框中输入管理员密码', 'info');

      const result = await electronAPI.unmountDevice(device);

      if (result.success) {
        if (result.result) {
          addLog(result.result, 'success');
        }
        await refreshDevices();
      } else {
        addLog(`卸载失败: ${result.error || '未知错误'}`, 'error');
        if (result.error?.includes('密码错误')) {
          addLog('提示：密码错误，请重试', 'warning');
        } else if (result.error?.includes('用户取消')) {
          addLog('提示：已取消操作', 'info');
        }
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      addLog(`卸载失败: ${errorMessage}`, 'error');
    } finally {
      showLoading(false);
    }
  }

  // 自动刷新
  function startAutoRefresh(): void {
    // 每 5 秒刷新一次设备列表
    autoRefreshInterval = setInterval(() => {
      refreshDevices();
    }, 5000);
  }

  // 关闭窗口
  async function closeWindow(): Promise<void> {
    try {
      if (electronAPI.closeModuleWindow) {
        await electronAPI.closeModuleWindow();
      } else {
        window.close();
      }
    } catch (error) {
      window.close();
    }
  }

  // 初始化
  document.addEventListener('DOMContentLoaded', () => {
    refreshBtn.addEventListener('click', refreshDevices);
    closeBtn.addEventListener('click', closeWindow);

    // 自动刷新
    refreshDevices();
    startAutoRefresh();

    // 清理
    window.addEventListener('beforeunload', () => {
      if (autoRefreshInterval) {
        clearInterval(autoRefreshInterval);
      }
    });
  });
})();
