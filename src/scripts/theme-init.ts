// 在页面加载前初始化主题，避免闪烁
(function() {
  try {
    const savedTheme = localStorage.getItem('app-theme');
    // 默认使用浅色模式，只有明确设置为 'dark' 时才使用深色
    const isLight = savedTheme !== 'dark';

    function applyTheme() {
      if (document.body) {
        if (isLight) {
          document.body.classList.add('light-theme');
        } else {
          document.body.classList.remove('light-theme');
        }
      }
    }

    // 如果 body 已存在，直接应用
    if (document.body) {
      applyTheme();
    } else {
      // 如果 body 还不存在，使用 MutationObserver 监听 body 的创建
      const observer = new MutationObserver(function(mutations) {
        if (document.body) {
          applyTheme();
          observer.disconnect();
        }
      });
      observer.observe(document.documentElement, {
        childList: true,
        subtree: true
      });
      // 如果 DOMContentLoaded 已经触发，立即检查
      if (document.readyState !== 'loading') {
        applyTheme();
        observer.disconnect();
      }
    }
  } catch (e) {
    console.warn('无法从 localStorage 读取主题设置:', e);
    // 默认浅色模式
    if (document.body) {
      document.body.classList.add('light-theme');
    }
  }
})();
