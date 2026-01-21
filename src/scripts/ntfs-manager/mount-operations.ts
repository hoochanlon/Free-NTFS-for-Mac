// 挂载操作模块
import * as fs from 'fs/promises';
import type { NTFSDevice } from '../../types/electron';
import { fileExists, execAsync } from './utils';
import { PasswordManager } from './password-manager';
import { SudoExecutor } from './sudo-executor';

export class MountOperations {
  private mountedDevices: Set<string>;
  private unmountedDevices: Map<string, NTFSDevice>;
  private passwordManager: PasswordManager;
  private sudoExecutor: SudoExecutor;
  private getNTFS3GPath: () => Promise<string | null>;

  constructor(
    mountedDevices: Set<string>,
    unmountedDevices: Map<string, NTFSDevice>,
    passwordManager: PasswordManager,
    sudoExecutor: SudoExecutor,
    getNTFS3GPath: () => Promise<string | null>
  ) {
    this.mountedDevices = mountedDevices;
    this.unmountedDevices = unmountedDevices;
    this.passwordManager = passwordManager;
    this.sudoExecutor = sudoExecutor;
    this.getNTFS3GPath = getNTFS3GPath;
  }

  // 卸载设备
  async unmountDevice(device: NTFSDevice): Promise<string> {
    try {
      const password = await this.passwordManager.getPassword('messages.passwordDialog.unmountDevice', { name: device.volumeName });
      await this.sudoExecutor.executeSudoWithPassword(['umount', '-f', device.devicePath], password);
      this.mountedDevices.delete(device.disk);
      fs.unlink(`/tmp/ntfs_mounted_${device.disk}`).catch(() => {});

      // 保存已卸载的设备信息，以便后续重新挂载
      this.unmountedDevices.set(device.disk, {
        ...device,
        isUnmounted: true
      });

      return `设备 ${device.volumeName} 已卸载`;
    } catch (error: any) {
      // 如果密码错误，重新获取密码并重试
      if (error.message?.includes('密码错误') || error.message?.includes('password is incorrect') || error.message?.includes('Sorry, try again')) {
        try {
          // 删除保存的密码后，重新获取
          const password = await this.passwordManager.getPassword('messages.passwordDialog.unmountDevice', { name: device.volumeName });
          await this.sudoExecutor.executeSudoWithPassword(['umount', '-f', device.devicePath], password);
          this.mountedDevices.delete(device.disk);
          fs.unlink(`/tmp/ntfs_mounted_${device.disk}`).catch(() => {});

          // 保存已卸载的设备信息
          this.unmountedDevices.set(device.disk, {
            ...device,
            isUnmounted: true
          });

          return `设备 ${device.volumeName} 已卸载`;
        } catch (retryError) {
          throw retryError;
        }
      }
      if (error.message?.includes('密码') || error.message?.includes('password')) {
        throw error;
      }
      try {
        const result = await this.unmountWithDiskutil(device);
        // 保存已卸载的设备信息
        this.unmountedDevices.set(device.disk, {
          ...device,
          isUnmounted: true
        });
        return result;
      } catch (diskutilError) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        throw new Error(`卸载失败: ${errorMessage}`);
      }
    }
  }

  // 使用 diskutil 卸载（备用方法）
  async unmountWithDiskutil(device: NTFSDevice): Promise<string> {
    try {
      await execAsync(`diskutil unmount force ${device.devicePath}`);
      this.mountedDevices.delete(device.disk);
      fs.unlink(`/tmp/ntfs_mounted_${device.disk}`).catch(() => {});
      return `设备 ${device.volumeName} 已卸载`;
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      throw new Error(`使用 diskutil 卸载失败: ${errorMessage}`);
    }
  }

  // 推出设备（完全断开）
  async ejectDevice(device: NTFSDevice): Promise<string> {
    try {
      // 先清理标记文件
      this.mountedDevices.delete(device.disk);
      fs.unlink(`/tmp/ntfs_mounted_${device.disk}`).catch(() => {});
      this.unmountedDevices.delete(device.disk);

      // 使用 diskutil eject 推出设备
      // 这会卸载所有卷并完全断开设备
      await execAsync(`diskutil eject ${device.devicePath}`);
      return `设备 ${device.volumeName} 已推出，可以安全拔出`;
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      throw new Error(`推出设备失败: ${errorMessage}`);
    }
  }

  // 还原设备为只读模式
  async restoreToReadOnly(device: NTFSDevice): Promise<string> {
    try {
      const password = await this.passwordManager.getPassword('messages.passwordDialog.restoreToReadOnly', { name: device.volumeName });

      // 先卸载当前挂载
      try {
        await this.sudoExecutor.executeSudoWithPassword(['umount', '-f', device.devicePath], password);
      } catch (error: any) {
        // 如果密码错误，重新获取密码
        if (error.message?.includes('密码错误') || error.message?.includes('password is incorrect') || error.message?.includes('Sorry, try again')) {
          const retryPassword = await this.passwordManager.getPassword('messages.passwordDialog.restoreToReadOnly', { name: device.volumeName });
          try {
            await this.sudoExecutor.executeSudoWithPassword(['umount', '-f', device.devicePath], retryPassword);
          } catch {
            // 卸载失败可能因为已经卸载，继续
          }
        } else {
          // 卸载失败可能因为已经卸载，继续
        }
      }

      // 从已挂载设备列表中移除
      this.mountedDevices.delete(device.disk);
      fs.unlink(`/tmp/ntfs_mounted_${device.disk}`).catch(() => {});

      // 等待一小段时间，让系统自动以只读模式重新挂载
      await new Promise(resolve => setTimeout(resolve, 1000));

      // 使用 diskutil mount 让系统以只读模式挂载
      try {
        await execAsync(`diskutil mount ${device.devicePath}`);
      } catch {
        // 如果 diskutil mount 失败，系统可能会自动挂载，继续
      }

      return `设备 ${device.volumeName} 已还原为只读模式`;
    } catch (error: any) {
      if (error.message?.includes('密码') || error.message?.includes('password')) {
        throw error;
      }
      const errorMessage = error instanceof Error ? error.message : String(error);
      throw new Error(`还原为只读模式失败: ${errorMessage}`);
    }
  }

  // 挂载设备
  async mountDevice(device: NTFSDevice): Promise<string> {
    const ntfs3gPath = await this.getNTFS3GPath();
    if (!ntfs3gPath) {
      throw new Error('未找到 ntfs-3g，请先安装依赖');
    }

    let fullPath = ntfs3gPath;
    if (!(await fileExists(fullPath))) {
      fullPath = `/System/Volumes/Data${ntfs3gPath}`;
      if (!(await fileExists(fullPath))) {
        throw new Error(`ntfs-3g 路径不存在: ${ntfs3gPath}`);
      }
    }

    if (this.mountedDevices.has(device.disk)) {
      try {
        const result = await execAsync(`mount | grep "${device.devicePath}"`) as { stdout: string };
        if (!result.stdout.includes('read-only')) {
          return `设备 ${device.volumeName} 已经是读写模式`;
        }
      } catch {
        // 继续挂载
      }
    }

    try {
      let password = await this.passwordManager.getPassword('messages.passwordDialog.mountDevice', { name: device.volumeName });

      try {
        await this.sudoExecutor.executeSudoWithPassword(['umount', '-f', device.devicePath], password);
      } catch (error: any) {
        // 如果密码错误，重新获取密码
        if (error.message?.includes('密码错误') || error.message?.includes('password is incorrect') || error.message?.includes('Sorry, try again')) {
          password = await this.passwordManager.getPassword('messages.passwordDialog.mountDevice', { name: device.volumeName });
          try {
            await this.sudoExecutor.executeSudoWithPassword(['umount', '-f', device.devicePath], password);
          } catch {
            // 卸载失败可能因为已经卸载，继续
          }
        } else {
          // 卸载失败可能因为已经卸载，继续
        }
      }

      const mountArgs = [
        fullPath,
        '-olocal',
        '-oallow_other',
        '-oauto_xattr',
        `-ovolname=${device.volumeName}`,
        '-oremove_hiberfile',
        '-onoatime',
        device.devicePath,
        device.volume
      ];

      let retryCount = 0;
      const maxRetries = 1; // 最多重试1次

      while (retryCount <= maxRetries) {
        try {
          console.log(`[MountOperations] 尝试挂载设备 ${device.volumeName} (尝试 ${retryCount + 1}/${maxRetries + 1})`);
          const mountPromise = this.sudoExecutor.executeSudoWithPassword(mountArgs, password);
          const timeoutPromise = new Promise<never>((_, reject) => {
            setTimeout(() => reject(new Error('挂载操作超时（10秒），操作已取消以防止卡死。可能的原因：1) 文件系统处于脏状态（如果该 NTFS 设备之前在 Windows 电脑上使用过，且 Windows 启用了快速启动功能，请将设备插回 Windows 电脑并完全关闭后再试）；2) 设备被其他程序占用；3) 系统权限问题。')), 10000);
          });

          await Promise.race([mountPromise, timeoutPromise]);
          // 如果成功，跳出循环
          break;
        } catch (error: any) {
          const errorMessage = error.message || String(error);
          console.error(`[MountOperations] 挂载失败 (尝试 ${retryCount + 1}):`, errorMessage);

          // 检查是否是密码错误
          const isPasswordError = errorMessage.includes('密码错误') ||
                                  errorMessage.includes('password is incorrect') ||
                                  errorMessage.includes('Sorry, try again') ||
                                  errorMessage.includes('密码不能为空');

          if (isPasswordError && retryCount < maxRetries) {
            // 如果是密码错误且还有重试次数，重新获取密码
            console.log('[MountOperations] 密码错误，重新获取密码...');
            password = await this.passwordManager.getPassword('messages.passwordDialog.mountDeviceRetry', { name: device.volumeName });
            retryCount++;
          } else {
            // 如果不是密码错误，或者已经达到最大重试次数，抛出错误
            throw error;
          }
        }
      }

      this.mountedDevices.add(device.disk);
      this.unmountedDevices.delete(device.disk); // 从已卸载列表中移除
      fs.writeFile(`/tmp/ntfs_mounted_${device.disk}`, '').catch(() => {});
      return `设备 ${device.volumeName} 已成功挂载为读写模式`;
    } catch (error: any) {
      if (error.message?.includes('超时')) {
        throw error;
      } else if (error.message?.includes('密码')) {
        throw error;
      } else {
        const errorMessage = error instanceof Error ? error.message : String(error);
        throw new Error(`挂载失败: ${errorMessage}`);
      }
    }
  }

  // 清理旧的挂载标记
  async cleanupOldMounts(): Promise<void> {
    try {
      const files = await fs.readdir('/tmp');
      const markers = files.filter(f => f.startsWith('ntfs_mounted_'));

      for (const marker of markers) {
        const disk = marker.replace('ntfs_mounted_', '');
        try {
          const result = await execAsync(`mount | grep "/dev/${disk}"`) as { stdout: string };
          if (!result.stdout.trim()) {
            await fs.unlink(`/tmp/${marker}`);
            this.mountedDevices.delete(disk);
          }
        } catch {
          await fs.unlink(`/tmp/${marker}`).catch(() => {});
          this.mountedDevices.delete(disk);
        }
      }
    } catch (error) {
      // 忽略错误
    }
  }
}
