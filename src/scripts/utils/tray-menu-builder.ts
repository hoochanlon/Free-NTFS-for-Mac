import { Menu, app, BrowserWindow } from 'electron';
import { SettingsManager } from './settings';
import { loadTranslations, t, detectLanguage } from './tray-translations';
import { createDeviceIcon } from './tray-icons';
import { waitForDeviceStatusUpdate } from './tray-device-status';
import { mainWindow, createMainWindow, trayDevicesWindow } from '../window-manager';
import ntfsManager from '../ntfs-manager';
import type { NTFSDevice } from '../../types/electron';

/**
 * 刷新所有窗口的设备列表（统一处理）
 * 优化：增加延迟和重试机制，确保状态更新
 */
async function refreshAllWindowsDevices(): Promise<void> {
  // 等待一小段时间，确保系统状态已更新
  await new Promise(resolve => setTimeout(resolve, 300));

  // 刷新主窗口
  if (mainWindow && !mainWindow.isDestroyed()) {
    try {
      mainWindow.webContents.send('tray-action', 'refresh-devices');
    } catch (error) {
      console.warn('刷新主窗口失败:', error);
    }
  }

  // 刷新托盘窗口（重要：确保托盘窗口显示最新状态）
  if (trayDevicesWindow && !trayDevicesWindow.isDestroyed()) {
    try {
      // 先发送事件（如果窗口正在监听）
      try {
        trayDevicesWindow.webContents.send('tray-action', 'refresh-devices');
      } catch (e) {
        // 忽略事件发送错误
      }

      // 直接调用刷新函数，强制刷新（更可靠）
      await trayDevicesWindow.webContents.executeJavaScript(`
        if (typeof window !== 'undefined' && window.refreshDevices) {
          window.refreshDevices(true);
        }
      `);

      // 如果窗口可见，再等待一小段时间后再次刷新（确保状态同步）
      if (trayDevicesWindow.isVisible()) {
        await new Promise(resolve => setTimeout(resolve, 200));
        await trayDevicesWindow.webContents.executeJavaScript(`
          if (typeof window !== 'undefined' && window.refreshDevices) {
            window.refreshDevices(true);
          }
        `);
      }
    } catch (error) {
      console.warn('刷新托盘窗口设备列表失败:', error);
    }
  }
}

/**
 * 创建托盘菜单
 * @param updateMenuCallback 更新菜单的回调函数（用于处理循环依赖）
 * @param forceRefresh 是否强制刷新（用于动态更新）
 */
export async function createTrayMenu(
  updateMenuCallback: (forceRefresh?: boolean) => Promise<void>
): Promise<Menu> {
  const settings = await SettingsManager.getSettings();
  const lang = detectLanguage(settings.language);

  await loadTranslations(lang);

  // 获取当前连接的 NTFS 设备列表
  let devices: NTFSDevice[] = [];
  try {
    // 强制刷新，确保获取最新状态
    devices = await ntfsManager.getNTFSDevices(true);
    // 按设备名称排序，保持稳定的顺序
    devices.sort((a, b) => {
      // 先按卷名排序
      const nameCompare = a.volumeName.localeCompare(b.volumeName, undefined, { numeric: true, sensitivity: 'base' });
      if (nameCompare !== 0) {
        return nameCompare;
      }
      // 如果卷名相同，按磁盘标识符排序
      return a.disk.localeCompare(b.disk);
    });
  } catch (error) {
    console.error('获取设备列表失败:', error);
  }

  // 获取设备图标
  const deviceIcon = createDeviceIcon();

  const template: Electron.MenuItemConstructorOptions[] = [
    {
      label: t('tray.showWindow') || '显示窗口',
      click: async () => {
        try {
          if (mainWindow && !mainWindow.isDestroyed()) {
            if (mainWindow.isMinimized()) {
              mainWindow.restore();
            }
            mainWindow.show();
            mainWindow.focus();
          } else {
            // 主窗口已被销毁，重新创建窗口
            await createMainWindow();
          }
        } catch (error) {
          console.error('显示窗口失败:', error);
          try {
            await createMainWindow();
          } catch (createError) {
            console.error('重新创建窗口失败:', createError);
          }
        }
      }
    },
    { type: 'separator' }
  ];

  // 添加设备列表
  if (devices.length === 0) {
    template.push({
      label: t('devices.emptyState') || '未检测到 NTFS 设备',
      enabled: false
    });
  } else {
    // 显示设备数量
    template.push({
      label: `${t('tray.ntfsDevices') || 'NTFS 设备'} (${devices.length})`,
      enabled: false
    });
    template.push({ type: 'separator' });

    // 按状态分组：先显示只读设备，再显示读写设备（类似于主窗口的显示方式）
    const readOnlyDevices = devices.filter(d => d.isReadOnly && !d.isUnmounted);
    const readWriteDevices = devices.filter(d => !d.isReadOnly && !d.isUnmounted);
    const unmountedDevices = devices.filter(d => d.isUnmounted);

    // 先显示只读设备
    readOnlyDevices.forEach((device) => {
      const statusLabel = `[${t('devices.readOnly') || '只读'}]`;

      // 设备主菜单项（显示设备名称和状态，类似于主窗口的显示）
      template.push({
        label: `${device.volumeName} ${statusLabel}`,
        icon: deviceIcon,
        submenu: [
          {
            label: t('devices.mount') || '配置为可读写',
            click: async () => {
              try {
                // 直接在主进程中执行操作
                await ntfsManager.mountDevice(device);
                // 等待设备状态更新（最多等待3秒）
                const statusUpdated = await waitForDeviceStatusUpdate(device, false, 3000);

                if (!statusUpdated) {
                  // 如果状态更新超时，额外等待并强制刷新
                  await new Promise(resolve => setTimeout(resolve, 500));
                }

                // 事件驱动：操作完成后立即更新托盘菜单
                // 等待系统状态更新后，立即刷新菜单（强制刷新，确保菜单显示最新状态）
                await new Promise(resolve => setTimeout(resolve, 600));
                await updateMenuCallback(true);

                // 刷新所有窗口的设备列表（包括托盘窗口）
                await refreshAllWindowsDevices();
              } catch (error) {
                console.error('配置设备为可读写失败:', error);
                // 即使失败也更新菜单，显示当前状态
                await new Promise(resolve => setTimeout(resolve, 300));
                await updateMenuCallback(true);
                // 刷新所有窗口的设备列表（包括托盘窗口）
                await refreshAllWindowsDevices();
              }
            }
          },
          {
            label: t('devices.eject') || '推出',
            click: async () => {
              try {
                // 直接在主进程中执行操作
                await ntfsManager.ejectDevice(device);
                // 等待一小段时间让系统更新状态
                await new Promise(resolve => setTimeout(resolve, 500));
                // 更新托盘菜单
                await updateMenuCallback(true);
                // 刷新所有窗口的设备列表（包括托盘窗口）
                await refreshAllWindowsDevices();
              } catch (error) {
                console.error('推出设备失败:', error);
                // 即使失败也更新菜单，显示当前状态
                await updateMenuCallback(true);
              }
            }
          }
        ]
      });
    });

    // 再显示读写设备
    readWriteDevices.forEach((device) => {
      const statusLabel = `[${t('devices.readWrite') || '可读写'}]`;

      // 设备主菜单项（显示设备名称和状态）
      template.push({
        label: `${device.volumeName} ${statusLabel}`,
        icon: deviceIcon,
        submenu: [
          {
            label: t('devices.restoreReadOnly') || '还原为只读',
            click: async () => {
              try {
                // 直接在主进程中执行操作
                await ntfsManager.restoreToReadOnly(device);
                // restoreToReadOnly 内部有1秒延迟，然后系统需要时间重新挂载
                // 对于只读操作，需要更长的等待时间（系统重新挂载可能需要 2-3 秒）
                // 增加等待时间和轮询频率，确保状态实时更新
                const statusUpdated = await waitForDeviceStatusUpdate(device, true, 8000, 150);

                if (!statusUpdated) {
                  // 如果状态更新超时，额外等待并强制刷新
                  console.warn('设备状态更新超时，强制等待并刷新');
                  await new Promise(resolve => setTimeout(resolve, 1000));
                }

                // 事件驱动：操作完成后立即更新托盘菜单
                // restoreToReadOnly 需要更长时间等待系统重新挂载
                await new Promise(resolve => setTimeout(resolve, 1500));
                await updateMenuCallback(true);

                // 刷新所有窗口的设备列表（包括托盘窗口）
                await refreshAllWindowsDevices();
              } catch (error) {
                console.error('还原设备为只读失败:', error);
                // 即使失败也更新菜单，显示当前状态
                await new Promise(resolve => setTimeout(resolve, 500));
                await updateMenuCallback(true);
                // 刷新所有窗口的设备列表（包括托盘窗口）
                await refreshAllWindowsDevices();
              }
            }
          },
          {
            label: t('devices.eject') || '推出',
            click: async () => {
              try {
                // 直接在主进程中执行操作
                await ntfsManager.ejectDevice(device);
                // 等待一小段时间让系统更新状态
                await new Promise(resolve => setTimeout(resolve, 500));
                // 更新托盘菜单
                await updateMenuCallback(true);
                // 刷新所有窗口的设备列表（包括托盘窗口）
                await refreshAllWindowsDevices();
              } catch (error) {
                console.error('推出设备失败:', error);
                // 即使失败也更新菜单，显示当前状态
                await updateMenuCallback(true);
              }
            }
          }
        ]
      });
    });

    // 最后显示已卸载的设备（如果有）
    if (unmountedDevices.length > 0) {
      unmountedDevices.forEach((device) => {
        const statusLabel = `[${t('devices.unmounted') || '已卸载'}]`;
        template.push({
          label: `${device.volumeName} ${statusLabel}`,
          icon: deviceIcon,
          enabled: false // 已卸载的设备禁用
        });
      });
    }

    template.push({ type: 'separator' });

    // 一键操作子菜单
    const quickActions: Electron.MenuItemConstructorOptions[] = [
      {
        label: t('tray.mountAll') || '全读写',
        click: async () => {
          try {
            // 强制刷新，确保获取最新状态
            const devices = await ntfsManager.getNTFSDevices(true);
            const readOnlyDevices = devices.filter(d => d.isReadOnly && !d.isUnmounted);
            if (readOnlyDevices.length === 0) {
              return;
            }
            for (const device of readOnlyDevices) {
              try {
                await ntfsManager.mountDevice(device);
                // 等待设备状态更新
                await waitForDeviceStatusUpdate(device, false, 2000);
              } catch (error) {
                console.error(`配置 ${device.volumeName} 为可读写失败:`, error);
              }
            }
            // 等待所有操作完成后再更新菜单
            await new Promise(resolve => setTimeout(resolve, 500));
            await updateMenuCallback(true);
            // 再次更新确保状态同步
            await new Promise(resolve => setTimeout(resolve, 200));
            await updateMenuCallback(true);
            // 刷新所有窗口的设备列表（包括托盘窗口）
            await refreshAllWindowsDevices();
          } catch (error) {
            console.error('全读写操作失败:', error);
            // 即使失败也更新菜单
            await updateMenuCallback(true);
            // 刷新所有窗口的设备列表（包括托盘窗口）
            await refreshAllWindowsDevices();
          }
        }
      },
      {
        label: t('tray.ejectAll') || '全推出',
        click: async () => {
          try {
            // 强制刷新，确保获取最新状态
            const devices = await ntfsManager.getNTFSDevices(true);
            if (devices.length === 0) {
              return;
            }
            for (const device of devices) {
              try {
                await ntfsManager.ejectDevice(device);
                await new Promise(resolve => setTimeout(resolve, 300));
              } catch (error) {
                console.error(`推出 ${device.volumeName} 失败:`, error);
              }
            }
            // 等待所有操作完成后再更新菜单
            await new Promise(resolve => setTimeout(resolve, 500));
            await updateMenuCallback(true);
            // 再次更新确保状态同步
            await new Promise(resolve => setTimeout(resolve, 200));
            await updateMenuCallback(true);
            // 刷新所有窗口的设备列表（包括托盘窗口）
            await refreshAllWindowsDevices();
          } catch (error) {
            console.error('全推出操作失败:', error);
            // 即使失败也更新菜单
            await updateMenuCallback(true);
            // 刷新所有窗口的设备列表（包括托盘窗口）
            await refreshAllWindowsDevices();
          }
        }
      },
      {
        label: t('devices.restoreAllReadOnly') || '全只读',
        click: async () => {
          try {
            // 强制刷新，确保获取最新状态
            const devices = await ntfsManager.getNTFSDevices(true);
            const readWriteDevices = devices.filter(d => !d.isReadOnly && !d.isUnmounted);
            if (readWriteDevices.length === 0) {
              return;
            }
            for (const device of readWriteDevices) {
              try {
                await ntfsManager.restoreToReadOnly(device);
                // restoreToReadOnly 内部有1秒延迟，增加等待时间和轮询频率
                await waitForDeviceStatusUpdate(device, true, 8000, 150);
                await new Promise(resolve => setTimeout(resolve, 500));
              } catch (error) {
                console.error(`还原 ${device.volumeName} 为只读失败:`, error);
              }
            }
            // 等待所有操作完成后再更新菜单
            await new Promise(resolve => setTimeout(resolve, 500));
            await updateMenuCallback(true);
            // 再次更新确保状态同步
            await new Promise(resolve => setTimeout(resolve, 200));
            await updateMenuCallback(true);
            // 刷新所有窗口的设备列表（包括托盘窗口）
            await refreshAllWindowsDevices();
          } catch (error) {
            console.error('全只读操作失败:', error);
            // 即使失败也更新菜单
            await updateMenuCallback(true);
            // 刷新所有窗口的设备列表（包括托盘窗口）
            await refreshAllWindowsDevices();
          }
        }
      }
    ];

    template.push({
      label: t('tray.quickActions') || '一键操作',
      submenu: quickActions
    });
  }

  template.push({ type: 'separator' });

  // 自动读写开关
  template.push({
    label: t('devices.autoMount') || '自动读写',
    type: 'checkbox',
    checked: settings.autoMount || false,
    click: async (menuItem) => {
      try {
        // 获取当前菜单项的状态（点击后已经切换了）
        const newValue = menuItem.checked;
        // 保存设置
        await SettingsManager.saveSettings({ autoMount: newValue });
        // 更新设置缓存，确保下次创建菜单时使用最新值
        settings.autoMount = newValue;
        // 如果窗口存在，通知渲染进程更新
        if (mainWindow && !mainWindow.isDestroyed()) {
          mainWindow.webContents.send('settings-updated', { autoMount: newValue });
        }
        // 立即更新托盘菜单，确保状态同步（不需要强制刷新，因为设置项本身已经更新）
        await updateMenuCallback(false);
      } catch (error) {
        console.error('保存自动读写设置失败:', error);
        // 如果保存失败，恢复原状态
        const currentSettings = await SettingsManager.getSettings();
        menuItem.checked = currentSettings.autoMount;
        settings.autoMount = currentSettings.autoMount;
      }
    }
  });

  template.push({ type: 'separator' });
  template.push({
    label: t('tray.quit') || '退出',
    click: () => {
      app.quit();
    }
  });

  return Menu.buildFromTemplate(template);
}
