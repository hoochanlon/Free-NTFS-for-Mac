// UI更新优化器 - 防抖、节流、增量更新
// 优化策略：
// 1. 防抖：短时间内多次更新只执行最后一次
// 2. 节流：限制更新频率
// 3. 增量更新：只更新变化的部分
// 4. 批量DOM操作：减少重排和重绘

export class UIOptimizer {
  private debounceTimers: Map<string, number> = new Map();
  private throttleTimers: Map<string, number> = new Map();
  private lastUpdateTime: Map<string, number> = new Map();

  /**
   * 防抖：延迟执行，如果短时间内多次调用，只执行最后一次
   * @param key 唯一标识
   * @param fn 要执行的函数
   * @param delay 延迟时间（毫秒）
   */
  debounce<T extends (...args: any[]) => void>(key: string, fn: T, delay: number = 300): T {
    return ((...args: any[]) => {
      const existingTimer = this.debounceTimers.get(key);
      if (existingTimer) {
        clearTimeout(existingTimer);
      }

      const timer = window.setTimeout(() => {
        fn(...args);
        this.debounceTimers.delete(key);
      }, delay);

      this.debounceTimers.set(key, timer);
    }) as T;
  }

  /**
   * 节流：限制执行频率，在指定时间内最多执行一次
   * @param key 唯一标识
   * @param fn 要执行的函数
   * @param interval 时间间隔（毫秒）
   */
  throttle<T extends (...args: any[]) => void>(key: string, fn: T, interval: number = 1000): T {
    return ((...args: any[]) => {
      const now = Date.now();
      const lastTime = this.lastUpdateTime.get(key) || 0;

      if (now - lastTime >= interval) {
        fn(...args);
        this.lastUpdateTime.set(key, now);
      } else {
        // 如果还在节流期内，清除之前的定时器，设置新的
        const existingTimer = this.throttleTimers.get(key);
        if (existingTimer) {
          clearTimeout(existingTimer);
        }

        const timer = window.setTimeout(() => {
          fn(...args);
          this.lastUpdateTime.set(key, Date.now());
          this.throttleTimers.delete(key);
        }, interval - (now - lastTime));

        this.throttleTimers.set(key, timer);
      }
    }) as T;
  }

  /**
   * 批量DOM操作：使用requestAnimationFrame优化
   * @param operations DOM操作函数数组
   */
  batchDOMOperations(operations: Array<() => void>): void {
    if (operations.length === 0) return;

    // 使用requestAnimationFrame确保在下一帧执行
    requestAnimationFrame(() => {
      // 使用DocumentFragment减少重排
      const fragment = document.createDocumentFragment();

      operations.forEach(op => {
        try {
          op();
        } catch (error) {
          console.error('DOM操作失败:', error);
        }
      });
    });
  }

  /**
   * 增量更新：比较新旧数据，只更新变化的部分
   * @param oldData 旧数据
   * @param newData 新数据
   * @param keyFn 获取唯一键的函数
   * @param updateFn 更新函数
   * @param createFn 创建函数
   * @param removeFn 删除函数
   */
  incrementalUpdate<T>(
    oldData: T[],
    newData: T[],
    keyFn: (item: T) => string,
    updateFn: (oldItem: T, newItem: T) => void,
    createFn: (item: T) => void,
    removeFn: (item: T) => void
  ): void {
    const oldMap = new Map(oldData.map(item => [keyFn(item), item]));
    const newMap = new Map(newData.map(item => [keyFn(item), item]));

    // 找出需要删除的
    for (const [key, item] of oldMap) {
      if (!newMap.has(key)) {
        removeFn(item);
      }
    }

    // 找出需要创建或更新的
    for (const [key, newItem] of newMap) {
      const oldItem = oldMap.get(key);
      if (oldItem) {
        // 检查是否有变化
        if (JSON.stringify(oldItem) !== JSON.stringify(newItem)) {
          updateFn(oldItem, newItem);
        }
      } else {
        createFn(newItem);
      }
    }
  }

  /**
   * 清理所有定时器
   */
  cleanup(): void {
    for (const timer of this.debounceTimers.values()) {
      clearTimeout(timer);
    }
    for (const timer of this.throttleTimers.values()) {
      clearTimeout(timer);
    }
    this.debounceTimers.clear();
    this.throttleTimers.clear();
    this.lastUpdateTime.clear();
  }

  /**
   * 清理特定key的定时器
   */
  cleanupKey(key: string): void {
    const debounceTimer = this.debounceTimers.get(key);
    if (debounceTimer) {
      clearTimeout(debounceTimer);
      this.debounceTimers.delete(key);
    }

    const throttleTimer = this.throttleTimers.get(key);
    if (throttleTimer) {
      clearTimeout(throttleTimer);
      this.throttleTimers.delete(key);
    }

    this.lastUpdateTime.delete(key);
  }
}

// 全局单例
export const uiOptimizer = new UIOptimizer();
