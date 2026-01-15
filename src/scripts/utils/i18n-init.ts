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

    // 标题栏（关于按钮不需要 tooltip）

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

    // 托盘模式（在设备标签页）
    const trayModeCheckbox = document.getElementById('trayModeCheckbox');
    if (trayModeCheckbox) {
      const label = trayModeCheckbox.parentElement?.querySelector('span');
      if (label) {
        label.textContent = t('settings.trayMode');
      }
    }

    const ejectAllBtn = document.getElementById('ejectAllBtn');
    if (ejectAllBtn) {
      ejectAllBtn.textContent = t('devices.ejectAll');
    }

    const refreshDevicesBtn = document.getElementById('refreshDevicesBtn');
    if (refreshDevicesBtn) {
      // 更新标题（只更新 title，不更新内容，因为只有图标）
      const titleText = t('tray.refreshDevices') || t('devices.refreshDevices');
      refreshDevicesBtn.title = titleText;
      // 确保只有图标（如果没有图标，添加图标）
      const icon = refreshDevicesBtn.querySelector('.btn-icon');
      if (!icon) {
        refreshDevicesBtn.innerHTML = '<img src="../imgs/svg/refresh.svg" alt="" class="btn-icon">';
      }
    }

    const quitBtn = document.getElementById('quitBtn');
    if (quitBtn) {
      // 区分主界面和托盘窗口：
      // - 主界面：使用 HTML 中自带的 exit-red.svg + btn-about-icon，不修改 title 和内容
      // - 托盘窗口：使用统一的 btn-icon 样式和退出提示文案
      const isTrayWindow = document.body && document.body.classList.contains('tray-window');
      if (isTrayWindow) {
        const titleText = t('tray.quit');
        quitBtn.title = titleText;

        // 托盘窗口使用简单的黑色退出图标（与其它图标风格一致）
        const icon = quitBtn.querySelector('.btn-icon');
        if (!icon) {
          quitBtn.innerHTML = '<img src="../imgs/svg/exit.svg" alt="" class="btn-icon">';
        }
      }
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

    // 系统自启
    const autoStartLabel = document.querySelector('label[for="autoStartCheckbox"]');
    if (autoStartLabel) {
      autoStartLabel.textContent = t('settings.autoStart');
    }
    const autoStartDesc = document.querySelector('#autoStartCheckbox')?.closest('.setting-item')?.querySelector('.setting-description');
    if (autoStartDesc) {
      autoStartDesc.textContent = t('settings.autoStartDesc');
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
        'en': t('settings.languages.en'),
        'de': t('settings.languages.de')
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

    // 处理所有带有 data-i18n 属性的元素（通用处理）
    const i18nElements = document.querySelectorAll('[data-i18n]');
    i18nElements.forEach((element) => {
      const key = element.getAttribute('data-i18n');
      if (key) {
        const translatedText = t(key);
        if (translatedText && translatedText !== key) {
          // 如果是 span 或其他文本元素，直接更新文本
          if (element.tagName === 'SPAN' || element.tagName === 'P' || element.tagName === 'DIV') {
            element.textContent = translatedText;
          } else if (element.tagName === 'BUTTON') {
            // 对于按钮，保留图标，只更新文本span
            const icon = element.querySelector('.btn-icon, img.btn-icon');
            const textSpan = element.querySelector('span[data-i18n], span:not(.btn-icon)');
            if (textSpan) {
              textSpan.textContent = translatedText;
            } else if (icon) {
              // 如果有图标但没有文本span，创建一个
              const span = document.createElement('span');
              span.textContent = translatedText;
              element.appendChild(span);
            } else {
              // 没有图标，直接更新文本内容
              element.textContent = translatedText;
            }
          } else {
            // 对于其他元素，更新文本内容但保留子元素（如图标）
            const icon = element.querySelector('.btn-icon, img');
            if (icon) {
              // 保留图标，只更新文本
              const textSpan = element.querySelector('span:not(.btn-icon)');
              if (textSpan) {
                textSpan.textContent = translatedText;
              } else {
                // 如果没有文本span，创建一个
                const span = document.createElement('span');
                span.textContent = translatedText;
                element.appendChild(span);
              }
            } else {
              // 没有图标，直接更新文本内容
              element.textContent = translatedText;
            }
          }
        }
      }
    });

    // 处理所有带有 data-i18n-title 属性的元素（用于 title 属性）
    const i18nTitleElements = document.querySelectorAll('[data-i18n-title]');
    i18nTitleElements.forEach((element) => {
      const key = element.getAttribute('data-i18n-title');
      if (key) {
        const translatedText = t(key);
        if (translatedText && translatedText !== key) {
          element.setAttribute('title', translatedText);
        }
      }
    });
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
        // 清除设备列表的状态缓存，强制重新渲染（修复：清除 __lastStateKey）
        (devicesList as any).__lastStateKey = '';
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
