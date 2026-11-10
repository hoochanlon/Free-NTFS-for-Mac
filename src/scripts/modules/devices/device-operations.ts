// 设备操作模块
// 注意：不使用 import，避免生成 CommonJS 代码（浏览器环境不支持）

(function() {
  'use strict';

  // 创建全局命名空间
  if (typeof (window as any).AppModules === 'undefined') {
    (window as any).AppModules = {};
  }

  const AppModules = (window as any).AppModules;
  const electronAPI = (window as any).electronAPI;
  const AppUtils = (window as any).AppUtils;
  const DeviceUtils = AppModules?.Devices?.Utils;

  // 获取翻译文本的辅助函数
  function t(key: string, params?: Record<string, string | number>): string {
    if (DeviceUtils && DeviceUtils.t) {
      return DeviceUtils.t(key, params);
    }
    if (AppUtils && AppUtils.I18n) {
      return AppUtils.I18n.t(key, params);
    }
    return key; // 如果 i18n 未初始化，返回 key
  }


  function isPasswordError(error: unknown): boolean {
    const message = error instanceof Error ? error.message : String(error);
    return /密码错误|password|authentication failure|authentication failed|sorry,\s*try again/i.test(message);
  }

  function isOperationCancelled(error: unknown): boolean {
    const message = error instanceof Error ? error.message : String(error);
    return /用户取消|user cancelled|cancelled|canceled/i.test(message);
  }

  async function showOperationMessage(title: string, message: string, type: 'info' | 'warning' | 'error' = 'error'): Promise<void> {
    try {
      if (AppUtils?.UI?.showMessage) {
        await AppUtils.UI.showMessage(title, message, type);
      } else if (electronAPI?.showMessageDialog) {
        await electronAPI.showMessageDialog(title, message, type);
      } else {
        console.error(`[设备操作] ${title}: ${message}`);
      }
    } catch (error) {
      console.error('[设备操作] 显示操作结果失败:', error, message);
    }
  }

  // 初始化命名空间
  if (!AppModules.Devices) {
    AppModules.Devices = {};
  }
  if (!AppModules.Devices.Operations) {
    AppModules.Devices.Operations = {};
  }

  // 格式化/修复成功：完成态挂在对应动作按钮上，刷新列表也不会冲掉
  const DEVICE_ACTION_DONE_MS = 3100;

  function markDeviceActionDone(
    disk: string | undefined,
    action: 'format' | 'repair',
    devicesList: HTMLElement,
    readWriteDevicesList: HTMLElement
  ): void {
    if (!disk) return;
    const doneHints: Record<string, { action: 'format' | 'repair'; until: number }> = AppModules.Devices.doneHints || {};
    AppModules.Devices.doneHints = doneHints;
    const until = Date.now() + DEVICE_ACTION_DONE_MS;
    doneHints[disk] = { action, until };

    window.setTimeout(() => {
      if (doneHints[disk]?.until !== until) return;
      delete doneHints[disk];
      (devicesList as any).__lastStateKey = '';
      const Renderer = AppModules.Devices?.Renderer;
      if (Renderer && typeof Renderer.renderDevices === 'function' && devicesList.isConnected) {
        Renderer.renderDevices(devicesList, readWriteDevicesList);
      }
    }, DEVICE_ACTION_DONE_MS);
  }

  // 自动读写：清理“已尝试”记录（卸载/推出/拔出等生命周期结束时应立即清理）
  function clearAutoMountAttemptedDisk(disk: string | undefined): void {
    try {
      if (!disk) return;
      const attempted = (AppModules.Devices as any).autoMountAttemptedDisks as Set<string> | undefined;
      attempted?.delete(disk);
    } catch {
      // ignore
    }
  }

  // 手动只读列表：设备的稳定标识（优先 volumeUuid，其次 disk）
  function getManualReadOnlyId(device: any): string {
    return device?.volumeUuid || device?.disk;
  }

  function getRepairErrorMessage(error: unknown): string {
    const message = error instanceof Error ? error.message : String(error);
    if (/密码错误|password is incorrect|sorry, try again/i.test(message)) {
      return t('messages.passwordError');
    }
    if (/用户取消|user cancelled|cancelled/i.test(message)) {
      return t('messages.cancelled');
    }

    const separator = message.indexOf(':');
    const code = separator === -1 ? message : message.slice(0, separator);
    const detail = separator === -1 ? '' : message.slice(separator + 1);
    switch (code) {
      case 'REPAIR_INVALID_PATH':
      case 'REPAIR_DEVICE_UNAVAILABLE':
        return t('messages.repairDeviceUnavailable');
      case 'REPAIR_UNMOUNT_FAILED':
        return t('messages.repairUnmountFailed', { error: detail });
      case 'REPAIR_FILESYSTEM_FAILED':
        return t('messages.repairFilesystemFailed', { error: detail });
      case 'REPAIR_REMOUNT_FAILED':
        return t('messages.repairRemountFailed', { error: detail });
      case 'REPAIR_AND_REMOUNT_FAILED': {
        const [repairError, mountError] = detail.split('|', 2);
        return t('messages.repairAndRemountFailed', { error: repairError, mountError });
      }
      default:
        return `${t('messages.repairError')}: ${message}`;
    }
  }

  function getRenameErrorMessage(error: unknown): string {
    const message = error instanceof Error ? error.message : String(error);
    if (/密码错误|password is incorrect|sorry, try again/i.test(message)) {
      return t('messages.passwordError');
    }
    if (/用户取消|user cancelled|cancelled/i.test(message)) {
      return t('messages.cancelled');
    }

    const separator = message.indexOf(':');
    const code = separator === -1 ? message : message.slice(0, separator);
    const detail = separator === -1 ? '' : message.slice(separator + 1);
    switch (code) {
      case 'RENAME_INVALID_PATH':
      case 'RENAME_DEVICE_UNAVAILABLE':
        return t('messages.renameDeviceUnavailable');
      case 'RENAME_INVALID_NAME':
        return t('messages.renameInvalidName');
      case 'RENAME_TOOL_MISSING':
        return t('messages.renameToolMissing');
      case 'RENAME_UNMOUNT_FAILED':
        return t('messages.renameUnmountFailed', { error: detail });
      case 'RENAME_LABEL_FAILED':
        return t('messages.renameFailedNeedChkdsk');
      case 'RENAME_REMOUNT_FAILED':
        return t('messages.renameRemountFailed', { error: detail });
      case 'RENAME_AND_REMOUNT_FAILED': {
        return t('messages.renameFailedNeedChkdsk');
      }
      default:
        return t('messages.renameFailedNeedChkdsk');
    }
  }

  function getFormatErrorMessage(error: unknown): string {
    const message = error instanceof Error ? error.message : String(error);
    if (/密码错误|password is incorrect|sorry, try again/i.test(message)) {
      return t('messages.passwordError');
    }
    if (/用户取消|user cancelled|cancelled/i.test(message)) {
      return t('messages.cancelled');
    }

    const separator = message.indexOf(':');
    const code = separator === -1 ? message : message.slice(0, separator);
    const detail = separator === -1 ? '' : message.slice(separator + 1);
    switch (code) {
      case 'FORMAT_INVALID_PATH':
      case 'FORMAT_DEVICE_UNAVAILABLE':
        return t('messages.formatDeviceUnavailable');
      case 'FORMAT_NOT_MOUNTED':
        return t('messages.formatNotMounted');
      case 'FORMAT_NOT_ALLOWED':
        return t('messages.formatNotAllowed');
      case 'FORMAT_TOOL_MISSING':
        return t('messages.formatToolMissing');
      case 'FORMAT_ERASE_FAILED':
        return t('messages.formatEraseFailed', { error: detail });
      case 'FORMAT_UNMOUNT_FAILED':
        return t('messages.formatUnmountFailed', { error: detail });
      case 'FORMAT_MKNTFS_FAILED':
        return t('messages.formatMkntfsFailed', { error: detail });
      case 'FORMAT_REMOUNT_FAILED':
        return t('messages.formatRemountFailed', { error: detail });
      default:
        return `${t('messages.formatError')}: ${message}`;
    }
  }

  // 记录手动只读设备最后一次出现时间（用于宽限期，避免还原只读的临时卸载被误清）
  const manualLastSeen = (AppModules.Devices as any).manualLastSeen as Map<string, number> || new Map<string, number>();
  (AppModules.Devices as any).manualLastSeen = manualLastSeen;

  // 统一的设备列表刷新函数（确保操作后状态立即更新）
  // 增加重试机制，确保读写状态变化能被及时捕获
  async function refreshDeviceList(devicesList: HTMLElement, retryCount: number = 0): Promise<void> {
    const Refresh = AppModules?.Devices?.Refresh;
    const maxRetries = 2; // 最多重试2次

    try {
      if (Refresh && Refresh.refreshDevices) {
        // 获取当前状态对象（从 devices.js 传入或使用默认）
        const state = (window as any).__devicesState || {
          devices: AppModules.Devices.devices || [],
          lastDeviceCount: 0,
          lastDeviceState: ''
        };
        await Refresh.refreshDevices(devicesList, true, state);

        // 如果是读写转换操作后的刷新，延迟后再次验证状态
        if (retryCount === 0) {
          setTimeout(async () => {
            try {
              // 再次强制刷新，确保状态完全同步
              const latestDevices = await electronAPI.getNTFSDevices(true);
              const currentDevices = AppModules.Devices.devices || [];

              // 检查是否有状态变化（特别是读写状态）
              const hasStateChange = latestDevices.some((newDevice: any) => {
                const oldDevice = currentDevices.find((d: any) => d.disk === newDevice.disk);
                return !oldDevice ||
                       oldDevice.isReadOnly !== newDevice.isReadOnly ||
                       oldDevice.isMounted !== newDevice.isMounted;
              });

              if (hasStateChange) {
                console.log('[设备操作] 检测到状态变化，再次刷新');
                await Refresh.refreshDevices(devicesList, true, state);
              }
            } catch (error) {
              console.warn('[设备操作] 状态验证刷新失败:', error);
            }
          }, 800); // 延迟800ms，给系统足够时间完成状态更新
        }
      } else if ((window as any).refreshDevices) {
        // 降级：使用全局 refreshDevices 函数
        await (window as any).refreshDevices(true);
      }
    } catch (error) {
      console.error('[设备操作] 刷新设备列表失败:', error);
      // 如果失败且还有重试次数，延迟后重试
      if (retryCount < maxRetries) {
        setTimeout(async () => {
          await refreshDeviceList(devicesList, retryCount + 1);
        }, 500);
      }
    }
  }

  // 设备操作功能
  AppModules.Devices.Operations = {
    // 挂载设备
    async mountDevice(
      device: any, // eslint-disable-line @typescript-eslint/no-explicit-any
      devicesList: HTMLElement,
      readWriteDevicesList: HTMLElement,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): Promise<void> {
      const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;

      try {
        // 使用设备工具中的 showLoading，自动兼容托盘窗口和降级逻辑
        if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
          DeviceUtils.showLoading(true);
        }

        const result = await electronAPI.mountDevice(device);

        if (result.success) {
          // 从手动只读列表中移除该设备，允许自动读写功能再次管理它
          try {
            const settings = await electronAPI.getSettings();
            const manuallyReadOnlyDevices = settings.manuallyReadOnlyDevices || [];
            const manualId = getManualReadOnlyId(device);
            const updated = manuallyReadOnlyDevices.filter((id: string) => id !== manualId && id !== device.disk);
            if (updated.length !== manuallyReadOnlyDevices.length) {
              await electronAPI.saveSettings({ manuallyReadOnlyDevices: updated });
            }
            if (manualId) manualLastSeen.delete(manualId);
            manualLastSeen.delete(device.disk);
          } catch (error) {
            console.warn('更新手动只读设备列表失败:', error);
          }

          if (result.result) {
          }
          // 等待一小段时间，确保挂载操作完全完成，标记文件已创建
          await new Promise(resolve => setTimeout(resolve, 500));

          // 强制刷新设备列表（确保状态立即更新，包含重试机制）
          await refreshDeviceList(devicesList, 0);
        } else {
          const errorMessage = result.error || t('messages.mountError');
          if (isPasswordError(errorMessage)) {
            const passwordError = t('messages.passwordError');
            await showOperationMessage(t('messages.mountError'), passwordError, 'warning');
          } else if (isOperationCancelled(errorMessage)) {
          } else {
            await showOperationMessage(t('messages.mountError'), errorMessage);
          }
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        if (isPasswordError(error)) {
          await showOperationMessage(t('messages.mountError'), t('messages.passwordError'), 'warning');
        } else if (!isOperationCancelled(error)) {
          await showOperationMessage(t('messages.mountError'), errorMessage);
        }
      } finally {
        if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
          DeviceUtils.showLoading(false);
        }
      }
    },

    // 重置设备（卸载+修复）
    async resetDevice(
      device: any, // eslint-disable-line @typescript-eslint/no-explicit-any
      devicesList: HTMLElement,
      readWriteDevicesList: HTMLElement,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): Promise<void> {
      try {
        if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
          DeviceUtils.showLoading(true);
        }

        // 在重置之前，先将设备添加到手动只读列表，防止自动读写功能立即将其设置为读写
        // 重置操作和手动设置为只读保持一样的逻辑
        try {
          const settings = await electronAPI.getSettings();
          // 创建新数组，避免直接修改原数组引用
          const manuallyReadOnlyDevices = [...(settings.manuallyReadOnlyDevices || [])];
          const manualId = getManualReadOnlyId(device);
          if (manualId && !manuallyReadOnlyDevices.includes(manualId)) {
            manuallyReadOnlyDevices.push(manualId);
            await electronAPI.saveSettings({ manuallyReadOnlyDevices });
            console.log(`[设备操作] 已将设备 ${device.volumeName} (${manualId}) 添加到手动只读列表（重置操作前），当前列表:`, manuallyReadOnlyDevices);
          } else {
            console.log(`[设备操作] 设备 ${device.volumeName} (${manualId}) 已在手动只读列表中`);
          }
          if (manualId) manualLastSeen.set(manualId, Date.now());
          if (device.disk) manualLastSeen.set(device.disk, Date.now());

          // 设置自动挂载冷却：给重置操作一个窗口期，避免刚点击就被自动读写抢回
          const cooldownMs = 8000; // 8 秒内不触发自动读写
          const autoMountCooldown: Map<string, number> =
            (AppModules.Devices as any).autoMountCooldown || new Map<string, number>();
          (AppModules.Devices as any).autoMountCooldown = autoMountCooldown;
          const until = Date.now() + cooldownMs;
          if (manualId) autoMountCooldown.set(manualId, until);
          if (device.disk) autoMountCooldown.set(device.disk, until);
        } catch (error) {
          console.warn('保存手动只读设备列表失败:', error);
        }

        // 重置操作：清理"已尝试自动挂载"记录，避免后续插回/重新挂载无法再次触发
        clearAutoMountAttemptedDisk(device.disk);

        const result = await electronAPI.resetDevice(device);

        if (result.success) {
          if (result.result) {
          }
          // 等待一小段时间，确保操作完全完成
          await new Promise(resolve => setTimeout(resolve, 1000));

          // 强制刷新设备列表
          await refreshDeviceList(devicesList, 0);
        } else {
          const errorMessage = result.error || t('messages.resetError') || '未知错误';
          if (isPasswordError(errorMessage)) {
            const passwordError = t('messages.passwordError');
            await showOperationMessage(t('messages.resetError') || '重置失败', passwordError, 'warning');
          } else if (isOperationCancelled(errorMessage)) {
          } else {
            await showOperationMessage(t('messages.resetError') || '重置失败', errorMessage);
          }
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        if (isPasswordError(error)) {
          await showOperationMessage(t('messages.resetError') || '重置失败', t('messages.passwordError'), 'warning');
        } else if (!isOperationCancelled(error)) {
          await showOperationMessage(t('messages.resetError') || '重置失败', errorMessage);
        }
      } finally {
        if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
          DeviceUtils.showLoading(false);
        }
      }
    },

    // 修复 NTFS 文件系统
    async repairDevice(
      device: any, // eslint-disable-line @typescript-eslint/no-explicit-any
      devicesList: HTMLElement,
      readWriteDevicesList: HTMLElement,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): Promise<void> {
      if (document.body?.classList.contains('tray-window') && electronAPI?.runDeviceActionInMainWindow) {
        await electronAPI.runDeviceActionInMainWindow({ action: 'repair', device });
        return;
      }

      const title = t('devices.repairConfirm');
      const message = [
        t('devices.repairConfirmNote'),
        t('devices.targetDevice', { name: device.volumeName })
      ].join('\n');
      const confirmed = await AppUtils.UI.showConfirm(title, message, {
        icon: '../imgs/svg/prompt/warning.svg',
        confirmText: t('dialog.continue')
      });
      if (!confirmed) return;

      const showRepairMessage = async (messageTitle: string, messageText: string, type: 'info' | 'warning' | 'error'): Promise<void> => {
        await AppUtils.UI.showMessage(messageTitle, messageText, type);
      };

      try {
        if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
          DeviceUtils.showLoading(true);
        }


        const autoMountCooldown: Map<string, number> =
          (AppModules.Devices as any).autoMountCooldown || new Map<string, number>();
        (AppModules.Devices as any).autoMountCooldown = autoMountCooldown;
        const cooldownUntil = Date.now() + 120000;
        const manualId = getManualReadOnlyId(device);
        if (manualId) autoMountCooldown.set(manualId, cooldownUntil);
        if (device.disk) autoMountCooldown.set(device.disk, cooldownUntil);
        clearAutoMountAttemptedDisk(device.disk);

        const result = await electronAPI.repairDevice(device);
        if (result.success) {
          const successMessage = t('messages.repairSuccess', {
            name: device.volumeName,
            mode: t(device.isReadOnly ? 'devices.readOnly' : 'devices.readWrite')
          });
          markDeviceActionDone(device.disk, 'repair', devicesList, readWriteDevicesList);
          await new Promise(resolve => setTimeout(resolve, 1000));
          await refreshDeviceList(devicesList, 0);
          if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
            DeviceUtils.showLoading(false);
          }
        } else {
          const errorMessage = getRepairErrorMessage(result.error || t('messages.unknownError'));
          const errorType = errorMessage === t('messages.cancelled') ? 'info' :
            errorMessage === t('messages.passwordError') ? 'warning' : 'error';
          await new Promise(resolve => setTimeout(resolve, 1000));
          await refreshDeviceList(devicesList, 0);
          if (errorType === 'error' || errorType === 'warning') {
            await showRepairMessage(t('messages.repairFailedTitle'), errorMessage, errorType);
          }
        }
      } catch (error) {
        const errorMessage = getRepairErrorMessage(error);
        const errorType = errorMessage === t('messages.cancelled') ? 'info' :
          errorMessage === t('messages.passwordError') ? 'warning' : 'error';
        if (errorType === 'error' || errorType === 'warning') {
          await showRepairMessage(t('messages.repairFailedTitle'), errorMessage, errorType);
        }
      } finally {
        if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
          DeviceUtils.showLoading(false);
        }
      }
    },

    async renameDevice(
      device: any, // eslint-disable-line @typescript-eslint/no-explicit-any
      devicesList: HTMLElement,
      readWriteDevicesList: HTMLElement,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): Promise<void> {
      if (document.body?.classList.contains('tray-window') && electronAPI?.runDeviceActionInMainWindow) {
        await electronAPI.runDeviceActionInMainWindow({ action: 'rename', device });
        return;
      }

      const title = t('devices.renameTitle');
      const message = [
        t('devices.targetDevice', { name: device.volumeName }),
        t('devices.renameNote')
      ].join('\n');
      const placeholder = t('devices.renamePlaceholder');
      const newName = await AppUtils.UI.showPrompt(title, message, device.volumeName, placeholder, {
        icon: '../imgs/svg/prompt/important.svg'
      });
      if (newName === null || newName === false) return;

      const trimmedName = String(newName).trim();
      if (!trimmedName) {
        await showOperationMessage(t('messages.renameFailedTitle'), t('messages.renameInvalidName'), 'warning');
        return;
      }
      if (trimmedName === device.volumeName) {
        return;
      }
      if (trimmedName.length > 32 || /[\\/:*?"<>|]/.test(trimmedName)) {
        await showOperationMessage(t('messages.renameFailedTitle'), t('messages.renameInvalidName'), 'warning');
        return;
      }

      try {
        if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
          DeviceUtils.showLoading(true);
        }


        const autoMountCooldown: Map<string, number> =
          (AppModules.Devices as any).autoMountCooldown || new Map<string, number>();
        (AppModules.Devices as any).autoMountCooldown = autoMountCooldown;
        const cooldownUntil = Date.now() + 120000;
        const manualId = getManualReadOnlyId(device);
        if (manualId) autoMountCooldown.set(manualId, cooldownUntil);
        if (device.disk) autoMountCooldown.set(device.disk, cooldownUntil);
        clearAutoMountAttemptedDisk(device.disk);

        const result = await electronAPI.renameDevice(device, trimmedName);
        if (result.success) {
          const successMessage = t('messages.renameSuccess', {
            name: device.volumeName,
            newName: trimmedName
          });
          await new Promise(resolve => setTimeout(resolve, 1000));
          await refreshDeviceList(devicesList, 0);
          if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
            DeviceUtils.showLoading(false);
          }
          const renameButton = Array.from(devicesList.querySelectorAll<HTMLElement>('.rename-btn'))
            .find(button => button.dataset.disk === device.disk);
          if (renameButton) {
            await AppUtils.UI.showSuccessAnimation(successMessage, renameButton);
          }
        } else {
          const errorMessage = getRenameErrorMessage(result.error || t('messages.unknownError'));
          const errorType = errorMessage === t('messages.cancelled') ? 'info' :
            errorMessage === t('messages.passwordError') ? 'warning' : 'error';
          await new Promise(resolve => setTimeout(resolve, 1000));
          await refreshDeviceList(devicesList, 0);
          if (errorType === 'error' || errorType === 'warning') {
            await showOperationMessage(t('messages.renameFailedTitle'), errorMessage, errorType);
          }
        }
      } catch (error) {
        const errorMessage = getRenameErrorMessage(error);
        const errorType = errorMessage === t('messages.cancelled') ? 'info' :
          errorMessage === t('messages.passwordError') ? 'warning' : 'error';
        if (errorType === 'error' || errorType === 'warning') {
          await showOperationMessage(t('messages.renameFailedTitle'), errorMessage, errorType);
        }
      } finally {
        if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
          DeviceUtils.showLoading(false);
        }
      }
    },

    async formatDevice(
      device: any, // eslint-disable-line @typescript-eslint/no-explicit-any
      devicesList: HTMLElement,
      readWriteDevicesList: HTMLElement,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): Promise<void> {
      if (document.body?.classList.contains('tray-window') && electronAPI?.runDeviceActionInMainWindow) {
        await electronAPI.runDeviceActionInMainWindow({ action: 'format', device });
        return;
      }

      const title = t('devices.formatConfirm');
      const message = [
        t('devices.targetDevice', { name: device.volumeName }),
        t('devices.formatConfirmNote')
      ].join('\n');
      const confirmed = await AppUtils.UI.showConfirm(title, message, {
        icon: '../imgs/svg/prompt/danger.svg'
      });
      if (!confirmed) return;

      try {
        if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
          DeviceUtils.showLoading(true);
        }


        const autoMountCooldown: Map<string, number> =
          (AppModules.Devices as any).autoMountCooldown || new Map<string, number>();
        (AppModules.Devices as any).autoMountCooldown = autoMountCooldown;
        const cooldownUntil = Date.now() + 120000;
        const manualId = getManualReadOnlyId(device);
        if (manualId) autoMountCooldown.set(manualId, cooldownUntil);
        if (device.disk) autoMountCooldown.set(device.disk, cooldownUntil);
        clearAutoMountAttemptedDisk(device.disk);

        const result = await electronAPI.formatDevice(device);
        if (result.success) {
          const successMessage = t('messages.formatSuccess', { name: device.volumeName });
          markDeviceActionDone(device.disk, 'format', devicesList, readWriteDevicesList);
          await new Promise(resolve => setTimeout(resolve, 1000));
          await refreshDeviceList(devicesList, 0);
          if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
            DeviceUtils.showLoading(false);
          }
        } else {
          const errorMessage = getFormatErrorMessage(result.error || t('messages.unknownError'));
          const errorType = errorMessage === t('messages.cancelled') ? 'info' :
            errorMessage === t('messages.passwordError') ? 'warning' : 'error';
          await new Promise(resolve => setTimeout(resolve, 1000));
          await refreshDeviceList(devicesList, 0);
          if (errorType === 'error' || errorType === 'warning') {
            await showOperationMessage(t('messages.formatFailedTitle'), errorMessage, errorType);
          }
        }
      } catch (error) {
        const errorMessage = getFormatErrorMessage(error);
        const errorType = errorMessage === t('messages.cancelled') ? 'info' :
          errorMessage === t('messages.passwordError') ? 'warning' : 'error';
        if (errorType === 'error' || errorType === 'warning') {
          await showOperationMessage(t('messages.formatFailedTitle'), errorMessage, errorType);
        }
      } finally {
        if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
          DeviceUtils.showLoading(false);
        }
      }
    },

    // 还原设备为只读模式
    async restoreToReadOnly(
      device: any, // eslint-disable-line @typescript-eslint/no-explicit-any
      devicesList: HTMLElement,
      readWriteDevicesList: HTMLElement,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): Promise<void> {
      const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;

      try {
        if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
          DeviceUtils.showLoading(true);
        }

        // 在还原为只读之前，先将设备添加到手动只读列表，防止自动读写功能立即将其设置为读写
        try {
          const settings = await electronAPI.getSettings();
          // 创建新数组，避免直接修改原数组引用
          const manuallyReadOnlyDevices = [...(settings.manuallyReadOnlyDevices || [])];
          const manualId = getManualReadOnlyId(device);
          if (manualId && !manuallyReadOnlyDevices.includes(manualId)) {
            manuallyReadOnlyDevices.push(manualId);
            await electronAPI.saveSettings({ manuallyReadOnlyDevices });
            console.log(`[设备操作] 已将设备 ${device.volumeName} (${manualId}) 添加到手动只读列表（操作前），当前列表:`, manuallyReadOnlyDevices);
          } else {
            console.log(`[设备操作] 设备 ${device.volumeName} (${manualId}) 已在手动只读列表中`);
          }
          if (manualId) manualLastSeen.set(manualId, Date.now());
          if (device.disk) manualLastSeen.set(device.disk, Date.now());

          // 设置自动挂载冷却：给手动只读操作一个窗口期，避免刚点击就被自动读写抢回
          const cooldownMs = 8000; // 8 秒内不触发自动读写
          const autoMountCooldown: Map<string, number> =
            (AppModules.Devices as any).autoMountCooldown || new Map<string, number>();
          (AppModules.Devices as any).autoMountCooldown = autoMountCooldown;
          const until = Date.now() + cooldownMs;
          if (manualId) autoMountCooldown.set(manualId, until);
          if (device.disk) autoMountCooldown.set(device.disk, until);
        } catch (error) {
          console.warn('保存手动只读设备列表失败:', error);
        }

        // 还原为只读：清理“已尝试自动挂载”记录，避免后续插回/重新挂载无法再次触发
        clearAutoMountAttemptedDisk(device.disk);

        const result = await electronAPI.restoreToReadOnly(device);

        if (result.success) {

          if (result.result) {
          }
          // 等待一小段时间，让系统重新挂载（restoreToReadOnly 需要更长时间）
          await new Promise(resolve => setTimeout(resolve, 1500));

          // 强制刷新设备列表（确保状态立即更新，包含重试机制）
          // restoreToReadOnly 操作后需要更仔细的状态检测
          await refreshDeviceList(devicesList, 0);

          // 额外延迟验证，确保只读状态完全同步
          setTimeout(async () => {
            try {
              const latestDevices = await electronAPI.getNTFSDevices(true);
              const Refresh = AppModules?.Devices?.Refresh;
              if (Refresh && Refresh.refreshDevices) {
                const state = (window as any).__devicesState || {
                  devices: AppModules.Devices.devices || [],
                  lastDeviceCount: 0,
                  lastDeviceState: ''
                };
                await Refresh.refreshDevices(devicesList, true, state);
              }
            } catch (error) {
              console.warn('[设备操作] restoreToReadOnly 状态验证失败:', error);
            }
          }, 1000);
        } else {
          const errorMessage = result.error || t('messages.restoreError');
          if (isPasswordError(errorMessage)) {
            const passwordError = t('messages.passwordError');
            await showOperationMessage(t('messages.restoreError'), passwordError, 'warning');
          } else if (isOperationCancelled(errorMessage)) {
          } else {
            await showOperationMessage(t('messages.restoreError'), errorMessage);
          }
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        if (isPasswordError(error)) {
          await showOperationMessage(t('messages.restoreError'), t('messages.passwordError'), 'warning');
        } else if (!isOperationCancelled(error)) {
          await showOperationMessage(t('messages.restoreError'), errorMessage);
        }
      } finally {
        if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
          DeviceUtils.showLoading(false);
        }
      }
    },

    // 还原所有设备为只读模式
    async restoreAllToReadOnly(
      devicesList: HTMLElement,
      readWriteDevicesList: HTMLElement,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): Promise<void> {
      if (document.body?.classList.contains('tray-window') && electronAPI?.runDeviceActionInMainWindow) {
        await electronAPI.runDeviceActionInMainWindow({ action: 'restore-all' });
        return;
      }

      // 获取所有已挂载为读写模式的设备
      const devices = AppModules.Devices.devices || [];
      const readWriteDevices = devices.filter((d: any) => !d.isReadOnly && !d.isUnmounted);

      if (readWriteDevices.length === 0) {
        return;
      }

      const deviceNames = readWriteDevices.map((d: any) => d.volumeName).join('、');
      const title = t('devices.restoreAllReadOnly') + '？';
      const message = `将还原以下设备：\n${deviceNames}\n\n*注意：*\n* 设备将恢复为只读模式，无法写入文件\n* 已写入的文件不会丢失，但后续只能读取`;

      const confirmed = await AppUtils.UI.showConfirm(title, message);
      if (!confirmed) {
        return;
      }

      // 将所有设备添加到手动只读列表
      try {
        const settings = await electronAPI.getSettings();
        const manuallyReadOnlyDevices = settings.manuallyReadOnlyDevices || [];
        const deviceDisks = readWriteDevices.map((d: any) => d.disk);
        const newManuallyReadOnlyDevices = [...new Set([...manuallyReadOnlyDevices, ...deviceDisks])];
        await electronAPI.saveSettings({ manuallyReadOnlyDevices: newManuallyReadOnlyDevices });
      } catch (error) {
        console.warn('保存手动只读设备列表失败:', error);
      }

      const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;

      try {
        if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
          DeviceUtils.showLoading(true);
        }

        let successCount = 0;
        let failCount = 0;
        const failureMessages: string[] = [];
        let wasCancelled = false;
        let hadPasswordError = false;

        // 逐个还原设备
        for (const device of readWriteDevices) {
          try {
            const result = await electronAPI.restoreToReadOnly(device);

            if (result.success) {
              successCount++;
              if (result.result) {
              }
            } else {
              failCount++;
              const errorMessage = result.error || '未知错误';
              failureMessages.push(`${device.volumeName}: ${isPasswordError(errorMessage) ? t('messages.passwordError') : errorMessage}`);
              hadPasswordError = isPasswordError(errorMessage);
              wasCancelled = isOperationCancelled(errorMessage);
              if (hadPasswordError || wasCancelled) break;
            }
          } catch (error) {
            failCount++;
            const errorMessage = error instanceof Error ? error.message : String(error);
            failureMessages.push(`${device.volumeName}: ${isPasswordError(error) ? t('messages.passwordError') : errorMessage}`);
            hadPasswordError = isPasswordError(error);
            wasCancelled = isOperationCancelled(error);
            if (hadPasswordError || wasCancelled) break;
          }
        }

        // 等待一小段时间，让系统重新挂载
        await new Promise(resolve => setTimeout(resolve, 1500));

        // 刷新设备列表（确保状态立即更新）
        await refreshDeviceList(devicesList);

        // 显示总结
        if (successCount > 0) {
        }
        if (failCount > 0) {
          if (hadPasswordError) {
            await showOperationMessage(t('devices.restoreAllReadOnly'), failureMessages.join('\n'), 'warning');
          } else if (!wasCancelled) {
            await showOperationMessage(t('devices.restoreAllReadOnly'), failureMessages.join('\n'));
          }
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
      } finally {
        if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
          DeviceUtils.showLoading(false);
        }
      }
    },

    // 卸载设备
    async unmountDevice(
      device: any, // eslint-disable-line @typescript-eslint/no-explicit-any
      devicesList: HTMLElement,
      readWriteDevicesList: HTMLElement,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): Promise<void> {
      const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;

      try {
        if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
          DeviceUtils.showLoading(true);
        }

        // 卸载：立即清理“已尝试自动挂载”记录
        clearAutoMountAttemptedDisk(device.disk);

        const result = await electronAPI.unmountDevice(device);

        if (result.success) {
          if (result.result) {
          }
          await AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText);
        } else {
          if (result.error?.includes('密码错误')) {
          } else if (result.error?.includes('用户取消')) {
          }
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
      } finally {
        if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
          DeviceUtils.showLoading(false);
        }
      }
    },

    // 一键配置所有设备可读写
    async mountAllDevices(
      devicesList: HTMLElement,
      readWriteDevicesList: HTMLElement,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): Promise<void> {
      if (document.body?.classList.contains('tray-window') && electronAPI?.runDeviceActionInMainWindow) {
        await electronAPI.runDeviceActionInMainWindow({ action: 'mount-all' });
        return;
      }

      // 获取所有只读设备和未挂载的设备
      const devices = AppModules.Devices.devices || [];
      const readOnlyDevices = devices.filter((d: any) => d.isReadOnly || d.isUnmounted);

      if (readOnlyDevices.length === 0) {
        return;
      }

      const deviceNames = readOnlyDevices.map((d: any) => d.volumeName).join('、');
      const title = t('devices.mountAll') + '？';
      const message = `将配置以下设备：\n${deviceNames}\n\n*注意：*\n* 配置后设备将支持读写，可以正常保存文件\n* 如果设备之前在 Windows 上使用过，可能需要先在 Windows 上完全关闭后再试`;

      const confirmed = await AppUtils.UI.showConfirm(title, message);
      if (!confirmed) {
        return;
      }

      const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;

      try {
        if (DeviceUtils && typeof DeviceUtils.showLoading === 'function') {
          DeviceUtils.showLoading(true);
        }

        let successCount = 0;
        let failCount = 0;

        // 逐个配置设备
        for (const device of readOnlyDevices) {
          try {
            const result = await electronAPI.mountDevice(device);

            if (result.success) {
              successCount++;
              if (result.result) {
              }
            } else {
              failCount++;
            }
          } catch (error) {
            failCount++;
            const errorMessage = error instanceof Error ? error.message : String(error);
          }
        }

        // 刷新设备列表（确保状态立即更新）
        await refreshDeviceList(devicesList);

        // 显示总结
        if (successCount > 0) {
        }
        if (failCount > 0) {
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
      } finally {
        AppUtils.UI.showLoading(loadingOverlay, false);
      }
    },

    // 卸载所有NTFS设备
    async unmountAllDevices(
      devicesList: HTMLElement,
      readWriteDevicesList: HTMLElement,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): Promise<void> {
      // 获取所有已挂载的设备（排除已卸载的设备）
      const devices = AppModules.Devices.devices || [];
      const mountedDevices = devices.filter((d: any) => !d.isUnmounted);

      if (mountedDevices.length === 0) {
        return;
      }

      const deviceNames = mountedDevices.map((d: any) => d.volumeName).join('、');
      const title = '确定要卸载所有已挂载的 NTFS 设备吗？';
      const message = `将卸载以下设备：\n${deviceNames}\n\n*注意：*\n* 卸载后设备将无法访问，需要重新挂载才能使用\n* 请确保没有程序正在使用这些设备`;

      const confirmed = await AppUtils.UI.showConfirm(title, message);
      if (!confirmed) {
        return;
      }

      const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;

      try {
        AppUtils.UI.showLoading(loadingOverlay, true);

        let successCount = 0;
        let failCount = 0;

        // 逐个卸载设备
        for (const device of mountedDevices) {
          try {
            // 卸载：立即清理“已尝试自动挂载”记录
            clearAutoMountAttemptedDisk(device.disk);
            const result = await electronAPI.unmountDevice(device);

            if (result.success) {
              successCount++;
              if (result.result) {
              }
            } else {
              failCount++;
            }
          } catch (error) {
            failCount++;
            const errorMessage = error instanceof Error ? error.message : String(error);
          }
        }

        // 刷新设备列表（确保状态立即更新）
        await refreshDeviceList(devicesList);

        // 显示总结
        if (successCount > 0) {
        }
        if (failCount > 0) {
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
      } finally {
        AppUtils.UI.showLoading(loadingOverlay, false);
      }
    },

    // 推出设备
    async ejectDevice(
      device: any, // eslint-disable-line @typescript-eslint/no-explicit-any
      devicesList: HTMLElement,
      readWriteDevicesList: HTMLElement,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): Promise<void> {
      try {

        // 推出：立即清理“已尝试自动挂载”记录
        clearAutoMountAttemptedDisk(device.disk);

        const result = await electronAPI.ejectDevice(device);

        if (result.success) {
          if (result.result) {
          }
          // 等待一小段时间，让系统完全断开设备
          await new Promise(resolve => setTimeout(resolve, 1000));
          await AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText);
        } else {
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
      }
    },

    // 推出所有设备
    async ejectAllDevices(
      devicesList: HTMLElement,
      readWriteDevicesList: HTMLElement,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): Promise<void> {
      if (document.body?.classList.contains('tray-window') && electronAPI?.runDeviceActionInMainWindow) {
        await electronAPI.runDeviceActionInMainWindow({ action: 'eject-all' });
        return;
      }

      // 获取所有已挂载的设备
      const devices = AppModules.Devices.devices || [];
      const mountedDevices = devices.filter((d: any) => !d.isUnmounted);

      // 获取翻译函数
      const t = AppUtils && AppUtils.I18n ? AppUtils.I18n.t : ((key: string, params?: Record<string, string | number>) => key);

      if (mountedDevices.length === 0) {
        return;
      }

      const deviceNames = mountedDevices.map((d: any) => d.volumeName).join('、');
      const title = t('devices.ejectAllConfirm');
      const message = t('devices.ejectAllConfirmNote', { devices: deviceNames });

      const confirmed = await AppUtils.UI.showConfirm(title, message);
      if (!confirmed) {
        return;
      }

      try {

        let successCount = 0;
        let failCount = 0;

        // 逐个推出设备
        for (const device of mountedDevices) {
          try {
            // 推出：立即清理“已尝试自动挂载”记录
            clearAutoMountAttemptedDisk(device.disk);
            const result = await electronAPI.ejectDevice(device);

            if (result.success) {
              successCount++;
              if (result.result) {
              }
            } else {
              failCount++;
            }
          } catch (error) {
            failCount++;
            const errorMessage = error instanceof Error ? error.message : String(error);
          }
        }

        // 等待一小段时间，让系统完全断开设备
        await new Promise(resolve => setTimeout(resolve, 1000));

        // 刷新设备列表（确保状态立即更新）
        await AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText);

        // 显示总结
        if (successCount > 0) {
        }
        if (failCount > 0) {
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
      }
    }
  };

})();
