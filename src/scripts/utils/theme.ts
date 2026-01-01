// 主题管理工具模块
// 注意：不使用 import，避免生成 CommonJS 代码（浏览器环境不支持）

(function() {
  'use strict';

  // 创建全局命名空间
  if (typeof (window as any).AppUtils === 'undefined') {
    (window as any).AppUtils = {};
  }

  const AppUtils = (window as any).AppUtils;

  // 主题管理
  AppUtils.Theme = {
    // 更新主题
    updateTheme(isLightMode: boolean, docBody: HTMLElement, themeToggleButton?: HTMLElement | null, shouldBroadcast: boolean = false): void {
      if (isLightMode) {
        docBody.classList.add('light-theme');
      } else {
        docBody.classList.remove('light-theme');
      }
      if (themeToggleButton) {
        themeToggleButton.setAttribute('aria-checked', isLightMode ? 'true' : 'false');
        const newLabel = isLightMode ? '切换到深色主题' : '切换到浅色主题';
        themeToggleButton.setAttribute('aria-label', newLabel);
      }
      try {
        localStorage.setItem('app-theme', isLightMode ? 'light' : 'dark');
        // 只在用户主动切换时广播，初始化时不广播
        if (shouldBroadcast && window.electronAPI && window.electronAPI.broadcastThemeChange) {
          window.electronAPI.broadcastThemeChange(isLightMode).catch((err: any) => {
            // 静默处理错误，避免影响主题切换
            console.debug('广播主题变化失败:', err);
          });
        }
      } catch (e) {
        console.warn('无法保存主题到 localStorage:', e);
      }
    },

    // 处理主题切换点击
    handleThemeToggleClick(docBody: HTMLElement, themeToggleButton?: HTMLElement | null): void {
      const isLightMode = docBody.classList.contains('light-theme');
      AppUtils.Theme.updateTheme(!isLightMode, docBody, themeToggleButton, true); // 用户主动切换，需要广播
    },

    // 初始化主题
    initializeTheme(docBody: HTMLElement, themeToggleButton?: HTMLElement | null): void {
      try {
        const savedTheme = localStorage.getItem('app-theme');
        if (savedTheme === 'light') {
          AppUtils.Theme.updateTheme(true, docBody, themeToggleButton);
        } else {
          AppUtils.Theme.updateTheme(false, docBody, themeToggleButton);
        }
      } catch (e) {
        console.warn('无法从 localStorage 读取主题设置:', e);
        AppUtils.Theme.updateTheme(false, docBody, themeToggleButton);
      }
    }
  };

})();
