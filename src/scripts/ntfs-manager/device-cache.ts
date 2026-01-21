// 设备检测结果缓存管理器
// 优化策略：
// 1. 缓存设备列表，避免重复检测
// 2. 缓存系统命令结果（mount, diskutil等）
// 3. 智能失效策略（设备变化时失效）
// 4. 减少不必要的系统调用

import type { NTFSDevice } from '../../types/electron';

export interface CacheEntry<T> {
  data: T;
  timestamp: number;
  ttl: number; // 生存时间（毫秒）
}

export class DeviceCacheManager {
  private deviceListCache: CacheEntry<NTFSDevice[]> | null = null;
  private mountInfoCache: CacheEntry<string> | null = null;
  private diskutilListCache: CacheEntry<string> | null = null; // diskutil list 缓存
  private diskutilCache: Map<string, CacheEntry<string>> = new Map();

  // 不同数据的缓存TTL（优化：大幅减少TTL以加快响应速度，接近即时检测）
  private readonly ttl = {
    deviceList: 200,       // 设备列表：0.2秒（接近即时）
    mountInfo: 100,        // 挂载信息：0.1秒（接近即时）
    diskutil: 500,         // diskutil信息：0.5秒（减少）
    capacity: 2000         // 容量信息：2秒（减少）
  };

  /**
   * 获取缓存的设备列表
   */
  getDeviceList(): NTFSDevice[] | null {
    if (this.deviceListCache && this.isValid(this.deviceListCache)) {
      return this.deviceListCache.data;
    }
    return null;
  }

  /**
   * 设置设备列表缓存
   */
  setDeviceList(devices: NTFSDevice[]): void {
    this.deviceListCache = {
      data: devices,
      timestamp: Date.now(),
      ttl: this.ttl.deviceList
    };
  }

  /**
   * 获取缓存的挂载信息
   */
  getMountInfo(): string | null {
    if (this.mountInfoCache && this.isValid(this.mountInfoCache)) {
      return this.mountInfoCache.data;
    }
    return null;
  }

  /**
   * 设置挂载信息缓存
   */
  setMountInfo(info: string): void {
    this.mountInfoCache = {
      data: info,
      timestamp: Date.now(),
      ttl: this.ttl.mountInfo
    };
  }

  /**
   * 获取缓存的diskutil信息
   */
  getDiskutilInfo(devicePath: string): string | null {
    const entry = this.diskutilCache.get(devicePath);
    if (entry && this.isValid(entry)) {
      return entry.data;
    }
    return null;
  }

  /**
   * 设置diskutil信息缓存
   */
  setDiskutilInfo(devicePath: string, info: string): void {
    this.diskutilCache.set(devicePath, {
      data: info,
      timestamp: Date.now(),
      ttl: this.ttl.diskutil
    });
  }

  /**
   * 检查缓存条目是否有效
   */
  private isValid<T>(entry: CacheEntry<T>): boolean {
    const age = Date.now() - entry.timestamp;
    return age < entry.ttl;
  }

  /**
   * 使设备列表缓存失效
   */
  invalidateDeviceList(): void {
    this.deviceListCache = null;
  }

  /**
   * 使挂载信息缓存失效
   */
  invalidateMountInfo(): void {
    this.mountInfoCache = null;
  }

  /**
   * 使特定设备的diskutil缓存失效
   */
  invalidateDiskutilInfo(devicePath: string): void {
    this.diskutilCache.delete(devicePath);
  }

  /**
   * 获取缓存的 diskutil list 信息
   */
  getDiskutilList(): string | null {
    if (this.diskutilListCache && this.isValid(this.diskutilListCache)) {
      return this.diskutilListCache.data;
    }
    return null;
  }

  /**
   * 设置 diskutil list 信息缓存
   */
  setDiskutilList(info: string): void {
    this.diskutilListCache = {
      data: info,
      timestamp: Date.now(),
      ttl: this.ttl.diskutil
    };
  }

  /**
   * 使所有缓存失效（设备插拔时调用）
   */
  invalidateAll(): void {
    this.deviceListCache = null;
    this.mountInfoCache = null;
    this.diskutilListCache = null;
    this.diskutilCache.clear();
  }

  /**
   * 清理过期缓存
   */
  cleanup(): void {
    // 清理过期的diskutil缓存
    const now = Date.now();
    for (const [key, entry] of this.diskutilCache.entries()) {
      if (!this.isValid(entry)) {
        this.diskutilCache.delete(key);
      }
    }

    // 清理过期的设备列表缓存
    if (this.deviceListCache && !this.isValid(this.deviceListCache)) {
      this.deviceListCache = null;
    }

    // 清理过期的挂载信息缓存
    if (this.mountInfoCache && !this.isValid(this.mountInfoCache)) {
      this.mountInfoCache = null;
    }
  }

  /**
   * 获取缓存统计信息（用于调试）
   */
  getStats(): {
    deviceListCached: boolean;
    mountInfoCached: boolean;
    diskutilCacheSize: number;
  } {
    return {
      deviceListCached: this.deviceListCache !== null && this.isValid(this.deviceListCache),
      mountInfoCached: this.mountInfoCache !== null && this.isValid(this.mountInfoCache),
      diskutilCacheSize: this.diskutilCache.size
    };
  }
}
