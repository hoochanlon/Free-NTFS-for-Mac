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
      const startupTabSelectCustom = document.getElementById('startupTabSelectCustom') as HTMLElement;
      const autoStartCheckbox = document.getElementById('autoStartCheckbox') as HTMLInputElement;

      if (!savePasswordCheckbox || !deletePasswordBtn || !startupTabSelectCustom) {
        return;
      }

      try {
        // 从主进程获取窗口尺寸配置（统一管理）
        const WINDOW_SIZE_CONFIG = await electronAPI.getWindowSizeConfig();

        // 加载设置
        const settings = await electronAPI.getSettings();
        savePasswordCheckbox.checked = settings.savePassword;

        // 初始化启动标签页自定义下拉菜单
        if (startupTabSelectCustom) {
          // 设置初始值
          const initialValue = settings.startupTab || 'dependencies';
          startupTabSelectCustom.setAttribute('data-value', initialValue);
          this.initCustomSelect(startupTabSelectCustom);
          // 初始化后立即更新显示，确保显示正确的选中值
          this.updateCustomSelectDisplay(startupTabSelectCustom);
        }

        // 初始化语言选择自定义下拉菜单
        const languageSelectCustom = document.getElementById('languageSelectCustom') as HTMLElement;
        if (languageSelectCustom) {
          const initialLanguage = settings.language || 'system';
          languageSelectCustom.setAttribute('data-value', initialLanguage);
          this.initLanguageSelect(languageSelectCustom);
          this.updateLanguageSelectDisplay(languageSelectCustom);
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

        // 启动标签页选择变化（通过自定义下拉菜单）
        if (startupTabSelectCustom) {
          startupTabSelectCustom.addEventListener('tabChanged', async (e: any) => {
            try {
              const newValue = e.detail.value;
              await electronAPI.saveSettings({ startupTab: newValue as any });
            } catch (error) {
              console.error('保存设置失败:', error);
            }
          });
        }

        // 语言选择变化（通过自定义下拉菜单）
        if (languageSelectCustom) {
          languageSelectCustom.addEventListener('languageChanged', async (e: any) => {
            try {
              const newLanguage = e.detail.value as 'zh-CN' | 'zh-TW' | 'ja' | 'en' | 'de' | 'system';
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
    },

    // 初始化自定义下拉菜单
    initCustomSelect(customSelect: HTMLElement): void {

      // 点击触发器打开/关闭下拉菜单
      const trigger = customSelect.querySelector('.custom-select-trigger') as HTMLElement;
      if (trigger) {
        trigger.addEventListener('click', (e) => {
          e.stopPropagation();
          const isOpen = customSelect.classList.contains('open');
          if (isOpen) {
            customSelect.classList.remove('open');
          } else {
            // 关闭其他打开的下拉菜单
            document.querySelectorAll('.custom-select.open').forEach(el => {
              if (el !== customSelect) {
                el.classList.remove('open');
              }
            });
            customSelect.classList.add('open');
          }
        });
      }

      // 点击选项
      const options = customSelect.querySelectorAll('.custom-select-option');
      options.forEach(option => {
        option.addEventListener('click', (e) => {
          e.stopPropagation();
          const value = option.getAttribute('data-value');
          if (value) {
            // 更新data-value属性
            customSelect.setAttribute('data-value', value);
            // 更新显示
            this.updateCustomSelectDisplay(customSelect);
            // 触发自定义事件
            customSelect.dispatchEvent(new CustomEvent('tabChanged', {
              detail: { value },
              bubbles: true
            }));
            // 关闭下拉菜单
            customSelect.classList.remove('open');
          }
        });
      });

      // 点击外部关闭下拉菜单
      document.addEventListener('click', (e) => {
        if (!customSelect.contains(e.target as Node)) {
          customSelect.classList.remove('open');
        }
      });
    },

    // 更新自定义下拉菜单显示
    updateCustomSelectDisplay(customSelect: HTMLElement): void {
      const iconMap: Record<string, string> = {
        'dependencies': '../imgs/svg/ui/module.svg',
        'devices': '../imgs/svg/devices/flash-drive.svg',
        'logs': '../imgs/svg/ui/log.svg',
        'help': '../imgs/svg/ui/help.svg'
      };

      const textMap: Record<string, string> = {
        'dependencies': AppUtils && AppUtils.I18n ? AppUtils.I18n.t('tabs.dependencies') : '系统依赖',
        'devices': AppUtils && AppUtils.I18n ? AppUtils.I18n.t('tabs.devices') : 'NTFS 设备',
        'logs': AppUtils && AppUtils.I18n ? AppUtils.I18n.t('tabs.logs') : '操作日志',
        'help': AppUtils && AppUtils.I18n ? AppUtils.I18n.t('tabs.help') : '指南手册'
      };

      const value = customSelect.getAttribute('data-value') || 'dependencies';
      const icon = customSelect.querySelector('.custom-select-icon') as HTMLImageElement;
      const text = customSelect.querySelector('.custom-select-text') as HTMLElement;

      if (icon && iconMap[value]) {
        icon.src = iconMap[value];
      }
      if (text && textMap[value]) {
        text.textContent = textMap[value];
      }

      // 更新选中状态
      const options = customSelect.querySelectorAll('.custom-select-option');
      options.forEach(option => {
        if (option.getAttribute('data-value') === value) {
          option.classList.add('selected');
        } else {
          option.classList.remove('selected');
        }
      });
    },

    // 初始化语言选择自定义下拉菜单
    initLanguageSelect(customSelect: HTMLElement): void {
      // 点击触发器打开/关闭下拉菜单
      const trigger = customSelect.querySelector('.custom-select-trigger') as HTMLElement;
      if (trigger) {
        trigger.addEventListener('click', (e) => {
          e.stopPropagation();
          const isOpen = customSelect.classList.contains('open');
          if (isOpen) {
            customSelect.classList.remove('open');
          } else {
            // 关闭其他打开的下拉菜单
            document.querySelectorAll('.custom-select.open').forEach(el => {
              if (el !== customSelect) {
                el.classList.remove('open');
              }
            });
            customSelect.classList.add('open');
          }
        });
      }

      // 点击选项
      const options = customSelect.querySelectorAll('.custom-select-option');
      options.forEach(option => {
        option.addEventListener('click', (e) => {
          e.stopPropagation();
          const value = option.getAttribute('data-value');
          if (value) {
            // 更新data-value属性
            customSelect.setAttribute('data-value', value);
            // 更新显示
            this.updateLanguageSelectDisplay(customSelect);
            // 触发自定义事件
            customSelect.dispatchEvent(new CustomEvent('languageChanged', {
              detail: { value },
              bubbles: true
            }));
            // 关闭下拉菜单
            customSelect.classList.remove('open');
          }
        });
      });

      // 点击外部关闭下拉菜单
      document.addEventListener('click', (e) => {
        if (!customSelect.contains(e.target as Node)) {
          customSelect.classList.remove('open');
        }
      });
    },

    // 更新语言选择显示
    updateLanguageSelectDisplay(customSelect: HTMLElement): void {
      const iconMap: Record<string, string> = {
        'system': '../imgs/svg/flags/earth.svg',
        'zh-CN': '../imgs/svg/flags/cn.svg',
        'zh-TW': '../imgs/svg/flags/tw.svg',
        'ja': '../imgs/svg/flags/jp.svg',
        'en': '../imgs/svg/flags/us.svg',
        'de': '../imgs/svg/flags/de.svg'
      };

      const textMap: Record<string, string> = {
        'system': AppUtils && AppUtils.I18n ? AppUtils.I18n.t('settings.languages.system') : '跟随系统',
        'zh-CN': AppUtils && AppUtils.I18n ? AppUtils.I18n.t('settings.languages.zh-CN') : '简中 (CN)',
        'zh-TW': AppUtils && AppUtils.I18n ? AppUtils.I18n.t('settings.languages.zh-TW') : '繁中 (TW)',
        'ja': AppUtils && AppUtils.I18n ? AppUtils.I18n.t('settings.languages.ja') : '日本語 (JP)',
        'en': AppUtils && AppUtils.I18n ? AppUtils.I18n.t('settings.languages.en') : 'English (US)',
        'de': AppUtils && AppUtils.I18n ? AppUtils.I18n.t('settings.languages.de') : 'Deutsch (DE)'
      };

      const value = customSelect.getAttribute('data-value') || 'system';
      const icon = customSelect.querySelector('.custom-select-icon') as HTMLImageElement;
      const text = customSelect.querySelector('.custom-select-text') as HTMLElement;

      if (icon && iconMap[value]) {
        icon.src = iconMap[value];
      }
      if (text && textMap[value]) {
        text.textContent = textMap[value];
      }

      // 更新选中状态
      const options = customSelect.querySelectorAll('.custom-select-option');
      options.forEach(option => {
        if (option.getAttribute('data-value') === value) {
          option.classList.add('selected');
        } else {
          option.classList.remove('selected');
        }
      });
    }
  };

})();
