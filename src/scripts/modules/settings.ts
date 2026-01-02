// 设置管理模块
// 注意：不使用 import，避免生成 CommonJS 代码（浏览器环境不支持）

(function() {
  'use strict';

  // 创建全局命名空间
  if (typeof (window as any).AppModules === 'undefined') {
    (window as any).AppModules = {};
  }

  const AppModules = (window as any).AppModules;
  const electronAPI = (window as any).electronAPI;

  // 设置管理
  AppModules.Settings = {
    // 初始化设置
    async initSettings(): Promise<void> {
      const savePasswordCheckbox = document.getElementById('savePasswordCheckbox') as HTMLInputElement;
      const deletePasswordBtn = document.getElementById('deletePasswordBtn') as HTMLButtonElement;
      const startupTabSelect = document.getElementById('startupTabSelect') as HTMLSelectElement;

      if (!savePasswordCheckbox || !deletePasswordBtn || !startupTabSelect) {
        return;
      }

      try {
        // 加载设置
        const settings = await electronAPI.getSettings();
        savePasswordCheckbox.checked = settings.savePassword;
        startupTabSelect.value = settings.startupTab;

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
          if (confirm('确定要删除保存的密码吗？')) {
            try {
              await electronAPI.deleteSavedPassword();
              deletePasswordBtn.style.display = 'none';
              alert('已删除保存的密码');
            } catch (error) {
              console.error('删除密码失败:', error);
              alert('删除密码失败，请重试');
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
      } catch (error) {
        console.error('加载设置失败:', error);
      }
    }
  };

})();
