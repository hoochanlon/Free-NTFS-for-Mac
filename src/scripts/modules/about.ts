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

  // 关于窗口管理
  AppModules.About = {
    // 初始化关于按钮
    initAboutButton(aboutBtn: HTMLElement): void {
      if (!aboutBtn) {
        console.error('关于按钮元素未找到');
        return;
      }

      console.log('初始化关于按钮', aboutBtn, electronAPI);

      // 打开关于窗口
      aboutBtn.addEventListener('click', async (e) => {
        e.preventDefault();
        e.stopPropagation();
        console.log('关于按钮被点击');
        try {
          if (electronAPI && electronAPI.openAboutWindow) {
            console.log('调用 openAboutWindow');
            await electronAPI.openAboutWindow();
          } else {
            console.error('electronAPI.openAboutWindow 未定义', electronAPI);
          }
        } catch (error) {
          console.error('打开关于窗口失败:', error);
        }
      });
    }
  };

})();
