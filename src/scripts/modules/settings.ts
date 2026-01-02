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
      const enableLogsCheckbox = document.getElementById('enableLogsCheckbox') as HTMLInputElement;
      const resetLogsDailyCheckbox = document.getElementById('resetLogsDailyCheckbox') as HTMLInputElement;
      const languageSelect = document.getElementById('languageSelect') as HTMLSelectElement;

      if (!savePasswordCheckbox || !deletePasswordBtn || !startupTabSelect) {
        return;
      }

      try {
        // 加载设置
        const settings = await electronAPI.getSettings();
        savePasswordCheckbox.checked = settings.savePassword;
        startupTabSelect.value = settings.startupTab;
        if (enableLogsCheckbox) {
          enableLogsCheckbox.checked = settings.enableLogs !== false; // 默认启用
        }
        if (resetLogsDailyCheckbox) {
          resetLogsDailyCheckbox.checked = settings.resetLogsDaily || false;
        }
        if (languageSelect) {
          // 如果没有设置或设置为空，默认使用跟随系统
          languageSelect.value = settings.language || 'system';
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
          if (confirm(confirmText)) {
            try {
              await electronAPI.deleteSavedPassword();
              deletePasswordBtn.style.display = 'none';
              const successText = t('settings.deletePasswordSuccess') || '已删除保存的密码';
              alert(successText);
            } catch (error) {
              console.error('删除密码失败:', error);
              const errorText = t('settings.deletePasswordError') || '删除密码失败，请重试';
              alert(errorText);
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

        // 启用日志复选框变化
        if (enableLogsCheckbox) {
          enableLogsCheckbox.addEventListener('change', async () => {
            try {
              await electronAPI.saveSettings({ enableLogs: enableLogsCheckbox.checked });
            } catch (error) {
              console.error('保存设置失败:', error);
              enableLogsCheckbox.checked = !enableLogsCheckbox.checked;
            }
          });
        }

        // 每天重置日志复选框变化
        if (resetLogsDailyCheckbox) {
          resetLogsDailyCheckbox.addEventListener('change', async () => {
            try {
              await electronAPI.saveSettings({ resetLogsDaily: resetLogsDailyCheckbox.checked });
            } catch (error) {
              console.error('保存设置失败:', error);
              resetLogsDailyCheckbox.checked = !resetLogsDailyCheckbox.checked;
            }
          });
        }

        // 语言选择变化
        if (languageSelect) {
          languageSelect.addEventListener('change', async () => {
            try {
              const newLanguage = languageSelect.value as 'zh-CN' | 'zh-TW' | 'ja' | 'en' | 'system';
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
      } catch (error) {
        console.error('加载设置失败:', error);
      }
    }
  };

})();
