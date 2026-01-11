// logs.html 的内联脚本
(function() {
  'use strict';

  const logContainer = document.getElementById('logContainer');
  const clearLogBtn = document.getElementById('clearLogBtn');
  const closeBtn = document.getElementById('closeBtn');

  // 从 localStorage 加载日志
  function loadLogs() {
    const logs = JSON.parse(localStorage.getItem('appLogs') || '[]');

    if (logs.length === 0) {
      logContainer!.innerHTML = '<div class="log-empty">暂无日志</div>';
      return;
    }

    logContainer!.innerHTML = '';
    logs.forEach((log: any) => {
      const logEntry = document.createElement('div');
      logEntry.className = `log-entry ${log.type}`;
      logEntry.innerHTML = `<span class="log-time">[${log.time}]</span>${log.message}`;
      logContainer!.appendChild(logEntry);
    });

    // 滚动到底部
    logContainer!.scrollTop = logContainer!.scrollHeight;
  }

  // 清空日志
  async function clearLogs() {
    if ((window as any).AppUtils && (window as any).AppUtils.UI) {
      const t = (window as any).AppUtils && (window as any).AppUtils.I18n ? (window as any).AppUtils.I18n.t : ((key: string) => key);
      const confirmTitle = t('dialog.confirm') || '确认';
      const confirmText = t('logs.clearConfirm') || '确定要清空所有日志吗？';
      const confirmed = await (window as any).AppUtils.UI.showConfirm(confirmTitle, confirmText);
      if (confirmed) {
        localStorage.setItem('appLogs', '[]');
        loadLogs();
      }
    } else {
      // 回退方案（不应该发生）
      if (confirm('确定要清空所有日志吗？')) {
        localStorage.setItem('appLogs', '[]');
        loadLogs();
      }
    }
  }

  // 监听日志更新事件（跨窗口）
  window.addEventListener('storage', (e) => {
    if (e.key === 'appLogs') {
      loadLogs();
    }
  });

  // 定期检查日志更新（用于同窗口内的更新）
  let lastLogCount = 0;
  setInterval(() => {
    const logs = JSON.parse(localStorage.getItem('appLogs') || '[]');
    if (logs.length !== lastLogCount) {
      lastLogCount = logs.length;
      loadLogs();
    }
  }, 300);

  // 关闭窗口
  async function closeWindow() {
    try {
      if ((window as any).electronAPI && (window as any).electronAPI.closeLogsWindow) {
        await (window as any).electronAPI.closeLogsWindow();
      } else if ((window as any).electronAPI && (window as any).electronAPI.closeModuleWindow) {
        await (window as any).electronAPI.closeModuleWindow();
      } else {
        window.close();
      }
    } catch (error) {
      window.close();
    }
  }

  // 事件监听
  clearLogBtn!.addEventListener('click', clearLogs);
  closeBtn!.addEventListener('click', closeWindow);

  // 初始化加载日志
  loadLogs();
})();
