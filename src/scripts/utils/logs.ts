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
    timestamp: number; // 添加时间戳，用于自动清理
  }

  // 创建全局命名空间
  if (typeof (window as any).AppUtils === 'undefined') {
    (window as any).AppUtils = {};
  }

  const AppUtils = (window as any).AppUtils;

  // 日志存储管理
  AppUtils.Logs = {
    // 上次重置日志的日期
    lastResetDate: '',

    // 检查并执行每天重置
    async checkAndResetDaily(): Promise<void> {
      try {
        const settings = await (window as any).electronAPI?.getSettings();
        if (!settings || !settings.resetLogsDaily) {
          return;
        }

        const today = new Date().toDateString();
        const lastReset = localStorage.getItem('lastLogResetDate');

        if (lastReset !== today) {
          localStorage.setItem('appLogs', '[]');
          localStorage.setItem('lastLogResetDate', today);
          AppUtils.Logs.lastResetDate = today;
        }
      } catch (error) {
        console.error('检查日志重置失败:', error);
      }
    },

    // 检查日志是否启用
    async isEnabled(): Promise<boolean> {
      try {
        const settings = await (window as any).electronAPI?.getSettings();
        return settings?.enableLogs !== false; // 默认启用
      } catch {
        return true; // 默认启用
      }
    },

    // 清理过期日志（超过一个月）
    cleanOldLogs(logs: LogEntry[]): LogEntry[] {
      const oneMonthAgo = Date.now() - (30 * 24 * 60 * 60 * 1000); // 30天前的时间戳
      return logs.filter((log: LogEntry) => {
        // 如果日志没有时间戳，保留（兼容旧日志）
        if (!log.timestamp) {
          return true;
        }
        return log.timestamp > oneMonthAgo;
      });
    },

    // 获取日志
    getLogs(): LogEntry[] {
      try {
        const logs = JSON.parse(localStorage.getItem('appLogs') || '[]');
        // 清理过期日志
        const cleanedLogs = AppUtils.Logs.cleanOldLogs(logs);
        // 如果清理后数量减少，保存清理后的日志
        if (cleanedLogs.length < logs.length) {
          AppUtils.Logs.saveLogs(cleanedLogs);
        }
        return cleanedLogs;
      } catch {
        return [];
      }
    },

    // 保存日志
    saveLogs(logs: LogEntry[]): void {
      // 先清理过期日志
      logs = AppUtils.Logs.cleanOldLogs(logs);

      // 限制日志数量，最多保留 1000 条
      const maxLogs = 1000;
      if (logs.length > maxLogs) {
        logs = logs.slice(-maxLogs);
      }
      localStorage.setItem('appLogs', JSON.stringify(logs));
    },

    // 添加日志
    async addLog(message: string, type: LogType = 'info', logContainer?: HTMLElement): Promise<void> {
      // 检查日志是否启用
      const enabled = await AppUtils.Logs.isEnabled();
      if (!enabled) {
        return;
      }

      // 检查是否需要每天重置
      await AppUtils.Logs.checkAndResetDaily();

      const time = new Date().toLocaleTimeString('zh-CN');
      const timestamp = Date.now(); // 添加时间戳
      const logs = AppUtils.Logs.getLogs();
      logs.push({ time, message, type, timestamp });
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
    },

    // 导出日志
    async exportLogs(): Promise<void> {
      try {
        const logs = AppUtils.Logs.getLogs();
        if (logs.length === 0) {
          alert('没有日志可导出');
          return;
        }

        // 生成日志文本内容
        const logText = logs.map((log: LogEntry) => {
          const typeMap: Record<LogType, string> = {
            info: '信息',
            success: '成功',
            error: '错误',
            warning: '警告'
          };
          return `[${log.time}] [${typeMap[log.type]}] ${log.message}`;
        }).join('\n');

        // 添加文件头信息
        const exportDate = new Date().toLocaleString('zh-CN');
        const header = `Free NTFS for Mac - 操作日志\n导出时间: ${exportDate}\n共 ${logs.length} 条日志\n${'='.repeat(50)}\n\n`;
        const fullContent = header + logText;

        // 使用 electronAPI 保存文件
        const result = await (window as any).electronAPI?.exportLogs(fullContent);
        if (result?.success) {
          alert(`日志已导出到: ${result.path}`);
        } else {
          throw new Error(result?.error || '导出失败');
        }
      } catch (error) {
        console.error('导出日志失败:', error);
        alert(`导出日志失败: ${error instanceof Error ? error.message : String(error)}`);
      }
    }
  };

})();
