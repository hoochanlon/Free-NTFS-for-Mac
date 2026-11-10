// 设备管理模块

// 格式化容量显示
const formatCapacity = (bytes: number): string => {
  if (bytes < 1024) {
    return `${bytes} B`;
  } else if (bytes < 1024 * 1024) {
    return `${(bytes / 1024).toFixed(1)} KB`;
  } else if (bytes < 1024 * 1024 * 1024) {
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  } else if (bytes < 1024 * 1024 * 1024 * 1024) {
    return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
  } else {
    return `${(bytes / (1024 * 1024 * 1024 * 1024)).toFixed(2)} TB`;
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
  renderDevicesFn: () => void
): Promise<void> {
  try {
    devicesRef.current = await electronAPI.getNTFSDevices();
    renderDevicesFn();

    const currentDeviceCount = devicesRef.current.length;
    const readOnlyCount = devicesRef.current.filter(d => d.isReadOnly).length;
    const currentState = `${currentDeviceCount}-${readOnlyCount}`;

    if (devicesRef.current.length === 0) {
      updateStatusFn('active', '等待设备');
    } else if (readOnlyCount > 0) {
      updateStatusFn('error', `${readOnlyCount} 个设备只读`);
    } else {
      updateStatusFn('active', `${devicesRef.current.length} 个设备就绪`);
    }

    lastDeviceCountRef.current = currentDeviceCount;
    lastDeviceStateRef.current = currentState;
  } catch (error) {
    updateStatusFn('error', '检测失败');
    console.error('刷新设备列表失败:', error);
  }
}

export async function mountDevice(
  electronAPI: any,
  device: any,
  showLoadingFn: (show: boolean) => void,
  refreshDevicesFn: () => void
): Promise<void> {
  try {
    showLoadingFn(true);
    const result = await electronAPI.mountDevice(device);
    if (result.success) {
      await refreshDevicesFn();
    } else {
      console.error('挂载失败:', result.error || '未知错误');
    }
  } catch (error) {
    console.error('挂载失败:', error);
  } finally {
    showLoadingFn(false);
  }
}

export async function resetDevice(
  electronAPI: any,
  device: any,
  showLoadingFn: (show: boolean) => void,
  refreshDevicesFn: () => void
): Promise<void> {
  try {
    showLoadingFn(true);
    const result = await electronAPI.resetDevice(device);
    if (result.success) {
      await refreshDevicesFn();
    } else {
      console.error('重置失败:', result.error || '未知错误');
    }
  } catch (error) {
    console.error('重置失败:', error);
  } finally {
    showLoadingFn(false);
  }
}

export async function unmountDevice(
  electronAPI: any,
  device: any,
  showLoadingFn: (show: boolean) => void,
  refreshDevicesFn: () => void
): Promise<void> {
  try {
    showLoadingFn(true);
    const result = await electronAPI.unmountDevice(device);
    if (result.success) {
      await refreshDevicesFn();
    } else {
      console.error('卸载失败:', result.error || '未知错误');
    }
  } catch (error) {
    console.error('卸载失败:', error);
  } finally {
    showLoadingFn(false);
  }
}
