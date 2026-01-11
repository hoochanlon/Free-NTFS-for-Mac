// 设置管理模块
// 注意：不使用 import，避免生成 CommonJS 代码（浏览器环境不支持）

(function() {
  'use strict';

  // 创建全局命名空间
  if (typeof (window as any).AppModules === 'undefined') {
    (window as any).AppModules = {};
  }

  const AppModules = (window as any).AppModules;
  const AppUtils = (window as any).AppUtils;
  const electronAPI = (window as any).electronAPI;

  // 设置管理
  AppModules.Settings = {
    // 初始化设置
    async initSettings(): Promise<void> {
      const savePasswordCheckbox = document.getElementById('savePasswordCheckbox') as HTMLInputElement;
      const deletePasswordBtn = document.getElementById('deletePasswordBtn') as HTMLButtonElement;
      const startupTabSelect = document.getElementById('startupTabSelect') as HTMLSelectElement;
      const languageSelect = document.getElementById('languageSelect') as HTMLSelectElement;
      const autoStartCheckbox = document.getElementById('autoStartCheckbox') as HTMLInputElement;

      if (!savePasswordCheckbox || !deletePasswordBtn || !startupTabSelect) {
        return;
      }

      try {
        // 从主进程获取窗口尺寸配置（统一管理）
        const WINDOW_SIZE_CONFIG = await electronAPI.getWindowSizeConfig();

        // 加载设置
        const settings = await electronAPI.getSettings();
        savePasswordCheckbox.checked = settings.savePassword;
        startupTabSelect.value = settings.startupTab;
        if (languageSelect) {
          // 如果没有设置或设置为空，默认使用跟随系统
          languageSelect.value = settings.language || 'system';
        }
        if (autoStartCheckbox) {
          autoStartCheckbox.checked = settings.autoStart || false;
        }

        // 窗口尺寸设置
        const windowWidthInput = document.getElementById('windowWidthInput') as HTMLInputElement;
        const windowHeightInput = document.getElementById('windowHeightInput') as HTMLInputElement;
        if (windowWidthInput) {
          windowWidthInput.value = String(settings.windowWidth || WINDOW_SIZE_CONFIG.defaultWidth);
          windowWidthInput.placeholder = String(WINDOW_SIZE_CONFIG.defaultWidth);
        }
        if (windowHeightInput) {
          windowHeightInput.value = String(settings.windowHeight || WINDOW_SIZE_CONFIG.defaultHeight);
          windowHeightInput.placeholder = String(WINDOW_SIZE_CONFIG.defaultHeight);
        }

        // 检查是否有保存的密码
        const hasPassword = await electronAPI.hasSavedPassword();
        deletePasswordBtn.style.display = hasPassword ? 'inline-block' : 'none';

        // 保存密码复选框变化
        savePasswordCheckbox.addEventListener('change', async () => {
          try {
            await electronAPI.saveSettings({ savePassword: savePasswordCheckbox.checked });
            // 如果取消保存密码，删除已保存的密码
            if (!savePasswordCheckbox.checked) {
              await electronAPI.deleteSavedPassword();
              deletePasswordBtn.style.display = 'none';
            } else {
              // 检查是否有保存的密码
              const hasPassword = await electronAPI.hasSavedPassword();
              deletePasswordBtn.style.display = hasPassword ? 'inline-block' : 'none';
            }
          } catch (error) {
            console.error('保存设置失败:', error);
            // 恢复复选框状态
            savePasswordCheckbox.checked = !savePasswordCheckbox.checked;
          }
        });

        // 删除保存的密码
        deletePasswordBtn.addEventListener('click', async () => {
          const t = AppUtils && AppUtils.I18n ? AppUtils.I18n.t : ((key: string) => key);
          const confirmText = t('settings.deletePasswordConfirm') || '确定要删除保存的密码吗？';
          const confirmTitle = t('dialog.confirm') || '确认';
          const confirmed = await AppUtils.UI.showConfirm(confirmTitle, confirmText);
          if (confirmed) {
            try {
              await electronAPI.deleteSavedPassword();
              deletePasswordBtn.style.display = 'none';
              const successText = t('settings.deletePasswordSuccess') || '已删除保存的密码';
              const successTitle = t('logs.logTypes.success') || '成功';
              await AppUtils.UI.showMessage(successTitle, successText, 'info');
            } catch (error) {
              console.error('删除密码失败:', error);
              const errorText = t('settings.deletePasswordError') || '删除密码失败，请重试';
              const errorTitle = t('logs.logTypes.error') || '错误';
              await AppUtils.UI.showMessage(errorTitle, errorText, 'error');
            }
          }
        });

        // 启动标签页选择变化
        startupTabSelect.addEventListener('change', async () => {
          try {
            await electronAPI.saveSettings({ startupTab: startupTabSelect.value as any });
          } catch (error) {
            console.error('保存设置失败:', error);
          }
        });

        // 语言选择变化
        if (languageSelect) {
          languageSelect.addEventListener('change', async () => {
            try {
              const newLanguage = languageSelect.value as 'zh-CN' | 'zh-TW' | 'ja' | 'en' | 'de' | 'system';
              await electronAPI.saveSettings({ language: newLanguage });
              // 切换语言
              if (AppUtils && AppUtils.I18n) {
                await AppUtils.I18n.setLanguage(newLanguage);
              }
            } catch (error) {
              console.error('保存设置失败:', error);
            }
          });
        }

        // 系统自启复选框变化
        if (autoStartCheckbox) {
          autoStartCheckbox.addEventListener('change', async () => {
            try {
              await electronAPI.saveSettings({ autoStart: autoStartCheckbox.checked });
            } catch (error) {
              console.error('保存设置失败:', error);
              // 恢复复选框状态
              autoStartCheckbox.checked = !autoStartCheckbox.checked;
            }
          });
        }

        // 窗口尺寸输入验证（只在失去焦点时验证）
        const validateSizeOnBlur = async (input: HTMLInputElement, min: number, max: number, defaultValue: number) => {
          const value = input.value.trim();

          // 如果为空，恢复为当前设置值
          if (value === '') {
            const settings = await electronAPI.getSettings();
            if (input.id === 'windowWidthInput') {
              input.value = String(settings.windowWidth || defaultValue);
            } else {
              input.value = String(settings.windowHeight || defaultValue);
            }
            return false;
          }

          // 只允许数字
          if (!/^\d+$/.test(value)) {
            // 如果不是纯数字，恢复为当前设置值
            const settings = await electronAPI.getSettings();
            if (input.id === 'windowWidthInput') {
              input.value = String(settings.windowWidth || defaultValue);
            } else {
              input.value = String(settings.windowHeight || defaultValue);
            }
            return false;
          }

          const numValue = parseInt(value, 10);
          // 验证范围
          if (numValue < min || numValue > max) {
            // 超出范围，恢复为当前设置值
            const settings = await electronAPI.getSettings();
            if (input.id === 'windowWidthInput') {
              input.value = String(settings.windowWidth || defaultValue);
            } else {
              input.value = String(settings.windowHeight || defaultValue);
            }
            return false;
          }

          return true;
        };

        // 保存窗口尺寸（防抖保存）
        let sizeTimeout: NodeJS.Timeout | null = null;
        const saveWindowSize = async () => {
          if (sizeTimeout) {
            clearTimeout(sizeTimeout);
          }
          sizeTimeout = setTimeout(async () => {
            try {
              const widthValue = windowWidthInput?.value.trim() || '';
              const heightValue = windowHeightInput?.value.trim() || '';

              // 如果输入为空，不保存
              if (!widthValue || !heightValue) {
                return;
              }

              // 验证输入
              if (!/^\d+$/.test(widthValue) || !/^\d+$/.test(heightValue)) {
                return;
              }

              const width = parseInt(widthValue, 10);
              const height = parseInt(heightValue, 10);

              // 验证范围
              if (width >= WINDOW_SIZE_CONFIG.minWidthLimit && width <= WINDOW_SIZE_CONFIG.maxWidthLimit &&
                  height >= WINDOW_SIZE_CONFIG.minHeightLimit && height <= WINDOW_SIZE_CONFIG.maxHeightLimit) {
                await electronAPI.saveSettings({
                  windowWidth: width,
                  windowHeight: height
                });
              }
            } catch (error) {
              console.error('保存窗口尺寸失败:', error);
            }
          }, 1000); // 1秒后保存
        };

        // 只允许输入数字
        const allowOnlyNumbers = (e: KeyboardEvent) => {
          const char = e.key;
          // 允许：数字、退格、删除、Tab、方向键、Home、End、Enter
          if (!/[\d\b\Delete\Tab\ArrowLeft\ArrowRight\ArrowUp\ArrowDown\Home\End\Enter]/.test(char) && !e.ctrlKey && !e.metaKey) {
            e.preventDefault();
          }
        };

        // 重置窗口尺寸为默认值
        const resetWindowSizeBtn = document.getElementById('resetWindowSizeBtn') as HTMLButtonElement;
        if (resetWindowSizeBtn) {
          resetWindowSizeBtn.addEventListener('click', async () => {
            try {
              if (windowWidthInput) {
                windowWidthInput.value = String(WINDOW_SIZE_CONFIG.defaultWidth);
              }
              if (windowHeightInput) {
                windowHeightInput.value = String(WINDOW_SIZE_CONFIG.defaultHeight);
              }

              await electronAPI.saveSettings({
                windowWidth: WINDOW_SIZE_CONFIG.defaultWidth,
                windowHeight: WINDOW_SIZE_CONFIG.defaultHeight
              });
            } catch (error) {
              console.error('重置窗口尺寸失败:', error);
            }
          });
        }

        if (windowWidthInput) {
          windowWidthInput.addEventListener('keydown', allowOnlyNumbers);
          windowWidthInput.addEventListener('input', saveWindowSize);
          windowWidthInput.addEventListener('blur', async () => {
            await validateSizeOnBlur(windowWidthInput, WINDOW_SIZE_CONFIG.minWidthLimit, WINDOW_SIZE_CONFIG.maxWidthLimit, WINDOW_SIZE_CONFIG.defaultWidth);
            saveWindowSize();
          });
        }
        if (windowHeightInput) {
          windowHeightInput.addEventListener('keydown', allowOnlyNumbers);
          windowHeightInput.addEventListener('input', saveWindowSize);
          windowHeightInput.addEventListener('blur', async () => {
            await validateSizeOnBlur(windowHeightInput, WINDOW_SIZE_CONFIG.minHeightLimit, WINDOW_SIZE_CONFIG.maxHeightLimit, WINDOW_SIZE_CONFIG.defaultHeight);
            saveWindowSize();
          });
        }
      } catch (error) {
        console.error('加载设置失败:', error);
      }
    }
  };

})();
