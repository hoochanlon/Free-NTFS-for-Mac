// 日志管理工具模块
// 注意：不使用 import，避免生成 CommonJS 代码（浏览器环境不支持）

(function() {
  'use strict';

  // 类型定义
  type LogType = 'info' | 'success' | 'error' | 'warning';

  // 日志接口
  interface LogEntry {
    time: string;
    message: string;
    type: LogType;
  }

  // 创建全局命名空间
  if (typeof (window as any).AppUtils === 'undefined') {
    (window as any).AppUtils = {};
  }

  const AppUtils = (window as any).AppUtils;

  // 日志存储管理
  AppUtils.Logs = {
    // 获取日志
    getLogs(): LogEntry[] {
      try {
        return JSON.parse(localStorage.getItem('appLogs') || '[]');
      } catch {
        return [];
      }
    },

    // 保存日志
    saveLogs(logs: LogEntry[]): void {
      // 限制日志数量，最多保留 1000 条
      const maxLogs = 1000;
      if (logs.length > maxLogs) {
        logs = logs.slice(-maxLogs);
      }
      localStorage.setItem('appLogs', JSON.stringify(logs));
    },

    // 添加日志
    addLog(message: string, type: LogType = 'info', logContainer?: HTMLElement): void {
      const time = new Date().toLocaleTimeString('zh-CN');
      const logs = AppUtils.Logs.getLogs();
      logs.push({ time, message, type });
      AppUtils.Logs.saveLogs(logs);

      // 如果提供了日志容器且日志标签页是活动的，立即更新显示
      if (logContainer) {
        const logsTab = document.getElementById('logsTab');
        if (logsTab && logsTab.classList.contains('active')) {
          // 添加新日志时强制更新
          AppUtils.Logs.renderLogs(logContainer, true);
        }
      }
    },

    // 渲染日志
    renderLogs(logContainer: HTMLElement, forceUpdate: boolean = false): void {
      const logs = AppUtils.Logs.getLogs();

      if (logs.length === 0) {
        if (logContainer.innerHTML !== '<div class="log-empty">暂无日志</div>') {
          logContainer.innerHTML = '<div class="log-empty">暂无日志</div>';
        }
        return;
      }

      // 检查是否需要更新（避免不必要的重渲染）
      const currentLogCount = logContainer.querySelectorAll('.log-entry').length;
      if (!forceUpdate && currentLogCount === logs.length) {
        // 日志数量没有变化，不需要更新
        return;
      }

      // 保存当前滚动位置
      const wasScrolledToBottom =
        logContainer.scrollHeight - logContainer.scrollTop <= logContainer.clientHeight + 10;

      // 只更新新增的日志条目，而不是重建整个列表
      const existingEntries = logContainer.querySelectorAll('.log-entry');
      const existingCount = existingEntries.length;

      if (existingCount < logs.length) {
        // 只添加新的日志条目
        for (let i = existingCount; i < logs.length; i++) {
          const log = logs[i];
          const logEntry = document.createElement('div');
          logEntry.className = `log-entry ${log.type}`;
          logEntry.innerHTML = `<span class="log-time">[${log.time}]</span>${log.message}`;
          logContainer.appendChild(logEntry);
        }

        // 如果之前滚动到底部，保持滚动到底部
        if (wasScrolledToBottom) {
          logContainer.scrollTop = logContainer.scrollHeight;
        }
      } else if (forceUpdate || existingCount !== logs.length) {
        // 如果日志数量减少或强制更新，重建整个列表
        logContainer.innerHTML = '';
        logs.forEach((log: LogEntry) => {
          const logEntry = document.createElement('div');
          logEntry.className = `log-entry ${log.type}`;
          logEntry.innerHTML = `<span class="log-time">[${log.time}]</span>${log.message}`;
          logContainer.appendChild(logEntry);
        });

        // 滚动到底部
        logContainer.scrollTop = logContainer.scrollHeight;
      }
    },

    // 清空日志
    clearLog(logContainer: HTMLElement): void {
      if (confirm('确定要清空所有日志吗？')) {
        localStorage.setItem('appLogs', '[]');
        AppUtils.Logs.renderLogs(logContainer, true);
      }
    }
  };

})();
