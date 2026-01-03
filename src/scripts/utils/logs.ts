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

  // 获取翻译文本的辅助函数
  function t(key: string, params?: Record<string, string | number>): string {
    if (AppUtils && AppUtils.I18n) {
      return AppUtils.I18n.t(key, params);
    }
    return key; // 如果 i18n 未初始化，返回 key
  }

  // 日志存储管理
  AppUtils.Logs = {
    // 上次重置日志的日期
    lastResetDate: '',

    // 检查并执行每天重置
    async checkAndResetDaily(): Promise<void> {
      // 每日自动重置功能已移除
      // 此函数保留为空，避免破坏现有代码结构
    },

    // 检查日志是否启用
    async isEnabled(): Promise<boolean> {
      try {
        const settings = await (window as any).electronAPI?.getSettings();
        return settings?.enableLogs === true; // 默认关闭，需要手动开启
      } catch {
        return false; // 默认关闭
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

      // 获取当前语言设置，用于格式化时间
      const currentLang = AppUtils.I18n ? AppUtils.I18n.getLanguage() : 'zh-CN';
      let locale = 'zh-CN';
      if (currentLang === 'en') {
        locale = 'en-US';
      } else if (currentLang === 'ja') {
        locale = 'ja-JP';
      } else if (currentLang === 'zh-TW') {
        locale = 'zh-TW';
      } else {
        locale = 'zh-CN';
      }
      const time = new Date().toLocaleTimeString(locale);
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
        const emptyText = t('logs.empty');
        if (logContainer.innerHTML !== `<div class="log-empty">${emptyText}</div>`) {
          logContainer.innerHTML = `<div class="log-empty">${emptyText}</div>`;
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
      if (confirm(t('logs.clearConfirm'))) {
        localStorage.setItem('appLogs', '[]');
        AppUtils.Logs.renderLogs(logContainer, true);
      }
    },

    // 导出日志
    async exportLogs(): Promise<void> {
      try {
        const logs = AppUtils.Logs.getLogs();
        if (logs.length === 0) {
          alert(t('logs.noLogsToExport'));
          return;
        }

        // 生成日志文本内容
        const logText = logs.map((log: LogEntry) => {
          const typeMap: Record<LogType, string> = {
            info: t('logs.logTypes.info'),
            success: t('logs.logTypes.success'),
            error: t('logs.logTypes.error'),
            warning: t('logs.logTypes.warning')
          };
          return `[${log.time}] [${typeMap[log.type]}] ${log.message}`;
        }).join('\n');

        // 添加文件头信息
        const currentLang = AppUtils.I18n ? AppUtils.I18n.getLanguage() : 'zh-CN';
        let locale = 'zh-CN';
        if (currentLang === 'en') {
          locale = 'en-US';
        } else if (currentLang === 'ja') {
          locale = 'ja-JP';
        } else if (currentLang === 'zh-TW') {
          locale = 'zh-TW';
        } else {
          locale = 'zh-CN';
        }
        const exportDate = new Date().toLocaleString(locale);
        const header = `${t('logs.exportHeader')}\n${t('logs.exportTime', { time: exportDate })}\n${t('logs.exportCount', { count: logs.length })}\n${'='.repeat(50)}\n\n`;
        const fullContent = header + logText;

        // 使用 electronAPI 保存文件
        const result = await (window as any).electronAPI?.exportLogs(fullContent);
        if (result?.success) {
          alert(t('logs.exportPath', { path: result.path }));
        } else {
          throw new Error(result?.error || t('logs.exportError'));
        }
      } catch (error) {
        console.error('导出日志失败:', error);
        alert(`${t('logs.exportError')}: ${error instanceof Error ? error.message : String(error)}`);
      }
    }
  };

})();
