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
    // 切换到指定标签页
    switchToTab(
      targetTab: string,
      logContainer: HTMLElement,
      helpTab: HTMLElement
    ): void {
      const tabs = document.querySelectorAll('.tab');
      const tabContents = document.querySelectorAll('.tab-content');
      const mainContent = document.querySelector('.main-content') as HTMLElement;

      // 移除所有活动状态
      tabs.forEach(t => t.classList.remove('active'));
      tabContents.forEach(content => content.classList.remove('active'));

      // 激活选中的标签页
      const tabButton = document.querySelector(`.tab[data-tab="${targetTab}"]`) as HTMLElement;
      const targetContent = document.getElementById(`${targetTab}Tab`);

      if (tabButton) {
        tabButton.classList.add('active');
      }
      if (targetContent) {
        targetContent.classList.add('active');
      }

      // 设备标签页激活时，禁用主内容区域滚动
      if (mainContent) {
        if (targetTab === 'devices') {
          mainContent.classList.add('devices-tab-active');
        } else {
          mainContent.classList.remove('devices-tab-active');
        }
      }

      // 如果切换到日志标签页，刷新日志显示
      if (targetTab === 'logs') {
        AppUtils.Logs.renderLogs(logContainer, true).catch((err: any) => console.error('渲染日志失败:', err));
      }
      // 如果切换到指南手册标签页，加载 markdown（会自动根据当前语言加载对应文件）
      else if (targetTab === 'help' && helpTab) {
        AppUtils.Markdown.loadMarkdown('help.md', helpTab);
      }
    },

    // 初始化标签页
    initTabs(
      logContainer: HTMLElement,
      helpTab: HTMLElement
    ): void {
      const tabs = document.querySelectorAll('.tab');

      tabs.forEach(tab => {
        tab.addEventListener('click', () => {
          const targetTab = tab.getAttribute('data-tab');
          if (targetTab) {
            AppModules.Tabs.switchToTab(targetTab, logContainer, helpTab);
          }
        });
      });
    }
  };

})();
