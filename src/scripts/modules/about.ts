// 关于窗口模块
// 注意：不使用 import，避免生成 CommonJS 代码（浏览器环境不支持）

(function() {
  'use strict';

  // 创建全局命名空间
  if (typeof (window as any).AppModules === 'undefined') {
    (window as any).AppModules = {};
  }

  const AppModules = (window as any).AppModules;
  const electronAPI = (window as any).electronAPI;

  // 关于对话框管理
  AppModules.About = {
    // 初始化关于按钮
    initAboutButton(aboutBtn: HTMLElement): void {
      if (!aboutBtn) {
        console.error('关于按钮元素未找到');
        return;
      }

      const AppUtils = (window as any).AppUtils;

      // 打开关于对话框
      aboutBtn.addEventListener('click', async (e) => {
        e.preventDefault();
        e.stopPropagation();
        try {
          if (AppUtils && AppUtils.UI && AppUtils.UI.showAbout) {
            await AppUtils.UI.showAbout();
          } else {
            console.error('AppUtils.UI.showAbout 未定义');
          }
        } catch (error) {
          console.error('打开关于对话框失败:', error);
        }
      });
    }
  };

})();
