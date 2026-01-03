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
  const unmountAllBtn = document.getElementById('unmountAllBtn') as HTMLButtonElement;
  const restoreAllReadOnlyBtn = document.getElementById('restoreAllReadOnlyBtn') as HTMLButtonElement;
  const ejectAllBtn = document.getElementById('ejectAllBtn') as HTMLButtonElement;
  const loadingOverlay = document.getElementById('loadingOverlay') as HTMLElement;
  const logContainer = document.getElementById('logContainer')!;
  const clearLogBtn = document.getElementById('clearLogBtn') as HTMLButtonElement;
  const themeToggleButton = document.getElementById('theme-toggle-btn') as HTMLButtonElement;
  const docBody = document.body;
  const helpTab = document.getElementById('helpTab') as HTMLElement;
  const aboutBtn = document.getElementById('aboutBtn') as HTMLButtonElement;

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

    // 根据设置打开启动标签页
    try {
      const settings = await window.electronAPI.getSettings();
      if (settings.startupTab) {
        AppModules.Tabs.switchToTab(settings.startupTab, logContainer, helpTab);
      }
    } catch (error) {
      console.error('加载启动标签页设置失败:', error);
    }

    // 初始化功能模块
    // 检查并执行每天重置日志，并清理过期日志
    AppUtils.Logs.checkAndResetDaily();
    // 清理超过一个月的日志（getLogs 内部会自动清理）
    AppUtils.Logs.getLogs();

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

    // 初始化关于按钮
    if (aboutBtn) {
      AppModules.About.initAboutButton(aboutBtn);
    }

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

    const mountAllBtn = document.getElementById('mountAllBtn') as HTMLButtonElement;
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

    clearLogBtn.addEventListener('click', () => {
      AppUtils.Logs.clearLog(logContainer);
    });

    const exportLogBtn = document.getElementById('exportLogBtn') as HTMLButtonElement;
    if (exportLogBtn) {
      exportLogBtn.addEventListener('click', () => {
        AppUtils.Logs.exportLogs();
      });
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
        AppUtils.Logs.renderLogs(logContainer, false);
      }
    }, 2000);
  });

  // 自动刷新
  function startAutoRefresh(): void {
    // 每 5 秒刷新一次设备列表
    autoRefreshInterval = setInterval(() => {
      AppModules.Devices.refreshDevices(devicesList, readWriteDevicesList, statusDot, statusText);
    }, 5000);
  }

  // 清理
  window.addEventListener('beforeunload', () => {
    if (autoRefreshInterval) {
      clearInterval(autoRefreshInterval);
    }
  });

})(); // 结束立即执行函数
