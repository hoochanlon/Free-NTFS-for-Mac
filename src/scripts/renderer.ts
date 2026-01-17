// 主入口文件 - 初始化所有模块
// 注意：不使用 import，避免生成 CommonJS 代码（浏览器环境不支持）
// 所有模块通过全局命名空间 AppUtils 和 AppModules 访问

(function() {
  'use strict';

  // 获取全局命名空间（在运行时可用）
  const AppUtils = (window as any).AppUtils;
  const AppModules = (window as any).AppModules;

  // 检查是否已经初始化（在函数开始就检查）
  if (window.__rendererInitialized) {
    console.warn('renderer.ts 已经初始化，跳过重复执行');
    return;
  }

  // 立即标记为已初始化，防止并发执行
  window.__rendererInitialized = true;

  // 检查 electronAPI 是否已存在
  if (typeof window.electronAPI === 'undefined') {
    console.error('electronAPI 未定义，请检查 preload.js 是否正确加载');
    // 创建一个空对象避免后续错误
    window.electronAPI = {} as any;
  }

  // DOM 元素
  const statusIndicator = document.getElementById('statusIndicator')!;
  const statusText = statusIndicator.querySelector('.status-text') as HTMLElement;
  const statusDot = statusIndicator.querySelector('.status-dot') as HTMLElement;
  const depsList = document.getElementById('depsList')!;
  const checkDepsBtn = document.getElementById('checkDepsBtn') as HTMLButtonElement;
  const devicesList = document.getElementById('devicesList')!;
  // readWriteDevicesList 已整合到 devicesList 中，保留变量以兼容现有代码
  const readWriteDevicesList = devicesList;
  const refreshDevicesBtn = document.getElementById('refreshDevicesBtn') as HTMLButtonElement;
  const mountAllBtn = document.getElementById('mountAllBtn') as HTMLButtonElement;
  const unmountAllBtn = document.getElementById('unmountAllBtn') as HTMLButtonElement;
  const restoreAllReadOnlyBtn = document.getElementById('restoreAllReadOnlyBtn') as HTMLButtonElement;
  const ejectAllBtn = document.getElementById('ejectAllBtn') as HTMLButtonElement;
  const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;
  const logContainer = document.getElementById('logContainer')!;
  const clearLogBtn = document.getElementById('clearLogBtn') as HTMLButtonElement;
  const themeToggleButton = document.getElementById('theme-toggle-btn') as HTMLButtonElement;
  const docBody = document.body;
  const helpTab = document.getElementById('helpTab') as HTMLElement;
  const protectBtn = document.getElementById('protectBtn') as HTMLButtonElement;
  const quitBtn = document.getElementById('quitBtn') as HTMLButtonElement;
  const caffeinateBtn = document.getElementById('caffeinateBtn') as HTMLButtonElement | null;
  const autoMountTitlebarBtn = document.getElementById('autoMountTitlebarBtn') as HTMLButtonElement | null;
  const trayModeTitlebarBtn = document.getElementById('trayModeTitlebarBtn') as HTMLButtonElement | null;

  // 自动刷新间隔
  let autoRefreshInterval: NodeJS.Timeout | null = null;

  // 初始化
  document.addEventListener('DOMContentLoaded', async () => {
    // 初始化主题（在 DOM 加载前设置，避免闪烁）
    AppUtils.Theme.initializeTheme(docBody, themeToggleButton);

    // 初始化标签页
    AppModules.Tabs.initTabs(logContainer, helpTab);

    // 初始化设置
    await AppModules.Settings.initSettings();

    // 初始化功能模块
    // 检查并执行每天重置日志，并清理过期日志
    AppUtils.Logs.checkAndResetDaily();
    // 清理超过一个月的日志（getLogs 内部会自动清理）
    AppUtils.Logs.getLogs().catch((err: any) => console.error('加载日志失败:', err));

    // 根据设置打开启动标签页
    try {
      const settings = await window.electronAPI.getSettings();
      if (settings.startupTab) {
        AppModules.Tabs.switchToTab(settings.startupTab, logContainer, helpTab);
      } else {
        // 如果没有设置启动标签页，默认显示第一个标签页，并确保日志已渲染
        const firstTab = document.querySelector('.tab') as HTMLElement;
        if (firstTab) {
          const tabName = firstTab.getAttribute('data-tab');
          if (tabName) {
            AppModules.Tabs.switchToTab(tabName, logContainer, helpTab);
          }
        }
      }

      // 确保如果当前在日志标签页，日志已正确渲染
      const logsTab = document.getElementById('logsTab');
      if (logsTab && logsTab.classList.contains('active')) {
        // 延迟一点渲染，确保 DOM 已完全加载
        setTimeout(() => {
          AppUtils.Logs.renderLogs(logContainer, true).catch((err: any) => console.error('渲染日志失败:', err));
        }, 100);
      }
    } catch (error) {
      console.error('加载启动标签页设置失败:', error);
      // 即使出错也尝试渲染日志（如果当前在日志标签页）
      const logsTab = document.getElementById('logsTab');
      if (logsTab && logsTab.classList.contains('active')) {
        setTimeout(() => {
          AppUtils.Logs.renderLogs(logContainer, true).catch((err: any) => console.error('渲染日志失败:', err));
        }, 100);
      }
    }

    AppModules.Dependencies.checkDependencies(
      depsList,
      loadingOverlay,
      statusDot,
      statusText
    );
    AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText);
    startAutoRefresh();

    // 初始化时加载指南手册的 markdown 内容（会自动根据当前语言加载对应文件）
    if (helpTab) {
      AppUtils.Markdown.loadMarkdown('help.md', helpTab);
    }

    // 获取翻译函数
    const getT = () => {
      return AppUtils && AppUtils.I18n && AppUtils.I18n.t
        ? AppUtils.I18n.t
        : ((key: string) => key);
    };

    // 状态锁定功能
    let isLocked = false;
    let longPressTimer: NodeJS.Timeout | null = null;
    const LONG_PRESS_DURATION = 3000; // 3秒

    // 更新锁定状态的视觉反馈
    const updateLockState = () => {
      if (protectBtn) {
        if (isLocked) {
          protectBtn.classList.add('locked');
          protectBtn.title = '状态已锁定（长按3秒解锁）';
        } else {
          protectBtn.classList.remove('locked');
          protectBtn.title = '状态锁定（长按3秒锁定）';
        }
      }

      // 更新按钮禁用状态
      if (autoMountTitlebarBtn) {
        autoMountTitlebarBtn.disabled = isLocked;
      }
      if (trayModeTitlebarBtn) {
        trayModeTitlebarBtn.disabled = isLocked;
      }
      if (caffeinateBtn) {
        caffeinateBtn.disabled = isLocked;
      }
    };

    // 初始化保护按钮
    if (protectBtn) {
      // 鼠标按下事件
      protectBtn.addEventListener('mousedown', () => {
        longPressTimer = setTimeout(() => {
          isLocked = !isLocked;
          updateLockState();
          const t = getT();
          const message = isLocked
            ? (t('app.protectLocked') || '状态已锁定')
            : (t('app.protectUnlocked') || '状态已解锁');
          AppUtils.Logs.addLog(message, 'info').catch(console.error);
          longPressTimer = null;
        }, LONG_PRESS_DURATION);
      });

      // 鼠标释放事件
      protectBtn.addEventListener('mouseup', () => {
        if (longPressTimer) {
          clearTimeout(longPressTimer);
          longPressTimer = null;
        }
      });

      // 鼠标离开事件（防止拖拽时触发）
      protectBtn.addEventListener('mouseleave', () => {
        if (longPressTimer) {
          clearTimeout(longPressTimer);
          longPressTimer = null;
        }
      });

      // 触摸事件支持（移动端）
      protectBtn.addEventListener('touchstart', (e) => {
        e.preventDefault();
        longPressTimer = setTimeout(() => {
          isLocked = !isLocked;
          updateLockState();
          const t = getT();
          const message = isLocked
            ? (t('app.protectLocked') || '状态已锁定')
            : (t('app.protectUnlocked') || '状态已解锁');
          AppUtils.Logs.addLog(message, 'info').catch(console.error);
          longPressTimer = null;
        }, LONG_PRESS_DURATION);
      });

      protectBtn.addEventListener('touchend', (e) => {
        e.preventDefault();
        if (longPressTimer) {
          clearTimeout(longPressTimer);
          longPressTimer = null;
        }
      });

      protectBtn.addEventListener('touchcancel', () => {
        if (longPressTimer) {
          clearTimeout(longPressTimer);
          longPressTimer = null;
        }
      });

      // 初始化锁定状态
      updateLockState();
    }

    // 初始化退出按钮（使用统一 confirm-dialog 样式）
    if (quitBtn) {
      quitBtn.addEventListener('click', async () => {
        try {
          const t = AppUtils && AppUtils.I18n ? AppUtils.I18n.t : ((key: string) => key);
          const title = t('tray.quitConfirmTitle') || '确认退出';
          const message = t('tray.quitConfirmMessage') || '确定要退出应用吗？';

          if (AppUtils && AppUtils.UI && typeof AppUtils.UI.showConfirm === 'function') {
            const confirmed = await AppUtils.UI.showConfirm(title, message);
            if (confirmed) {
              await window.electronAPI.quitApp();
            }
          } else {
            // 降级：直接退出（极端情况下）
            const confirmed = window.confirm(message);
            if (confirmed) {
              await window.electronAPI.quitApp();
            }
          }
        } catch (error) {
          console.error('退出应用失败:', error);
        }
      });
    }

    // 监听菜单中的关于对话框事件
    if (window.electronAPI && window.electronAPI.onShowAboutDialog) {
      window.electronAPI.onShowAboutDialog(async () => {
        if (AppUtils && AppUtils.UI && AppUtils.UI.showAbout) {
          await AppUtils.UI.showAbout();
        }
      });
    }

    // 更新设置页面标签文本，显示"（已启用）"
    const updateSettingLabel = (checkboxId: string, i18nKey: string) => {
      const checkbox = document.getElementById(checkboxId) as HTMLInputElement | null;
      if (!checkbox) return;

      const label = checkbox.closest('.setting-item')?.querySelector('label[for="' + checkboxId + '"]') as HTMLLabelElement | null;
      if (!label) return;

      const t = AppUtils && AppUtils.I18n && AppUtils.I18n.t ? AppUtils.I18n.t : ((key: string) => key);
      const baseText = t(i18nKey) || '';
      const enabledText = t('settings.enabled') || '（已启用）';

      // 直接使用国际化文本，不依赖当前文本内容
      if (checkbox.checked) {
        label.textContent = baseText + enabledText;
      } else {
        label.textContent = baseText;
      }
    };

    // 更新标题栏按钮的title提示，显示"（已启用）"
    const updateTitlebarButtonTitle = (button: HTMLElement | null, i18nKey: string, isEnabled: boolean) => {
      if (!button) return;
      const t = AppUtils && AppUtils.I18n && AppUtils.I18n.t ? AppUtils.I18n.t : ((key: string) => key);
      const baseText = t(i18nKey) || '';
      const enabledText = t('settings.enabled') || '（已启用）';
      if (isEnabled) {
        button.setAttribute('title', baseText + enabledText);
      } else {
        button.setAttribute('title', baseText);
      }
    };

    // 更新标题栏自动读写按钮状态
    const updateAutoMountTitlebarButton = async () => {
      if (!autoMountTitlebarBtn) return;
      try {
        const settings = await window.electronAPI.getSettings();
        const isEnabled = settings.autoMount || false;
        if (isEnabled) {
          autoMountTitlebarBtn.classList.add('active');
        } else {
          autoMountTitlebarBtn.classList.remove('active');
        }
        updateTitlebarButtonTitle(autoMountTitlebarBtn, 'devices.autoMount', isEnabled);
      } catch (error) {
        console.error('获取自动挂载设置失败:', error);
      }
    };

    // 初始化自动读写功能
    await updateAutoMountTitlebarButton();

    // 标题栏自动读写按钮点击事件
    if (autoMountTitlebarBtn) {
      autoMountTitlebarBtn.addEventListener('click', async () => {
        if (isLocked) {
          const t = getT();
          await AppUtils.Logs.addLog(t('app.protectLockedMessage') || '状态已锁定，无法修改', 'warning');
          return;
        }
        try {
          const settings = await window.electronAPI.getSettings();
          const newValue = !settings.autoMount;
          await window.electronAPI.saveSettings({ autoMount: newValue });
          await updateAutoMountTitlebarButton();
        } catch (error) {
          console.error('切换自动挂载设置失败:', error);
        }
      });
    }

    // 防止休眠按钮（标题栏 + 主界面按钮）
    // 移除updateMainCaffeinateButtonState，不再需要更新设置页面的复选框

    const updateCaffeinateButtonState = async () => {
      if (!caffeinateBtn) return;
      try {
        const t = getT();
        const isActive = await window.electronAPI.caffeinateStatus();
        if (isActive) {
          caffeinateBtn.classList.add('active');
        } else {
          caffeinateBtn.classList.remove('active');
        }
        updateTitlebarButtonTitle(caffeinateBtn, 'tray.preventSleep', isActive);
      } catch (error) {
        console.error('获取防止休眠状态失败:', error);
      }
    };

    const syncCaffeinateButtons = async () => {
      await updateCaffeinateButtonState();
    };

    const handleCaffeinateToggle = async () => {
      if (isLocked) {
        const t = getT();
        await AppUtils.Logs.addLog(t('app.protectLockedMessage') || '状态已锁定，无法修改', 'warning');
        return;
      }
      try {
        const result = await window.electronAPI.caffeinateToggle();
        if (result.success) {
          // 保存状态到设置
          await window.electronAPI.saveSettings({ preventSleep: result.isActive });
          await syncCaffeinateButtons();
          const t = getT();
          const message = result.isActive
            ? t('tray.preventSleepEnabled')
            : t('tray.preventSleepDisabled');
          await AppUtils.Logs.addLog(message, result.isActive ? 'success' : 'info');
        } else {
          console.error('切换防止休眠状态失败:', result.error);
          const t = getT();
          await AppUtils.Logs.addLog(`${t('tray.preventSleep')}操作失败: ${result.error || t('devices.unknownError') || '未知错误'}`, 'error');
        }
      } catch (error) {
        console.error('防止休眠操作失败:', error);
        const t = getT();
        await AppUtils.Logs.addLog(`${t('tray.preventSleep')}操作失败: ${error instanceof Error ? error.message : String(error)}`, 'error');
      }
    };

    // 初始化时检查设置并恢复禁止休眠状态
    const initPreventSleep = async () => {
      try {
        const settings = await window.electronAPI.getSettings();
        const shouldBeActive = settings.preventSleep || false;
        const currentStatus = await window.electronAPI.caffeinateStatus();

        // 如果设置中启用了，但当前未激活，则启动
        if (shouldBeActive && !currentStatus) {
          const result = await window.electronAPI.caffeinateStart();
          if (result.success) {
            console.log('[Renderer] 已恢复禁止休眠状态');
          }
        }
        // 如果设置中未启用，但当前已激活，则停止
        else if (!shouldBeActive && currentStatus) {
          await window.electronAPI.caffeinateStop();
        }

        // 更新按钮状态
        await updateCaffeinateButtonState();
      } catch (error) {
        console.error('初始化禁止休眠状态失败:', error);
        await updateCaffeinateButtonState();
      }
    };

    if (caffeinateBtn) {
      await initPreventSleep();
      caffeinateBtn.addEventListener('click', handleCaffeinateToggle);
    }

    if (window.electronAPI.onCaffeinateStatusChange) {
      window.electronAPI.onCaffeinateStatusChange(async () => {
        await syncCaffeinateButtons();
      });
    }

    // 更新标题栏托盘模式按钮状态
    const updateTrayModeTitlebarButton = async () => {
      if (!trayModeTitlebarBtn) return;
      try {
        const settings = await window.electronAPI.getSettings();
        const isEnabled = settings.trayMode || false;
        if (isEnabled) {
          trayModeTitlebarBtn.classList.add('active');
        } else {
          trayModeTitlebarBtn.classList.remove('active');
        }
        updateTitlebarButtonTitle(trayModeTitlebarBtn, 'settings.trayMode', isEnabled);
      } catch (error) {
        console.error('获取托盘模式设置失败:', error);
      }
    };

    // 初始化托盘模式功能
    await updateTrayModeTitlebarButton();

    // 标题栏托盘模式按钮点击事件
    if (trayModeTitlebarBtn) {
      trayModeTitlebarBtn.addEventListener('click', async () => {
        if (isLocked) {
          const t = getT();
          await AppUtils.Logs.addLog(t('app.protectLockedMessage') || '状态已锁定，无法修改', 'warning');
          return;
        }
        try {
          const settings = await window.electronAPI.getSettings();
          const newValue = !settings.trayMode;
          await window.electronAPI.saveSettings({ trayMode: newValue });
          await updateTrayModeTitlebarButton();
        } catch (error) {
          console.error('切换托盘模式设置失败:', error);
        }
      });
    }

    window.addEventListener('languageChanged', async () => {
      await new Promise(resolve => setTimeout(resolve, 100));
      await syncCaffeinateButtons();
      await updateAutoMountTitlebarButton();
      await updateTrayModeTitlebarButton();
    });

    // 监听从菜单切换标签页的事件
    if (window.electronAPI && window.electronAPI.onSwitchTab) {
      window.electronAPI.onSwitchTab((tabName: string) => {
        AppModules.Tabs.switchToTab(tabName, logContainer, helpTab);
      });
    }

    // 事件监听
    checkDepsBtn.addEventListener('click', () => {
      AppModules.Dependencies.checkDependencies(
        depsList,
        loadingOverlay,
        statusDot,
        statusText
      );
    });

    if (refreshDevicesBtn) {
      refreshDevicesBtn.addEventListener('click', async () => {
        // 禁用按钮，防止重复点击
        if (refreshDevicesBtn) {
          refreshDevicesBtn.disabled = true;
          const refreshingText = AppUtils?.I18n?.t('tray.refreshing') || '刷新中...';
          refreshDevicesBtn.innerHTML = `<img src="../imgs/svg/actions/refresh.svg" alt="" class="btn-icon">`;
        }
        try {
          // 强制刷新设备列表（跳过缓存）
          const devices = await (window as any).electronAPI.getNTFSDevices(true);
          await AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText, devices);
        } catch (error) {
          console.error('刷新设备列表失败:', error);
          await AppUtils.Logs.addLog('刷新设备列表失败: ' + (error instanceof Error ? error.message : String(error)), 'error');
        } finally {
          // 恢复按钮状态
          if (refreshDevicesBtn) {
            refreshDevicesBtn.disabled = false;
            const refreshText = AppUtils?.I18n?.t('devices.refreshDevices') || '刷新';
            refreshDevicesBtn.innerHTML = `<img src="../imgs/svg/actions/refresh.svg" alt="" class="btn-icon">`;
          }
        }
      });
    }

    if (mountAllBtn) {
      mountAllBtn.addEventListener('click', () => {
        AppModules.Devices.mountAllDevices(devicesList, readWriteDevicesList, statusDot, statusText);
      });
    }

    if (restoreAllReadOnlyBtn) {
      restoreAllReadOnlyBtn.addEventListener('click', () => {
        AppModules.Devices.restoreAllToReadOnly(devicesList, readWriteDevicesList, statusDot, statusText);
      });
    }

    if (unmountAllBtn) {
      unmountAllBtn.addEventListener('click', () => {
        AppModules.Devices.unmountAllDevices(devicesList, readWriteDevicesList, statusDot, statusText);
      });
    }

    if (ejectAllBtn) {
      ejectAllBtn.addEventListener('click', () => {
        AppModules.Devices.ejectAllDevices(devicesList, readWriteDevicesList, statusDot, statusText);
      });
    }

    // 同步设备列表的滚动（确保两栏内容高度一致）
    const devicesLayout = document.querySelector('.devices-layout') as HTMLElement;
    if (devicesLayout) {
      // 监听滚动，确保两栏内容同步
      // 由于现在使用统一的滚动容器，两栏会自然同步
      // 这里可以添加额外的逻辑来确保内容高度一致（如果需要）
    }

    clearLogBtn.addEventListener('click', async () => {
      await AppUtils.Logs.clearLog(logContainer);
    });

    const exportLogBtn = document.getElementById('exportLogBtn') as HTMLButtonElement;
    if (exportLogBtn) {
      exportLogBtn.addEventListener('click', () => {
        AppUtils.Logs.exportLogs();
      });
    }

    // 初始化启用操作日志复选框
    const enableLogsCheckbox = document.getElementById('enableLogsCheckbox') as HTMLInputElement;
    if (enableLogsCheckbox) {
      // 检查日志是否已启用
      const checkLogsStatus = async () => {
        const isEnabled = await AppUtils.Logs.isEnabled();
        enableLogsCheckbox.checked = isEnabled;
      };

      checkLogsStatus();

      enableLogsCheckbox.addEventListener('change', async () => {
        try {
          await window.electronAPI.saveSettings({ enableLogs: enableLogsCheckbox.checked });
          if (enableLogsCheckbox.checked) {
            const t = AppUtils && AppUtils.I18n ? AppUtils.I18n.t : ((key: string) => key);
            const logsEnabledText = t('logs.logsEnabled') || '操作日志已启用';
            await AppUtils.Logs.addLog(logsEnabledText, 'success');
          }
        } catch (error) {
          console.error('保存操作日志设置失败:', error);
          enableLogsCheckbox.checked = !enableLogsCheckbox.checked;
        }
      });

      // 定期检查日志状态（当切换到日志标签页时）
      const logsTab = document.getElementById('logsTab');
      if (logsTab) {
        const observer = new MutationObserver(() => {
          if (logsTab.classList.contains('active')) {
            checkLogsStatus();
          }
        });
        observer.observe(logsTab, { attributes: true, attributeFilter: ['class'] });
      }
    }

    if (themeToggleButton) {
      themeToggleButton.addEventListener('click', () => {
        AppUtils.Theme.handleThemeToggleClick(docBody, themeToggleButton);
      });
    }

    // 定期刷新日志显示（如果日志标签页是活动的）
    // 降低刷新频率，避免闪烁
    setInterval(() => {
      const logsTab = document.getElementById('logsTab');
      if (logsTab && logsTab.classList.contains('active')) {
        // 只在日志标签页可见时才更新，且不强制更新
        AppUtils.Logs.renderLogs(logContainer, false).catch((err: any) => console.error('渲染日志失败:', err));
      }
    }, 2000);
  });

  // 自动刷新（优化版：混合检测 - 事件驱动 + 智能轮询备用）
  async function startAutoRefresh(): Promise<void> {
    // 停止旧的轮询
    if (autoRefreshInterval) {
      clearInterval(autoRefreshInterval);
      autoRefreshInterval = null;
    }

    // 注意：每个窗口都需要注册自己的事件监听器
    // 即使混合检测已经全局初始化，每个窗口也需要调用startHybridDetection来注册监听器

    // 尝试使用混合检测（事件驱动优先）
    try {
      if (window.electronAPI && typeof window.electronAPI.startHybridDetection === 'function') {
        await window.electronAPI.startHybridDetection(async (devices: any[]) => {
          // 设备变化回调（立即使用事件提供的设备列表，这些设备列表已经是强制刷新的最新状态）
          console.log('[主界面] 设备变化事件触发，设备数量:', devices.length, '设备列表:', devices.map((d: any) => d.volumeName));

          // 立即更新设备列表（不等待，确保UI快速响应）
          // 注意：事件提供的设备列表已经是强制刷新的最新状态，直接使用即可
          try {
            await AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText, devices);
            console.log('[主界面] UI已更新，当前显示设备数量:', devices.length);

            // 对于读写状态变化，额外进行一次验证检测（确保状态完全同步）
            // 延迟一小段时间后再次强制刷新，捕获可能的延迟状态更新
            setTimeout(async () => {
              try {
                // 再次强制刷新，确保读写状态完全同步（特别是读写转换操作后）
                const latestDevices = await window.electronAPI.getNTFSDevices(true);
                const hasStateChange = latestDevices.some((newDevice: any, index: number) => {
                  const oldDevice = devices[index];
                  return !oldDevice ||
                         oldDevice.isReadOnly !== newDevice.isReadOnly ||
                         oldDevice.isMounted !== newDevice.isMounted;
                });

                if (hasStateChange) {
                  console.log('[主界面] 检测到状态变化，更新UI');
                  await AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText, latestDevices);
                }
              } catch (error) {
                console.warn('[主界面] 状态验证检测失败:', error);
              }
            }, 500);
          } catch (error) {
            console.error('[主界面] 更新设备列表失败:', error);
          }
        });

        console.log('✅ [主界面] 混合检测事件监听器已注册（事件驱动模式）');

        // 监听窗口可见性变化
        document.addEventListener('visibilitychange', () => {
          if (window.electronAPI && typeof window.electronAPI.updateWindowVisibility === 'function') {
            window.electronAPI.updateWindowVisibility(!document.hidden);
          }

          // 窗口变为可见时，立即强制刷新设备列表（使用强制刷新，确保获取最新状态）
          if (!document.hidden) {
            setTimeout(async () => {
              try {
                // 强制刷新，确保窗口重新可见时显示最新状态
                const latestDevices = await window.electronAPI.getNTFSDevices(true);
                await AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText, latestDevices);
              } catch (error) {
                console.error('[主界面] 窗口可见性变化时刷新失败:', error);
                // 降级：不使用强制刷新
                await AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText);
              }
            }, 100);
          }
        });

        return;
      }
    } catch (error) {
      console.warn('[主界面] 混合检测启动失败，降级到轮询模式:', error);
    }

    // 降级到智能轮询（如果混合检测不可用）
    console.log('⚠️ [主界面] 使用智能轮询模式');

    let currentInterval = 500; // 初始0.5秒（加快初始检测）
    let consecutiveChanges = 0;
    let lastDeviceCount = 0;
    let lastDeviceState = ''; // 记录设备状态哈希，用于检测读写状态变化

    const poll = async () => {
      try {
        const oldDeviceCount = lastDeviceCount;
        const oldDeviceState = lastDeviceState;

        // 轮询模式下也使用强制刷新，确保获取最新状态
        const latestDevices = await window.electronAPI.getNTFSDevices(true);
        await AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText, latestDevices);

        const currentDeviceCount = devicesList?.children.length || latestDevices.length;
        // 计算设备状态哈希（包括读写状态）
        const currentDeviceState = JSON.stringify(latestDevices.map((d: any) => ({
          disk: d.disk,
          isReadOnly: d.isReadOnly,
          isMounted: d.isMounted
        })));

        const hasChanged = currentDeviceCount !== oldDeviceCount || currentDeviceState !== oldDeviceState;

        if (hasChanged) {
          consecutiveChanges++;
          currentInterval = 1000; // 变化后使用1秒高频（加快响应）
          console.log('[主界面] 设备变化:', oldDeviceCount, '->', currentDeviceCount, '状态变化:', currentDeviceState !== oldDeviceState);
        } else {
          consecutiveChanges = Math.max(0, consecutiveChanges - 1);

          if (currentDeviceCount === 0) {
            currentInterval = 30000;
          } else if (consecutiveChanges === 0) {
            currentInterval = 5000; // 稳定状态：5秒
          }
        }

        if (consecutiveChanges > 3) {
          consecutiveChanges = 0;
          currentInterval = 5000;
        }

        if (document.hidden) {
          currentInterval = 60000;
        }

        lastDeviceCount = currentDeviceCount;
        lastDeviceState = currentDeviceState;
        autoRefreshInterval = setTimeout(poll, currentInterval);
      } catch (error) {
        console.error('[主界面] 智能轮询检测失败:', error);
        autoRefreshInterval = setTimeout(poll, 5000);
      }
    };

    poll();
  }

  // 监听托盘操作
  if (window.electronAPI && window.electronAPI.onTrayAction) {
    window.electronAPI.onTrayAction((action: string) => {
      switch (action) {
        case 'refresh-devices':
          AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText);
          break;
        case 'mount-all':
          if (mountAllBtn) {
            mountAllBtn.click();
          }
          break;
        case 'unmount-all':
          if (unmountAllBtn) {
            unmountAllBtn.click();
          }
          break;
        case 'eject-all':
          if (ejectAllBtn) {
            ejectAllBtn.click();
          }
          break;
      }
    });
  }

  // 监听托盘设备操作
  if (window.electronAPI && window.electronAPI.onTrayDeviceAction) {
    window.electronAPI.onTrayDeviceAction((data: { action: string; device: any }) => {
      const { action, device } = data;
      // 切换到设备标签页
      AppModules.Tabs.switchToTab('devices', logContainer, helpTab);
      // 刷新设备列表
      AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText).then(() => {
        // 根据操作类型执行相应的操作
        switch (action) {
          case 'mount':
            // 找到对应的设备并执行挂载操作
            AppModules.Devices.mountDevice(device, devicesList, readWriteDevicesList, statusDot, statusText);
            break;
          case 'unmount':
            AppModules.Devices.unmountDevice(device, devicesList, readWriteDevicesList, statusDot, statusText);
            break;
          case 'eject':
            AppModules.Devices.ejectDevice(device, devicesList, readWriteDevicesList, statusDot, statusText);
            break;
          case 'restore':
            AppModules.Devices.restoreToReadOnly(device, devicesList, readWriteDevicesList, statusDot, statusText);
            break;
        }
      });
    });
  }

  // 清理
  window.addEventListener('beforeunload', () => {
    if (autoRefreshInterval) {
      clearInterval(autoRefreshInterval);
    }
  });

})(); // 结束立即执行函数
