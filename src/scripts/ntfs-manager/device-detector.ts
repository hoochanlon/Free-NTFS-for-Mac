// 设备检测模块（性能优化版）
import { execAsync, fileExists } from './utils';
import type { NTFSDevice } from '../../types/electron';
import { DeviceCacheManager } from './device-cache';
import { BatchExecutor } from './batch-executor';

export class DeviceDetector {
  private mountedDevices: Set<string>;
  private unmountedDevices: Map<string, NTFSDevice>;
  private cache: DeviceCacheManager;
  private batchExecutor: BatchExecutor;
  private lastDeviceList: NTFSDevice[] = [];
  private lastDeviceHash: string = '';

  constructor(
    mountedDevices: Set<string>,
    unmountedDevices: Map<string, NTFSDevice>,
    cache?: DeviceCacheManager,
    batchExecutor?: BatchExecutor
  ) {
    this.mountedDevices = mountedDevices;
    this.unmountedDevices = unmountedDevices;
    this.cache = cache || new DeviceCacheManager();
    this.batchExecutor = batchExecutor || new BatchExecutor();
  }

  // 获取磁盘容量信息
  // 优先从挂载点获取（如果已挂载），否则从设备本身获取（即使未挂载）
  private async getDiskCapacity(volume: string, devicePath: string): Promise<{ total: number; used: number; available: number } | undefined> {
    try {
      // 方法1：尝试从挂载点获取（如果设备已挂载）
      try {
        const dfResult = await execAsync(`df -k "${volume}" 2>/dev/null`) as { stdout: string };
        const dfLines = dfResult.stdout.trim().split('\n').filter(line => line.length > 0);

        if (dfLines.length >= 2) {
          // 跳过标题行（第一行），取数据行
          // 通常最后一行是实际数据，但也要检查是否包含设备路径
          let dataLine = '';
          for (let i = dfLines.length - 1; i >= 1; i--) {
            const line = dfLines[i].trim();
            // 查找包含设备路径或挂载点的行
            if (line.includes('/dev/') || line.includes(volume)) {
              dataLine = line;
              break;
            }
          }
          // 如果没找到，使用最后一行
          if (!dataLine && dfLines.length > 1) {
            dataLine = dfLines[dfLines.length - 1].trim();
          }

          if (dataLine) {
            const parts = dataLine.split(/\s+/);

            // df -k 输出格式：Filesystem 1024-blocks Used Available Capacity Mounted on
            // 或者：/dev/disk5s1    30236732 67904  30168828     1%   /Volumes/TOSHIBA
            // parts[0] = Filesystem/设备路径
            // parts[1] = 1024-blocks (总容量，KB)
            // parts[2] = Used (已使用，KB)
            // parts[3] = Available (可用，KB)
            if (parts.length >= 4) {
              const totalKB = parseInt(parts[1], 10);
              const usedKB = parseInt(parts[2], 10);
              const availableKB = parseInt(parts[3], 10);

              if (!isNaN(totalKB) && !isNaN(usedKB) && !isNaN(availableKB) && totalKB > 0) {
                // 转换为字节
                const result = {
                  total: totalKB * 1024,
                  used: usedKB * 1024,
                  available: availableKB * 1024
                };
                // 验证数据合理性：used + available 应该约等于 total（允许一些误差）
                const sum = result.used + result.available;
                const diff = Math.abs(sum - result.total);
                // 如果差异小于 1%，认为数据有效
                if (diff < result.total * 0.01 || result.used > 0) {
                  return result;
                }
              }
            }
          }
        }
      } catch (error) {
        // df 命令失败是正常情况（设备可能未挂载或只读挂载），静默处理，继续尝试 diskutil
        // 不输出错误信息，避免控制台噪音
      }

      // 方法2：从设备本身获取容量（即使未挂载也可以）
      try {
        const diskutilResult = await execAsync(`diskutil info "${devicePath}" 2>/dev/null`) as { stdout: string };
        const info = diskutilResult.stdout;

        // 解析 diskutil 输出
        // Total Size: 500.1 GB (500107862016 Bytes) (exactly 976773168 512-Byte-Units)
        // Volume Free Space: 400.0 GB (400000000000 Bytes) (exactly 781250000 512-Byte-Units)
        // Volume Used Space: 100.1 GB (100107862016 Bytes) (exactly 195523168 512-Byte-Units)

        // 或者使用 Disk Size（如果 Volume 信息不可用）
        const totalSizeMatch = info.match(/Total Size:\s*[\d.]+ [KMGT]?B\s*\((\d+)\s+Bytes\)/i) ||
                                 info.match(/Disk Size:\s*[\d.]+ [KMGT]?B\s*\((\d+)\s+Bytes\)/i);
        const freeSpaceMatch = info.match(/Volume Free Space:\s*[\d.]+ [KMGT]?B\s*\((\d+)\s+Bytes\)/i);
        const usedSpaceMatch = info.match(/Volume Used Space:\s*[\d.]+ [KMGT]?B\s*\((\d+)\s+Bytes\)/i);

        if (totalSizeMatch) {
          const total = parseInt(totalSizeMatch[1], 10);

          if (!isNaN(total) && total > 0) {
            let used = 0;
            let available = 0;

            if (usedSpaceMatch && usedSpaceMatch[1]) {
              used = parseInt(usedSpaceMatch[1], 10);
            }
            if (freeSpaceMatch && freeSpaceMatch[1]) {
              available = parseInt(freeSpaceMatch[1], 10);
            }

            // 如果无法获取已使用和可用空间，但能获取总容量，至少显示总容量
            // 已使用 = 总容量 - 可用空间
            if (available > 0 && used === 0) {
              // 如果有可用空间但没有已使用空间，计算：已使用 = 总容量 - 可用空间
              used = total - available;
            } else if (used > 0 && available === 0) {
              // 如果有已使用空间但没有可用空间，计算：可用空间 = 总容量 - 已使用
              available = total - used;
            } else if (used === 0 && available === 0) {
              // 如果都无法获取，至少显示总容量，已使用设为 0
              used = 0;
              available = total;
            }

            // 确保数据合理性：used + available 应该约等于 total
            const sum = used + available;
            const diff = Math.abs(sum - total);
            // 如果差异超过 5%，可能需要调整
            if (diff > total * 0.05) {
              // 如果差异太大，优先使用 available 来计算 used
              if (available > 0) {
                used = total - available;
              } else if (used > 0) {
                available = total - used;
              }
            }

            return {
              total,
              used: Math.max(0, used), // 确保不为负数
              available: Math.max(0, available) // 确保不为负数
            };
          }
        }
      } catch {
        // diskutil 命令失败，返回 undefined
      }

      return undefined;
    } catch (error) {
      // 获取容量失败时返回 undefined，不影响设备列表的显示
      return undefined;
    }
  }

  // 获取 NTFS 设备列表（优化版：使用缓存和批量执行）
  async getNTFSDevices(forceRefresh: boolean = false): Promise<NTFSDevice[]> {
    try {
      // 如果强制刷新，先失效缓存
      if (forceRefresh) {
        this.cache.invalidateAll();
      }

      // 检查缓存（仅在非强制刷新时使用）
      if (!forceRefresh) {
        const cached = this.cache.getDeviceList();
        if (cached) {
          return cached;
        }
      }

      // 检查挂载信息缓存（仅在非强制刷新时使用）
      let stdout = forceRefresh ? '' : (this.cache.getMountInfo() || '');

      if (!stdout) {
        try {
          // 使用批量执行器（带缓存，但强制刷新时使用更短的TTL）
          const result = await this.batchExecutor.execute(
            'mount | grep -iE "(ntfs|fuse)"',
            'mount_ntfs_fuse',
            forceRefresh ? 300 : 1000 // 强制刷新时缓存0.3秒，否则1秒
          );
          stdout = result.stdout || '';

          // 更新缓存
          if (stdout) {
            this.cache.setMountInfo(stdout);
          }
        } catch (error: any) {
          if (error.code === 1) {
            stdout = error.stdout || '';
            if (!stdout) {
              // 缓存空结果，避免频繁查询
              this.cache.setDeviceList([]);
              return [];
            }
          } else {
            return [];
          }
        }
      }

      const lines = stdout.trim().split('\n').filter(line => line.length > 0 && (line.toLowerCase().includes('ntfs') || line.toLowerCase().includes('fuse')));

      const devices: NTFSDevice[] = [];
      for (const line of lines) {
        const parts = line.split(' on ');
        if (parts.length !== 2) continue;

        const devicePath = parts[0].trim();
        const rest = parts[1].trim();

        const volumeMatch = rest.match(/^(\/Volumes\/[^\s(]+)/);
        const optionsMatch = rest.match(/\(([^)]+)\)/);

        if (!volumeMatch) continue;

        const volume = volumeMatch[1].trim();
        const volumeName = volume.replace('/Volumes/', '');
        const disk = devicePath.replace('/dev/', '');
        const options = optionsMatch ? optionsMatch[1] : '';
        const isReadOnly = options.includes('read-only');

        // 检查是否通过 ntfs-3g (FUSE) 挂载
        // ntfs-3g 挂载的设备会在 mount 输出中包含 fuse 或特定的挂载选项
        // 系统默认的 ntfs 挂载会包含 fskit，不是 FUSE
        const isFuseMounted = line.toLowerCase().includes('fuse') ||
                              line.toLowerCase().includes('ntfs-3g') ||
                              (options.includes('local') && options.includes('allow_other'));

        const markerFile = `/tmp/ntfs_mounted_${disk}`;
        let markerExists = false;
        try {
          markerExists = await fileExists(markerFile);
        } catch {
          markerExists = false;
        }

        // 如果标记文件存在但设备不是通过 FUSE 挂载，说明设备被系统重新挂载为只读模式
        // 需要清理标记文件，避免误判
        if (markerExists && !isFuseMounted) {
          try {
            const fs = await import('fs/promises');
            await fs.unlink(markerFile);
            this.mountedDevices.delete(disk);
            markerExists = false;
          } catch {
            // 忽略清理失败
          }
        }

        // 如果标记文件存在且设备通过 FUSE 挂载，将设备添加到 mountedDevices Set 中
        if (markerExists && isFuseMounted) {
          this.mountedDevices.add(disk);
        }

        // 判断设备是否已通过 ntfs-3g 挂载为读写模式
        // 必须同时满足：
        // 1. 标记文件存在（说明之前通过本应用挂载过）
        // 2. 当前通过 FUSE 挂载（说明确实是 ntfs-3g 挂载）
        const isInMountedSet = this.mountedDevices.has(disk);
        const deviceIsMounted = (isInMountedSet || markerExists) && isFuseMounted;

        // 如果设备已通过 ntfs-3g 挂载为读写模式，强制设置 isReadOnly 为 false
        // 否则，使用 mount 命令检测到的实际状态
        const finalIsReadOnly = deviceIsMounted ? false : isReadOnly;

        // 获取磁盘容量信息（无论是否挂载都尝试获取）
        // 优先从挂载点获取，如果失败则从设备本身获取
        let capacity: { total: number; used: number; available: number } | undefined;
        try {
          capacity = await this.getDiskCapacity(volume, devicePath);
        } catch (error) {
          // 获取容量失败时静默处理，不影响设备列表显示
          capacity = undefined;
        }

        devices.push({
          disk,
          devicePath,
          volume,
          volumeName,
          isReadOnly: finalIsReadOnly,
          options,
          isMounted: deviceIsMounted,
          capacity
        });

        // 如果设备已挂载，从已卸载设备列表中移除
        this.unmountedDevices.delete(disk);
      }

      // 检查已卸载的设备是否仍然存在
      for (const [disk, unmountedDevice] of this.unmountedDevices.entries()) {
        // 检查设备是否已经在当前列表中（可能已经重新挂载）
        const alreadyInList = devices.some(d => d.disk === disk);
        if (alreadyInList) {
          // 设备已重新挂载，从已卸载列表中移除
          this.unmountedDevices.delete(disk);
          continue;
        }

        try {
          // 检查diskutil缓存
          let diskutilOutput = this.cache.getDiskutilInfo(unmountedDevice.devicePath);

          if (!diskutilOutput) {
            // 使用批量执行器（带缓存）
            const result = await this.batchExecutor.execute(
              `diskutil info ${unmountedDevice.devicePath} 2>/dev/null`,
              `diskutil_${unmountedDevice.devicePath}`,
              5000 // 缓存5秒
            );
            diskutilOutput = result.stdout || '';

            if (diskutilOutput) {
              this.cache.setDiskutilInfo(unmountedDevice.devicePath, diskutilOutput);
            }
          }

          if (diskutilOutput && diskutilOutput.includes('File System Personality:')) {
            // 尝试从 diskutil 输出中获取卷名
            const volumeNameMatch = diskutilOutput.match(/Volume Name:\s*(.+)/i);
            const volumeName = volumeNameMatch ? volumeNameMatch[1].trim() : unmountedDevice.volumeName;

            // 尝试获取容量信息（即使设备未挂载）
            let capacity: { total: number; used: number; available: number } | undefined;
            try {
              capacity = await this.getDiskCapacity('', unmountedDevice.devicePath);
            } catch {
              capacity = undefined;
            }

            // 设备仍然存在，添加到列表中，标记为已卸载
            devices.push({
              ...unmountedDevice,
              volumeName,
              isUnmounted: true,
              isReadOnly: true, // 已卸载的设备默认显示为只读
              isMounted: false,
              capacity
            });
          } else {
            // 设备不存在，从已卸载列表中移除
            this.unmountedDevices.delete(disk);
          }
        } catch {
          // 设备不存在或无法访问，从已卸载列表中移除
          this.unmountedDevices.delete(disk);
        }
      }

      // 计算设备列表哈希，用于检测变化
      const deviceHash = this.calculateDeviceHash(devices);
      const hasChanged = deviceHash !== this.lastDeviceHash;

      // 更新缓存
      this.cache.setDeviceList(devices);
      this.lastDeviceList = devices;
      this.lastDeviceHash = deviceHash;

      // 如果设备列表变化，清理相关缓存
      if (hasChanged) {
        this.cache.invalidateMountInfo();
      }

      return devices;
    } catch (error) {
      console.error('获取 NTFS 设备列表失败:', error);
      return [];
    }
  }

  /**
   * 计算设备列表哈希（用于快速比较变化）
   */
  private calculateDeviceHash(devices: NTFSDevice[]): string {
    // 使用设备路径和挂载状态的组合作为哈希
    return devices
      .map(d => `${d.disk}:${d.isMounted ? '1' : '0'}:${d.isReadOnly ? '1' : '0'}`)
      .sort()
      .join('|');
  }

  /**
   * 检查设备列表是否有变化
   */
  hasDeviceListChanged(newDevices: NTFSDevice[]): boolean {
    const newHash = this.calculateDeviceHash(newDevices);
    return newHash !== this.lastDeviceHash;
  }

  /**
   * 使缓存失效（设备插拔时调用）
   */
  invalidateCache(): void {
    this.cache.invalidateAll();
    this.lastDeviceHash = '';
  }
}
