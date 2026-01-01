// 在页面加载前初始化主题，避免闪烁
(function() {
  try {
    const savedTheme = localStorage.getItem('app-theme');
    if (savedTheme === 'light' && document.body) {
      document.body.classList.add('light-theme');
    }
  } catch (e) {
    console.warn('无法从 localStorage 读取主题设置:', e);
  }
})();
