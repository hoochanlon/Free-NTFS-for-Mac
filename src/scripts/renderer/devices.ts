// 设备管理模块

// 格式化容量显示
const formatCapacity = (bytes: number): string => {
  const sharedFormatter = (globalThis as any).NigateFormatCapacity as ((value: number) => string) | undefined;
  if (sharedFormatter) return sharedFormatter(bytes);
  if (bytes < 1024) {
    return `${bytes} B`;
  } else if (bytes < 1024 * 1024) {
    return `${(bytes / 1024).toFixed(1)} KB`;
  } else if (bytes < 1024 * 1024 * 1024) {
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  } else {
    return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
  }
};

export function renderDevices(devicesList: HTMLElement, devices: any[], mountDeviceFn: (device: any) => void, unmountDeviceFn: (device: any) => void, resetDeviceFn?: (device: any) => void): void {
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

    // 计算容量百分比和可用空间
    let capacityPercent = 0;
    let availableText = '';
    if (device.capacity && device.capacity.total > 0) {
      capacityPercent = Math.round((device.capacity.used / device.capacity.total) * 100);
      if (device.capacity.available > 0) {
        availableText = formatCapacity(device.capacity.available);
      }
      item.setAttribute('data-capacity-percent', capacityPercent.toString());
    }

    item.innerHTML = `
      <div class="device-card">
        <div class="device-icon-large">
          <img src="../../imgs/ico/drive.svg" alt="${device.volumeName}" class="device-icon-svg">
        </div>
        <div class="device-card-content">
          <div class="device-name-large">${device.volumeName}</div>
          ${device.capacity ? `
          <div class="device-capacity-info">
            <span class="capacity-available">${availableText} 可用</span>
            <span class="capacity-separator">，</span>
            <span class="capacity-total">共 ${formatCapacity(device.capacity.total)}</span>
          </div>
          <div class="capacity-bar-windows">
            <div class="capacity-bar-fill-windows" style="width: ${capacityPercent}%"></div>
          </div>
          ` : ''}
        </div>
      </div>
      <div class="device-actions">
        ${device.isReadOnly ? `
          <button class="btn btn-success mount-btn" data-disk="${device.disk}">
            挂载为读写
          </button>
          ${resetDeviceFn ? `
          <button class="btn btn-purple reset-btn" data-disk="${device.disk}">
            重置
          </button>
          ` : ''}
        ` : `
          <button class="btn btn-danger unmount-btn" data-disk="${device.disk}">
            卸载
          </button>
          ${resetDeviceFn ? `
          <button class="btn btn-purple reset-btn" data-disk="${device.disk}">
            重置
          </button>
          ` : ''}
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

  if (resetDeviceFn) {
    devicesList.querySelectorAll('.reset-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const disk = (btn as HTMLElement).dataset.disk;
        const device = devices.find(d => d.disk === disk);
        if (device) resetDeviceFn(device);
      });
    });
  }
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
  // 单个设备操作不需要确认弹窗（根据用户要求）

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

export async function resetDevice(
  electronAPI: any,
  device: any,
  addLogFn: (message: string, type?: 'info' | 'success' | 'error' | 'warning') => void,
  showLoadingFn: (show: boolean) => void,
  refreshDevicesFn: () => void
): Promise<void> {
  try {
    showLoadingFn(true);
    addLogFn(`正在重置 ${device.volumeName}（卸载并修复）...`, 'info');
    addLogFn('提示：请在弹出的对话框中输入管理员密码', 'info');

    const result = await electronAPI.resetDevice(device);

    if (result.success) {
      if (result.result) {
        addLogFn(result.result, 'success');
      }
      await refreshDevicesFn();
    } else {
      addLogFn(`重置失败: ${result.error || '未知错误'}`, 'error');
      if (result.error?.includes('密码错误')) {
        addLogFn('提示：密码错误，请重试', 'warning');
      } else if (result.error?.includes('用户取消')) {
        addLogFn('提示：已取消操作', 'info');
      }
    }
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    addLogFn(`重置失败: ${errorMessage}`, 'error');
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
  // 单个设备操作不需要确认弹窗（根据用户要求）

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
