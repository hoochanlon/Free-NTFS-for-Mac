// 混合检测管理器 - 事件驱动 + 智能轮询备用
// 优先使用事件驱动（零延迟），如果不可用则降级到智能轮询

import { DeviceDetector } from './device-detector';
import { EventDrivenDetector } from './event-driven-detector';
import { SmartPollingManager } from './smart-polling';
import type { NTFSDevice } from '../../types/electron';

export class HybridDetector {
  private deviceDetector: DeviceDetector;
  private eventDetector: EventDrivenDetector;
  private pollingManager: SmartPollingManager;
  private useEvents: boolean = false;
  private onChangeCallback?: (devices: NTFSDevice[]) => void;
  private currentDevices: NTFSDevice[] = [];
  private backupPollingInterval: NodeJS.Timeout | null = null; // 备用轮询定时器（事件驱动模式下的安全网，使用 setTimeout 而非 setInterval）
  private readonly backupPollingIntervalWithDevices = 12000; // 有设备时每12秒备用检测一次
  private readonly backupPollingIntervalNoDevices = 20000; // 无设备时每20秒备用检测一次（降低频率）

  constructor(deviceDetector: DeviceDetector) {
    this.deviceDetector = deviceDetector;
    this.eventDetector = new EventDrivenDetector(deviceDetector);
    this.pollingManager = new SmartPollingManager();
  }

  /**
   * 初始化混合检测
   */
  async initialize(callback: (devices: NTFSDevice[]) => void): Promise<void> {
    this.onChangeCallback = callback;

    // 尝试使用事件驱动
    const eventSuccess = await this.eventDetector.start((devices) => {
      // 事件驱动时，立即处理（fromEvent=true）
      this.handleDeviceChange(devices, true);
    });

    if (eventSuccess) {
      this.useEvents = true;
      console.log('✅ [混合检测] 使用事件驱动模式（零延迟、极低CPU）');
      // 启动备用轮询机制（作为安全网，确保即使事件丢失也能检测到设备移除）
      this.startBackupPolling();
    } else {
      // 降级到智能轮询
      this.useEvents = false;
      this.pollingManager.start(async () => {
        // 轮询时也使用强制刷新，确保获取最新状态（与刷新按钮行为一致）
        const devices = await this.deviceDetector.getNTFSDevices(true);
        this.handleDeviceChange(devices, false);
      });
      console.log('⚠️ [混合检测] 降级到智能轮询模式（fswatch未安装，建议运行: brew install fswatch）');
      console.log('ℹ️ [混合检测] 已优化轮询间隔，接近即时检测（初始0.5秒，稳定3秒，活跃1秒）');
    }

    // 立即执行一次检测（强制刷新，确保获取最新状态）
    const initialDevices = await this.deviceDetector.getNTFSDevices(true);
    this.handleDeviceChange(initialDevices, this.useEvents);
  }

  /**
   * 处理设备变化
   */
  private handleDeviceChange(devices: NTFSDevice[], fromEvent: boolean): void {
    // 检查是否有实际变化
    const hasChanged = this.hasDeviceListChanged(this.currentDevices, devices);

    // 如果设备数量增加，即使状态没变也认为是变化（可能是新设备插入）
    const deviceCountIncreased = devices.length > this.currentDevices.length;

    // 如果设备数量减少，说明有设备被移除，必须更新
    const deviceCountDecreased = devices.length < this.currentDevices.length;

    // 事件驱动模式下，每次都更新（确保不遗漏，特别是设备移除时）
    // 轮询模式下，只在有变化时更新
    if (fromEvent || hasChanged || deviceCountIncreased || deviceCountDecreased) {
      this.currentDevices = devices;

      // 更新轮询管理器状态
      if (!this.useEvents) {
        this.pollingManager.updateDeviceState(
          devices.length > 0,
          hasChanged || deviceCountIncreased || deviceCountDecreased
        );
      }

      // 调用回调（事件驱动模式下每次都调用，确保UI更新，特别是设备移除时）
      if (this.onChangeCallback) {
        this.onChangeCallback(devices);
      }
    }
  }

  /**
   * 检查设备列表是否有变化
   */
  private hasDeviceListChanged(oldDevices: NTFSDevice[], newDevices: NTFSDevice[]): boolean {
    // 如果数量不同，肯定有变化
    if (oldDevices.length !== newDevices.length) {
      return true;
    }

    // 比较设备状态
    const oldMap = new Map(oldDevices.map(d => [d.disk, {
      volumeName: d.volumeName,
      isMounted: d.isMounted,
      isReadOnly: d.isReadOnly
    }]));
    const newMap = new Map(newDevices.map(d => [d.disk, {
      volumeName: d.volumeName,
      isMounted: d.isMounted,
      isReadOnly: d.isReadOnly
    }]));

    // 检查是否有新增或删除（通过 disk 标识）
    if (oldMap.size !== newMap.size) {
      return true;
    }

    // 检查是否有新设备（disk 不在旧列表中）
    for (const [disk] of newMap) {
      if (!oldMap.has(disk)) {
        return true; // 有新设备
      }
    }

    // 检查是否有设备被移除（disk 不在新列表中）
    for (const [disk] of oldMap) {
      if (!newMap.has(disk)) {
        return true; // 有设备被移除
      }
    }

    // 检查是否有状态变化
    for (const [disk, oldState] of oldMap) {
      const newState = newMap.get(disk);
      if (!newState ||
          newState.volumeName !== oldState.volumeName ||
          newState.isMounted !== oldState.isMounted ||
          newState.isReadOnly !== oldState.isReadOnly) {
        return true;
      }
    }

    return false;
  }

  /**
   * 更新窗口可见性
   */
  updateWindowVisibility(isVisible: boolean): void {
    if (!this.useEvents) {
      this.pollingManager.updateWindowVisibility(isVisible);
    }
  }

  /**
   * 启动备用轮询（事件驱动模式下的安全网）
   * 优化：根据设备状态动态调整检测频率，降低CPU使用
   */
  private startBackupPolling(): void {
    const performBackupCheck = async () => {
      if (!this.useEvents || !this.onChangeCallback) {
        // 如果已切换到轮询模式或回调已清除，停止备用轮询
        if (this.backupPollingInterval) {
          clearTimeout(this.backupPollingInterval);
          this.backupPollingInterval = null;
        }
        return;
      }

      try {
        // 静默检测设备状态
        const currentDevices = await this.deviceDetector.getNTFSDevices(true);

        // 检查是否有变化（特别是设备移除）
        const hasChanged = this.hasDeviceListChanged(this.currentDevices, currentDevices);
        const deviceCountDecreased = currentDevices.length < this.currentDevices.length;

        if (hasChanged || deviceCountDecreased) {
          console.log(`[混合检测] 备用检测：发现设备变化（${this.currentDevices.length} -> ${currentDevices.length}），触发更新`);
          this.handleDeviceChange(currentDevices, false); // 使用 fromEvent=false，因为这是备用检测
        }

        // 根据设备状态动态调整下次检测间隔
        const hasDevices = currentDevices.length > 0;
        const nextInterval = hasDevices
          ? this.backupPollingIntervalWithDevices  // 有设备时12秒
          : this.backupPollingIntervalNoDevices;   // 无设备时20秒（降低频率）

        // 清除旧的定时器并重新调度
        if (this.backupPollingInterval) {
          clearTimeout(this.backupPollingInterval);
        }
        this.backupPollingInterval = setTimeout(performBackupCheck, nextInterval);
      } catch (error) {
        console.error('[混合检测] 备用检测失败:', error);
        // 出错时也重新调度，但使用较长的间隔
        if (this.backupPollingInterval) {
          clearTimeout(this.backupPollingInterval);
        }
        this.backupPollingInterval = setTimeout(performBackupCheck, this.backupPollingIntervalNoDevices);
      }
    };

    // 立即执行一次检测
    performBackupCheck();
  }

  /**
   * 停止检测
   */
  stop(): void {
    if (this.useEvents) {
      this.eventDetector.stop();
    } else {
      this.pollingManager.stop();
    }

    if (this.backupPollingInterval) {
      clearTimeout(this.backupPollingInterval);
      this.backupPollingInterval = null;
    }

    this.onChangeCallback = undefined;
  }

  /**
   * 强制立即检测一次
   */
  async forceDetect(): Promise<NTFSDevice[]> {
    // 强制刷新，失效所有缓存
    const devices = await this.deviceDetector.getNTFSDevices(true);
    this.handleDeviceChange(devices, false);
    return devices;
  }

  /**
   * 获取当前模式
   */
  getMode(): 'event-driven' | 'polling' {
    return this.useEvents ? 'event-driven' : 'polling';
  }

  /**
   * 获取状态信息（用于调试）
   */
  getStatus(): {
    mode: 'event-driven' | 'polling';
    isEventActive: boolean;
    pollingInterval?: number;
  } {
    return {
      mode: this.getMode(),
      isEventActive: this.eventDetector.isActive(),
      pollingInterval: this.useEvents ? undefined : this.pollingManager.getCurrentInterval()
    };
  }

  /**
   * 检查是否可以切换到事件驱动模式
   */
  async checkEventDrivenAvailable(): Promise<boolean> {
    return await this.eventDetector.checkFswatchAvailable();
  }
}
