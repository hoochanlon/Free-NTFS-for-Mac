// 标签页管理模块
// 注意：不使用 import，避免生成 CommonJS 代码（浏览器环境不支持）

(function() {
  'use strict';

  // 创建全局命名空间
  if (typeof (window as any).AppModules === 'undefined') {
    (window as any).AppModules = {};
  }

  const AppModules = (window as any).AppModules;
  const AppUtils = (window as any).AppUtils;

  // 标签页管理
  AppModules.Tabs = {
    // 初始化标签页
    initTabs(
      logContainer: HTMLElement,
      helpTab: HTMLElement
    ): void {
      const tabs = document.querySelectorAll('.tab');
      const tabContents = document.querySelectorAll('.tab-content');

      tabs.forEach(tab => {
        tab.addEventListener('click', () => {
          const targetTab = tab.getAttribute('data-tab');

          // 移除所有活动状态
          tabs.forEach(t => t.classList.remove('active'));
          tabContents.forEach(content => content.classList.remove('active'));

          // 激活选中的标签页
          tab.classList.add('active');
          const targetContent = document.getElementById(`${targetTab}Tab`);
          if (targetContent) {
            targetContent.classList.add('active');
          }

          // 如果切换到日志标签页，刷新日志显示
          if (targetTab === 'logs') {
            AppUtils.Logs.renderLogs(logContainer, true);
          }
          // 如果切换到帮助说明标签页，加载 markdown
          else if (targetTab === 'help' && helpTab) {
            AppUtils.Markdown.loadMarkdown('help.md', helpTab);
          }
        });
      });
    }
  };

})();
