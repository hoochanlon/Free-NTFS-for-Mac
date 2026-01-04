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

    const autoMountCheckbox = document.getElementById('autoMountCheckbox');
    if (autoMountCheckbox) {
      const label = autoMountCheckbox.parentElement?.querySelector('span');
      if (label) {
        label.textContent = t('devices.autoMount');
      }
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

    // 指南手册标签页
    const helpTitle = document.querySelector('#helpTab h2');
    if (helpTitle) {
      helpTitle.textContent = t('help.title');
    }

    // 设置标签页
    const settingsTitle = document.querySelector('#settingsTab h2');
    if (settingsTitle) {
      settingsTitle.textContent = t('settings.title');
    }

    // 更新所有设置项的标签和描述
    // 保存管理员密码
    const savePasswordLabel = document.querySelector('label[for="savePasswordCheckbox"]');
    if (savePasswordLabel) {
      savePasswordLabel.textContent = t('settings.savePassword');
    }
    const savePasswordDesc = document.querySelector('#savePasswordCheckbox')?.closest('.setting-item')?.querySelector('.setting-description');
    if (savePasswordDesc) {
      savePasswordDesc.textContent = t('settings.savePasswordDesc');
    }
    const deletePasswordBtn = document.getElementById('deletePasswordBtn');
    if (deletePasswordBtn) {
      deletePasswordBtn.textContent = t('settings.deletePassword');
    }

    // 启动时打开的标签页
    const startupTabLabel = document.querySelector('label[for="startupTabSelect"]');
    if (startupTabLabel) {
      startupTabLabel.textContent = t('settings.startupTab');
    }
    const startupTabDesc = document.querySelector('#startupTabSelect')?.closest('.setting-item')?.querySelector('.setting-description');
    if (startupTabDesc) {
      startupTabDesc.textContent = t('settings.startupTabDesc');
    }
    // 更新启动标签页下拉选项
    const startupTabSelect = document.getElementById('startupTabSelect') as HTMLSelectElement;
    if (startupTabSelect) {
      Array.from(startupTabSelect.options).forEach(option => {
        const tabKey = option.value;
        if (tabKey === 'dependencies') {
          option.textContent = t('tabs.dependencies');
        } else if (tabKey === 'devices') {
          option.textContent = t('tabs.devices');
        } else if (tabKey === 'logs') {
          option.textContent = t('tabs.logs');
        } else if (tabKey === 'help') {
          option.textContent = t('tabs.help');
        }
      });
    }

    // 启用操作日志复选框（在操作日志标签页）
    const enableLogsCheckbox = document.getElementById('enableLogsCheckbox');
    if (enableLogsCheckbox) {
      const label = enableLogsCheckbox.parentElement?.querySelector('span');
      if (label) {
        label.textContent = t('logs.enable') || '启用操作日志';
      }
    }

    // 托盘模式
    const trayModeLabel = document.querySelector('label[for="trayModeCheckbox"]');
    if (trayModeLabel) {
      trayModeLabel.textContent = t('settings.trayMode');
    }
    const trayModeDesc = document.querySelector('#trayModeCheckbox')?.closest('.setting-item')?.querySelector('.setting-description');
    if (trayModeDesc) {
      trayModeDesc.textContent = t('settings.trayModeDesc');
    }

    // 语言
    const languageLabel = document.querySelector('label[for="languageSelect"]');
    if (languageLabel) {
      languageLabel.textContent = t('settings.language');
    }
    const languageDesc = document.querySelector('#languageSelect')?.closest('.setting-item')?.querySelector('.setting-description');
    if (languageDesc) {
      languageDesc.textContent = t('settings.languageDesc');
    }

    // 窗口尺寸
    const windowSizeLabel = document.querySelector('.setting-item:has(#windowWidthInput) label');
    if (windowSizeLabel) {
      windowSizeLabel.textContent = t('settings.windowSize');
    }
    const windowSizeDesc = document.querySelector('.setting-item:has(#windowWidthInput) .setting-description');
    if (windowSizeDesc) {
      windowSizeDesc.textContent = t('settings.windowSizeDesc');
    }
    const widthLabel = document.querySelector('label[for="windowWidthInput"]');
    if (widthLabel) {
      widthLabel.textContent = t('settings.width');
    }
    const heightLabel = document.querySelector('label[for="windowHeightInput"]');
    if (heightLabel) {
      heightLabel.textContent = t('settings.height');
    }
    // 更新单位文字
    const sizeUnits = document.querySelectorAll('.size-unit[data-i18n="settings.pixel"]');
    sizeUnits.forEach((unit) => {
      unit.textContent = t('settings.pixel');
    });
    // 重置按钮
    const resetSizeBtn = document.getElementById('resetWindowSizeBtn');
    if (resetSizeBtn) {
      resetSizeBtn.textContent = t('settings.resetToDefault');
    }
    // 更新语言选择器的选项文本
    const languageSelect = document.getElementById('languageSelect') as HTMLSelectElement;
    if (languageSelect) {
      const langMap: Record<string, string> = {
        'system': t('settings.languages.system'),
        'zh-CN': t('settings.languages.zh-CN'),
        'zh-TW': t('settings.languages.zh-TW'),
        'ja': t('settings.languages.ja'),
        'en': t('settings.languages.en')
      };
      Array.from(languageSelect.options).forEach(option => {
        if (langMap[option.value]) {
          option.textContent = langMap[option.value];
        }
      });
    }

    // 加载遮罩
    const loadingText = document.querySelector('#loadingOverlay p');
    if (loadingText) {
      loadingText.textContent = t('status.checking');
    }
  }

  // 监听语言变更事件
  window.addEventListener('languageChanged', async () => {
    // 先应用静态翻译
    applyTranslations();

    // 等待一小段时间确保翻译已加载
    await new Promise(resolve => setTimeout(resolve, 50));

    // 重新渲染动态内容
    if ((window as any).AppModules) {
      // 触发设备列表刷新
      const devicesList = document.getElementById('devicesList');
      const readWriteDevicesList = document.getElementById('readWriteDevicesList');
      const statusDot = document.querySelector('.status-dot') as HTMLElement;
      const statusText = document.querySelector('.status-text') as HTMLElement;

      if (devicesList && (window as any).AppModules.Devices) {
        // 清除设备列表的缓存，强制重新渲染
        if ((window as any).AppModules.Devices.Renderer) {
          (window as any).AppModules.Devices.Renderer.lastRenderedDevices = [];
        }
        // 重新渲染设备列表
        if ((window as any).AppModules.Devices.Renderer && (window as any).AppModules.Devices.Renderer.renderDevices) {
          (window as any).AppModules.Devices.Renderer.renderDevices(
            devicesList,
            readWriteDevicesList || devicesList
          );
        }
        // 刷新设备状态
        if ((window as any).AppModules.Devices.refreshDevices) {
        (window as any).AppModules.Devices.refreshDevices(
          devicesList,
          readWriteDevicesList || devicesList,
          statusDot,
          statusText
        );
        }
      }

      // 重新渲染依赖列表
      const depsList = document.getElementById('depsList');
      if (depsList && (window as any).AppModules.Dependencies) {
        // 确保依赖数据存在，如果不存在则重新检查
        const dependencies = (window as any).AppModules.Dependencies.dependencies;
        if (!dependencies) {
          // 如果没有依赖数据，触发重新检查
          const checkDepsBtn = document.getElementById('checkDepsBtn');
          if (checkDepsBtn && (window as any).AppModules.Dependencies.checkDependencies) {
            const loadingOverlay = document.getElementById('loadingOverlay');
            if (loadingOverlay) {
              (window as any).AppModules.Dependencies.checkDependencies(
                depsList,
                loadingOverlay,
                statusDot,
                statusText
              );
            }
          }
        } else {
          // 重新渲染依赖列表
          if ((window as any).AppModules.Dependencies.renderDependencies) {
            (window as any).AppModules.Dependencies.renderDependencies(depsList);
          }

          // 更新状态文本（根据当前依赖状态）
          if (statusDot && statusText) {
            const t = AppUtils.I18n.t;
            const allInstalled = dependencies.swift &&
                                dependencies.brew &&
                                dependencies.macfuse &&
                                dependencies.ntfs3g &&
                                dependencies.macosVersion;

            if (allInstalled) {
              (window as any).AppUtils.UI.updateStatus('active', t('status.systemReady'), statusDot, statusText);
            } else {
              (window as any).AppUtils.UI.updateStatus('error', t('status.missingDeps'), statusDot, statusText);
            }
          }
        }
      }

      // 重新渲染日志
      const logContainer = document.getElementById('logContainer');
      if (logContainer && (window as any).AppUtils && (window as any).AppUtils.Logs) {
        (window as any).AppUtils.Logs.renderLogs(logContainer, true).catch((err: any) => console.error('渲染日志失败:', err));
      }

      // 如果当前在指南手册标签页，重新加载 markdown（会根据新语言加载对应文件）
      const helpTab = document.getElementById('helpTab');
      if (helpTab && helpTab.classList.contains('active') && (window as any).AppUtils && (window as any).AppUtils.Markdown) {
        (window as any).AppUtils.Markdown.loadMarkdown('help.md', helpTab);
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
