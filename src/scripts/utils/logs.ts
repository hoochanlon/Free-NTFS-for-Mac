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

    // 清理过期日志（超过30天）
    cleanOldLogs(logs: LogEntry[]): LogEntry[] {
      const thirtyDaysAgo = Date.now() - (30 * 24 * 60 * 60 * 1000); // 30天前的时间戳
      return logs.filter((log: LogEntry) => {
        // 如果日志没有时间戳，视为旧日志，删除（不再兼容，避免累积）
        if (!log.timestamp) {
          return false;
        }
        return log.timestamp > thirtyDaysAgo;
      });
    },

    // 获取日志（从文件系统读取）
    async getLogs(): Promise<LogEntry[]> {
      try {
        // 优先从文件系统读取
        if ((window as any).electronAPI?.readLogsFile) {
          const result = await (window as any).electronAPI.readLogsFile();
          if (result.success) {
            // 如果文件不存在，content 可能是 undefined，使用空数组
            const content = result.content || '[]';
            try {
              const logs = JSON.parse(content);
              // 确保 logs 是数组
              if (!Array.isArray(logs)) {
                console.warn('日志文件格式错误，不是数组，重置为空数组');
                return [];
              }
              // 清理过期日志
              const cleanedLogs = AppUtils.Logs.cleanOldLogs(logs);
              // 如果清理后数量减少，保存清理后的日志
              if (cleanedLogs.length < logs.length) {
                await AppUtils.Logs.saveLogs(cleanedLogs);
              }
              return cleanedLogs;
            } catch (parseError) {
              console.error('解析日志文件失败:', parseError);
              // 如果解析失败，尝试从 localStorage 恢复
              return await this.fallbackToLocalStorage();
            }
          } else {
            console.warn('读取日志文件失败:', result.error);
            // 如果读取失败，尝试从 localStorage 恢复
            return await this.fallbackToLocalStorage();
          }
        }

        // 如果没有 electronAPI，直接使用 localStorage
        return await this.fallbackToLocalStorage();
      } catch (error) {
        console.error('获取日志失败:', error);
        return [];
      }
    },

    // 从 localStorage 读取日志（兼容旧版本和回退方案）
    async fallbackToLocalStorage(): Promise<LogEntry[]> {
      try {
        const logs = JSON.parse(localStorage.getItem('appLogs') || '[]');
        if (!Array.isArray(logs)) {
          return [];
        }
        const cleanedLogs = AppUtils.Logs.cleanOldLogs(logs);
        if (cleanedLogs.length < logs.length) {
          await AppUtils.Logs.saveLogs(cleanedLogs);
        }
        // 迁移到文件系统
        if (cleanedLogs.length > 0) {
          await AppUtils.Logs.saveLogs(cleanedLogs);
          localStorage.removeItem('appLogs'); // 迁移后删除旧数据
        }
        return cleanedLogs;
      } catch {
        return [];
      }
    },

    // 保存日志（保存到文件系统）
    async saveLogs(logs: LogEntry[]): Promise<void> {
      // 先清理过期日志（超过30天）
      logs = AppUtils.Logs.cleanOldLogs(logs);

      // 限制日志数量，最多保留 500 条（防止数据过大导致卡顿）
      const maxLogs = 500;
      if (logs.length > maxLogs) {
        logs = logs.slice(-maxLogs); // 保留最新的500条
      }

      // 限制日志数据大小（防止文件过大）
      try {
        const jsonString = JSON.stringify(logs, null, 2); // 格式化JSON，便于查看
        const maxSize = 500 * 1024; // 最大500KB
        if (jsonString.length > maxSize) {
          // 如果超过大小限制，进一步减少日志数量
          const targetSize = maxSize * 0.8; // 目标大小（留20%余量）
          const avgLogSize = jsonString.length / logs.length;
          const targetCount = Math.floor(targetSize / avgLogSize);
          logs = logs.slice(-Math.min(targetCount, maxLogs));
        }

        // 优先保存到文件系统
        if ((window as any).electronAPI?.writeLogsFile) {
          const finalJsonString = JSON.stringify(logs, null, 2);
          const result = await (window as any).electronAPI.writeLogsFile(finalJsonString);
          if (!result.success) {
            throw new Error(result.error || '保存失败');
          }
        } else {
          // 回退到 localStorage（兼容旧版本）
          localStorage.setItem('appLogs', JSON.stringify(logs));
        }
      } catch (error) {
        console.error('保存日志失败，可能是数据过大:', error);
        // 如果保存失败，尝试只保留最新的100条
        const fallbackLogs = logs.slice(-100);
        try {
          if ((window as any).electronAPI?.writeLogsFile) {
            await (window as any).electronAPI.writeLogsFile(JSON.stringify(fallbackLogs, null, 2));
          } else {
            localStorage.setItem('appLogs', JSON.stringify(fallbackLogs));
          }
        } catch (e) {
          console.error('保存日志失败，清空日志:', e);
          if ((window as any).electronAPI?.writeLogsFile) {
            await (window as any).electronAPI.writeLogsFile('[]');
          } else {
            localStorage.setItem('appLogs', '[]');
          }
        }
      }
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
      const logs = await AppUtils.Logs.getLogs();

      // 添加新日志前，先检查并清理（防止日志累积过多）
      const cleanedLogs = AppUtils.Logs.cleanOldLogs(logs);

      // 添加新日志
      cleanedLogs.push({ time, message, type, timestamp });

      // 保存（内部会再次清理并限制数量）
      await AppUtils.Logs.saveLogs(cleanedLogs);

      // 如果提供了日志容器且日志标签页是活动的，立即更新显示
      if (logContainer) {
        const logsTab = document.getElementById('logsTab');
        if (logsTab && logsTab.classList.contains('active')) {
          // 添加新日志时强制更新
          await AppUtils.Logs.renderLogs(logContainer, true);
        }
      }
    },

    // 渲染日志（优化性能，限制显示数量）
    async renderLogs(logContainer: HTMLElement, forceUpdate: boolean = false): Promise<void> {
      const allLogs = await AppUtils.Logs.getLogs();

      if (allLogs.length === 0) {
        const emptyText = t('logs.empty');
        if (logContainer.innerHTML !== `<div class="log-empty">${emptyText}</div>`) {
          logContainer.innerHTML = `<div class="log-empty">${emptyText}</div>`;
        }
        return;
      }

      // 限制显示数量，最多显示300条（防止DOM元素过多导致卡顿）
      const maxDisplayLogs = 300;
      const logs = allLogs.slice(-maxDisplayLogs); // 只显示最新的300条

      // 清除"暂无日志"提示（如果有）
      const emptyElement = logContainer.querySelector('.log-empty');
      if (emptyElement) {
        emptyElement.remove();
      }

      // 检查是否需要更新（避免不必要的重渲染）
      const currentLogCount = logContainer.querySelectorAll('.log-entry').length;
      if (!forceUpdate && currentLogCount === logs.length && currentLogCount > 0) {
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
        // 只添加新的日志条目（批量添加，提高性能）
        const fragment = document.createDocumentFragment();
        for (let i = existingCount; i < logs.length; i++) {
          const log = logs[i];
          const logEntry = document.createElement('div');
          logEntry.className = `log-entry ${log.type}`;
          logEntry.innerHTML = `<span class="log-time">[${log.time}]</span>${log.message}`;
          fragment.appendChild(logEntry);
        }
        logContainer.appendChild(fragment);

        // 如果之前滚动到底部，保持滚动到底部
        if (wasScrolledToBottom) {
          logContainer.scrollTop = logContainer.scrollHeight;
        }
      } else if (forceUpdate || existingCount !== logs.length) {
        // 如果日志数量减少或强制更新，重建整个列表（使用DocumentFragment优化）
        const fragment = document.createDocumentFragment();
        logs.forEach((log: LogEntry) => {
          const logEntry = document.createElement('div');
          logEntry.className = `log-entry ${log.type}`;
          logEntry.innerHTML = `<span class="log-time">[${log.time}]</span>${log.message}`;
          fragment.appendChild(logEntry);
        });
        logContainer.innerHTML = '';
        logContainer.appendChild(fragment);

        // 滚动到底部
        logContainer.scrollTop = logContainer.scrollHeight;
      }
    },

    // 清空日志
    async clearLog(logContainer: HTMLElement): Promise<void> {
      // 直接清空，不需要确认弹窗
      // 清空文件系统中的日志
      if ((window as any).electronAPI?.writeLogsFile) {
        await (window as any).electronAPI.writeLogsFile('[]');
      } else {
        localStorage.setItem('appLogs', '[]');
      }
      await AppUtils.Logs.renderLogs(logContainer, true);
    },

    // 导出日志
    async exportLogs(): Promise<void> {
      try {
        const logs = await AppUtils.Logs.getLogs();
        if (logs.length === 0) {
          // 没有日志时不显示弹窗，静默返回
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

        // 使用 electronAPI 保存文件（不显示弹窗）
        await (window as any).electronAPI?.exportLogs(fullContent);
      } catch (error) {
        // 静默处理错误，不显示弹窗
        console.error('导出日志失败:', error);
      }
    }
  };

})();
