// 智能轮询管理器 - 根据设备状态动态调整检测间隔
// 优化策略：
// 1. 无设备时：降低检测频率（30秒）
// 2. 有设备但无变化：中等频率（10秒）
// 3. 设备状态变化：立即检测 + 短暂高频（2秒，持续3次）
// 4. 窗口不可见：暂停检测或大幅降低频率（60秒）

export interface PollingState {
  hasDevices: boolean;
  lastChangeTime: number;
  consecutiveChanges: number;
  isWindowVisible: boolean;
  lastPollTime: number;
}

export class SmartPollingManager {
  private state: PollingState = {
    hasDevices: false,
    lastChangeTime: 0,
    consecutiveChanges: 0,
    isWindowVisible: true,
    lastPollTime: 0
  };

  private currentInterval: number | null = null;
  private pollingCallback: (() => Promise<void>) | null = null;
  private readonly intervals = {
    // 无设备时的间隔（5秒，减少等待时间）
    noDevices: 5000,
    // 有设备但稳定的间隔（3秒，提高响应速度）
    stable: 3000,
    // 设备变化后的高频间隔（1秒，更快响应）
    active: 1000,
    // 窗口不可见时的间隔（10秒，即使隐藏也保持较快检测）
    hidden: 10000,
    // 初始检测间隔（0.5秒，立即开始检测）
    initial: 500
  };

  private readonly maxConsecutiveChanges = 3; // 连续变化次数阈值

  /**
   * 启动智能轮询
   * @param callback 检测回调函数
   */
  start(callback: () => Promise<void>): void {
    this.pollingCallback = callback;
    this.scheduleNextPoll(this.intervals.initial);
  }

  /**
   * 停止轮询
   */
  stop(): void {
    if (this.currentInterval !== null) {
      clearTimeout(this.currentInterval);
      this.currentInterval = null;
    }
  }

  /**
   * 更新设备状态
   * @param hasDevices 是否有设备
   * @param hasChanged 设备状态是否发生变化
   */
  updateDeviceState(hasDevices: boolean, hasChanged: boolean): void {
    const now = Date.now();

    if (hasChanged) {
      this.state.lastChangeTime = now;
      this.state.consecutiveChanges += 1;
    } else {
      // 如果超过5秒没有变化，重置连续变化计数
      if (now - this.state.lastChangeTime > 5000) {
        this.state.consecutiveChanges = 0;
      }
    }

    this.state.hasDevices = hasDevices;
    this.state.lastPollTime = now;

    // 如果状态变化，立即触发检测并重新调度
    if (hasChanged) {
      // 立即执行一次检测（类似刷新按钮的行为）
      if (this.pollingCallback) {
        this.pollingCallback().catch(error => {
          console.error('立即检测失败:', error);
        });

        // 连续插入多块U盘时，多次检测确保不遗漏
        setTimeout(() => {
          if (this.pollingCallback) {
            this.pollingCallback().catch(error => {
              console.error('二次检测失败:', error);
            });
          }
        }, 500);

        // 第三次检测，确保捕获所有设备
        setTimeout(() => {
          if (this.pollingCallback) {
            this.pollingCallback().catch(error => {
              console.error('三次检测失败:', error);
            });
          }
        }, 1000);
      }
      this.reschedule();
    }
  }

  /**
   * 更新窗口可见性
   * @param isVisible 窗口是否可见
   */
  updateWindowVisibility(isVisible: boolean): void {
    if (this.state.isWindowVisible !== isVisible) {
      this.state.isWindowVisible = isVisible;
      this.reschedule();
    }
  }

  /**
   * 重新调度轮询
   */
  private reschedule(): void {
    this.stop();
    const nextInterval = this.calculateNextInterval();
    this.scheduleNextPoll(nextInterval);
  }

  /**
   * 计算下一次轮询间隔
   */
  private calculateNextInterval(): number {
    // 窗口不可见时，使用隐藏间隔
    if (!this.state.isWindowVisible) {
      return this.intervals.hidden;
    }

    // 无设备时，使用长间隔
    if (!this.state.hasDevices) {
      return this.intervals.noDevices;
    }

    // 如果最近有变化且连续变化次数未超过阈值，使用高频间隔
    const timeSinceLastChange = Date.now() - this.state.lastChangeTime;
    if (this.state.consecutiveChanges > 0 &&
        this.state.consecutiveChanges <= this.maxConsecutiveChanges &&
        timeSinceLastChange < 15000) { // 延长到15秒，保持更长时间的高频检测
      return this.intervals.active;
    }

    // 默认使用稳定间隔
    return this.intervals.stable;
  }

  /**
   * 安排下一次轮询
   */
  private scheduleNextPoll(interval: number): void {
    this.currentInterval = window.setTimeout(async () => {
      if (this.pollingCallback) {
        try {
          await this.pollingCallback();
        } catch (error) {
          console.error('轮询回调执行失败:', error);
        }
      }
      // 执行完后，根据当前状态重新调度
      this.reschedule();
    }, interval);
  }

  /**
   * 获取当前轮询间隔（用于调试）
   */
  getCurrentInterval(): number {
    return this.calculateNextInterval();
  }

  /**
   * 获取当前状态（用于调试）
   */
  getState(): PollingState {
    return { ...this.state };
  }

  /**
   * 强制立即执行一次检测（用于手动刷新）
   */
  async forcePoll(): Promise<void> {
    if (this.pollingCallback) {
      await this.pollingCallback();
      this.reschedule();
    }
  }
}
