// UI 工具函数模块
// 注意：不使用 import，避免生成 CommonJS 代码（浏览器环境不支持）

(function() {
  'use strict';

  // 类型定义
  type StatusType = 'active' | 'error';

  // 创建全局命名空间
  if (typeof (window as any).AppUtils === 'undefined') {
    (window as any).AppUtils = {};
  }

  const AppUtils = (window as any).AppUtils;

  // UI 工具函数
  AppUtils.UI = {
    // 显示/隐藏加载遮罩
    showLoading(loadingOverlay: HTMLElement, show: boolean = true): void {
      if (show) {
        loadingOverlay.classList.add('visible');
      } else {
        loadingOverlay.classList.remove('visible');
      }
    },

    // 更新状态指示器
    updateStatus(
      status: StatusType,
      text: string,
      statusDot: HTMLElement,
      statusText: HTMLElement
    ): void {
      statusDot.className = 'status-dot';
      if (status === 'active') {
        statusDot.classList.add('active');
      } else if (status === 'error') {
        statusDot.classList.add('error');
      }
      statusText.textContent = text;
    }
  };

})();
