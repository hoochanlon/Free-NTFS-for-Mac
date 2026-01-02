// i18n 初始化脚本 - 在页面加载时应用翻译
// 注意：不使用 import，避免生成 CommonJS 代码（浏览器环境不支持）

(function() {
  'use strict';

  const AppUtils = (window as any).AppUtils;

  // 应用翻译到 HTML 元素
  function applyTranslations() {
    if (!AppUtils || !AppUtils.I18n) {
      console.error('I18n not initialized');
      return;
    }

    const t = AppUtils.I18n.t;

    // 标题栏
    const aboutBtn = document.getElementById('aboutBtn');
    if (aboutBtn) {
      aboutBtn.title = t('app.about');
    }

    const statusText = document.querySelector('.status-text');
    if (statusText) {
      statusText.textContent = t('status.checking');
    }

    // 标签页
    const tabs = document.querySelectorAll('.tab span');
    tabs.forEach((tab, index) => {
      const tabNames = ['dependencies', 'devices', 'logs', 'help', 'settings'];
      if (tabNames[index]) {
        (tab as HTMLElement).textContent = t(`tabs.${tabNames[index]}`);
      }
    });

    // 系统依赖标签页
    const depsTitle = document.querySelector('#dependenciesTab h2');
    if (depsTitle) {
      depsTitle.textContent = t('dependencies.title');
    }

    const checkDepsBtn = document.getElementById('checkDepsBtn');
    if (checkDepsBtn) {
      checkDepsBtn.textContent = t('dependencies.checkButton');
    }

    // NTFS 设备标签页
    const devicesTitle = document.querySelector('#devicesTab h2');
    if (devicesTitle) {
      devicesTitle.textContent = t('devices.title');
    }

    const mountAllBtn = document.getElementById('mountAllBtn');
    if (mountAllBtn) {
      mountAllBtn.textContent = t('devices.mountAll');
    }

    const restoreAllReadOnlyBtn = document.getElementById('restoreAllReadOnlyBtn');
    if (restoreAllReadOnlyBtn) {
      restoreAllReadOnlyBtn.textContent = t('devices.restoreAllReadOnly');
    }

    const unmountAllBtn = document.getElementById('unmountAllBtn');
    if (unmountAllBtn) {
      unmountAllBtn.textContent = t('devices.unmountAll');
    }

    const ejectAllBtn = document.getElementById('ejectAllBtn');
    if (ejectAllBtn) {
      ejectAllBtn.textContent = t('devices.ejectAll');
    }

    // 操作日志标签页
    const logsTitle = document.querySelector('#logsTab h2');
    if (logsTitle) {
      logsTitle.textContent = t('logs.title');
    }

    const clearLogBtn = document.getElementById('clearLogBtn');
    if (clearLogBtn) {
      clearLogBtn.textContent = t('logs.clear');
    }

    const exportLogBtn = document.getElementById('exportLogBtn');
    if (exportLogBtn) {
      exportLogBtn.textContent = t('logs.export');
    }

    // 帮助说明标签页
    const helpTitle = document.querySelector('#helpTab h2');
    if (helpTitle) {
      helpTitle.textContent = t('help.title');
    }

    // 设置标签页
    const settingsTitle = document.querySelector('#settingsTab h2');
    if (settingsTitle) {
      settingsTitle.textContent = t('settings.title');
    }

    // 更新设置描述文本
    const enableLogsDesc = document.querySelector('#enableLogsCheckbox')?.closest('.setting-item')?.querySelector('.setting-description');
    if (enableLogsDesc) {
      enableLogsDesc.textContent = t('settings.enableLogsDesc');
    }

    const resetLogsDailyDesc = document.querySelector('#resetLogsDailyCheckbox')?.closest('.setting-item')?.querySelector('.setting-description');
    if (resetLogsDailyDesc) {
      resetLogsDailyDesc.textContent = t('settings.resetLogsDailyDesc');
    }

    // 加载遮罩
    const loadingText = document.querySelector('#loadingOverlay p');
    if (loadingText) {
      loadingText.textContent = t('status.checking');
    }
  }

  // 监听语言变更事件
  window.addEventListener('languageChanged', () => {
    applyTranslations();
    // 重新渲染动态内容
    if ((window as any).AppModules) {
      // 触发设备列表刷新
      const devicesList = document.getElementById('devicesList');
      const readWriteDevicesList = document.getElementById('readWriteDevicesList');
      const statusDot = document.querySelector('.status-dot') as HTMLElement;
      const statusText = document.querySelector('.status-text') as HTMLElement;

      if (devicesList && (window as any).AppModules.Devices && (window as any).AppModules.Devices.refreshDevices) {
        (window as any).AppModules.Devices.refreshDevices(
          devicesList,
          readWriteDevicesList || devicesList,
          statusDot,
          statusText
        );
      }
    }
  });

  // 初始化 i18n
  async function init() {
    await AppUtils.I18n.init();
    applyTranslations();
  }

  // 等待 DOM 加载完成
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
