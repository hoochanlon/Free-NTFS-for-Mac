// 设备管理模块
export function renderDevices(devicesList: HTMLElement, devices: any[], mountDeviceFn: (device: any) => void, unmountDeviceFn: (device: any) => void): void {
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
      if (device) mountDeviceFn(device);
    });
  });

  devicesList.querySelectorAll('.unmount-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const disk = (btn as HTMLElement).dataset.disk;
      const device = devices.find(d => d.disk === disk);
      if (device) unmountDeviceFn(device);
    });
  });
}

export async function refreshDevices(
  electronAPI: any,
  devicesList: HTMLElement,
  devicesRef: { current: any[] },
  lastDeviceCountRef: { current: number },
  lastDeviceStateRef: { current: string },
  updateStatusFn: (status: 'active' | 'error', text: string) => void,
  addLogFn: (message: string, type?: 'info' | 'success' | 'error' | 'warning') => void,
  renderDevicesFn: () => void
): Promise<void> {
  try {
    devicesRef.current = await electronAPI.getNTFSDevices();
    renderDevicesFn();

    const currentDeviceCount = devicesRef.current.length;
    const readOnlyCount = devicesRef.current.filter(d => d.isReadOnly).length;
    const currentState = `${currentDeviceCount}-${readOnlyCount}`;

    const stateChanged = currentDeviceCount !== lastDeviceCountRef.current || currentState !== lastDeviceStateRef.current;

    if (devicesRef.current.length === 0) {
      updateStatusFn('active', '等待设备');
      if (stateChanged) {
        addLogFn('未检测到 NTFS 设备', 'info');
      }
    } else {
      const readWriteCount = devicesRef.current.length - readOnlyCount;

      if (readOnlyCount > 0) {
        updateStatusFn('error', `${readOnlyCount} 个设备只读`);
        if (stateChanged) {
          if (readWriteCount > 0) {
            addLogFn(`检测到 ${devicesRef.current.length} 个设备（${readOnlyCount} 个只读，${readWriteCount} 个读写）`, 'info');
          } else {
            addLogFn(`检测到 ${devicesRef.current.length} 个 NTFS 设备（全部只读）`, 'warning');
          }
        }
      } else {
        updateStatusFn('active', `${devicesRef.current.length} 个设备就绪`);
        if (stateChanged) {
          addLogFn(`检测到 ${devicesRef.current.length} 个 NTFS 设备（全部可读写）`, 'success');
        }
      }
    }

    lastDeviceCountRef.current = currentDeviceCount;
    lastDeviceStateRef.current = currentState;
  } catch (error) {
    updateStatusFn('error', '检测失败');
    const errorMessage = error instanceof Error ? error.message : String(error);
    addLogFn(`刷新设备列表失败: ${errorMessage}`, 'error');
  }
}

export async function mountDevice(
  electronAPI: any,
  device: any,
  addLogFn: (message: string, type?: 'info' | 'success' | 'error' | 'warning') => void,
  showLoadingFn: (show: boolean) => void,
  refreshDevicesFn: () => void
): Promise<void> {
  const message = `确定要将 ${device.volumeName} 挂载为读写模式吗？\n\n` +
                  `⚠️ 注意：\n` +
                  `• 这需要管理员权限，系统会弹出密码输入对话框\n` +
                  `• 如果设备在 Windows 中使用了快速启动，可能需要先在 Windows 中完全关闭设备`;

  if (!confirm(message)) {
    return;
  }

  try {
    showLoadingFn(true);
    addLogFn(`正在挂载 ${device.volumeName}...`, 'info');
    addLogFn('提示：请在弹出的对话框中输入管理员密码', 'info');

    const result = await electronAPI.mountDevice(device);

    if (result.success) {
      if (result.result) {
        addLogFn(result.result, 'success');
      }
      await refreshDevicesFn();
    } else {
      addLogFn(`挂载失败: ${result.error || '未知错误'}`, 'error');
      if (result.error?.includes('密码错误')) {
        addLogFn('提示：密码错误，请重试', 'warning');
      } else if (result.error?.includes('用户取消')) {
        addLogFn('提示：已取消操作', 'info');
      }
    }
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    addLogFn(`挂载失败: ${errorMessage}`, 'error');
  } finally {
    showLoadingFn(false);
  }
}

export async function unmountDevice(
  electronAPI: any,
  device: any,
  addLogFn: (message: string, type?: 'info' | 'success' | 'error' | 'warning') => void,
  showLoadingFn: (show: boolean) => void,
  refreshDevicesFn: () => void
): Promise<void> {
  const message = `确定要卸载 ${device.volumeName} 吗？\n\n` +
                  `⚠️ 注意：这需要管理员权限，系统会弹出密码输入对话框`;

  if (!confirm(message)) {
    return;
  }

  try {
    showLoadingFn(true);
    addLogFn(`正在卸载 ${device.volumeName}...`, 'info');
    addLogFn('提示：请在弹出的对话框中输入管理员密码', 'info');

    const result = await electronAPI.unmountDevice(device);

    if (result.success) {
      if (result.result) {
        addLogFn(result.result, 'success');
      }
      await refreshDevicesFn();
    } else {
      addLogFn(`卸载失败: ${result.error || '未知错误'}`, 'error');
      if (result.error?.includes('密码错误')) {
        addLogFn('提示：密码错误，请重试', 'warning');
      } else if (result.error?.includes('用户取消')) {
        addLogFn('提示：已取消操作', 'info');
      }
    }
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    addLogFn(`卸载失败: ${errorMessage}`, 'error');
  } finally {
    showLoadingFn(false);
  }
}
