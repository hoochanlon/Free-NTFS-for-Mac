// 挂载操作模块
import * as fs from 'fs/promises';
import * as path from 'path';
import type { NTFSDevice } from '../../types/electron';
import { fileExists, execAsync, execFileAsync, findExecutablePath } from './utils';
import { PasswordManager } from './password-manager';
import { SudoExecutor } from './sudo-executor';
import {
  getParentDiskId,
  getParentDiskPath as parentDiskOf,
  isExternalFormattableFromInfo,
  isValidPartitionPath,
  isValidWholeDiskPath,
  parseDiskutilField,
  sanitizeNtfsVolumeName
} from './disk-safety';

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

  private async getNTFSFixPath(): Promise<string> {
    const pathFromEnvironment = await findExecutablePath('ntfsfix');
    if (pathFromEnvironment) {
      return pathFromEnvironment;
    }

    const ntfs3gPath = await this.getNTFS3GPath();
    if (ntfs3gPath) {
      const siblingPath = await findExecutablePath(path.join(path.dirname(ntfs3gPath), 'ntfsfix'));
      if (siblingPath) {
        return siblingPath;
      }
    }

    throw new Error('ntfsfix not found. Install ntfs-3g-mac before repairing an NTFS volume.');
  }

  private async getNTFSLabelPath(): Promise<string> {
    const pathFromEnvironment = await findExecutablePath('ntfslabel');
    if (pathFromEnvironment) {
      return pathFromEnvironment;
    }

    const ntfs3gPath = await this.getNTFS3GPath();
    if (ntfs3gPath) {
      const siblingPath = await findExecutablePath(path.join(path.dirname(ntfs3gPath), 'ntfslabel'));
      if (siblingPath) {
        return siblingPath;
      }
    }

    throw new Error('RENAME_TOOL_MISSING');
  }

  private async getMkntfsPath(): Promise<string> {
    const pathFromEnvironment = await findExecutablePath('mkntfs');
    if (pathFromEnvironment) {
      return pathFromEnvironment;
    }

    const ntfs3gPath = await this.getNTFS3GPath();
    if (ntfs3gPath) {
      const siblingPath = await findExecutablePath(path.join(path.dirname(ntfs3gPath), 'mkntfs'));
      if (siblingPath) {
        return siblingPath;
      }
    }

    throw new Error('FORMAT_TOOL_MISSING');
  }

  private isValidDevicePath(devicePath: string): boolean {
    return isValidPartitionPath(devicePath);
  }

  private getParentDiskPath(devicePath: string): string {
    return parentDiskOf(devicePath);
  }

  private getPartitionIndex(disk: string): string | null {
    const match = disk.match(/s(\d+)$/);
    return match ? match[1] : null;
  }

  // diskutil list 在 GPT 盘上读的是分区名，不是 NTFS 卷标。
  // 整盘卸载后再写 GPT 名，DiskArbitration 才会丢掉旧名，不必真的推出重插。
  private async tryRefreshDiskName(
    execute: (args: string[]) => Promise<unknown>,
    devicePath: string,
    disk: string,
    newName: string
  ): Promise<void> {
    const parentDiskPath = this.getParentDiskPath(devicePath);
    if (parentDiskPath === devicePath) {
      return;
    }

    try {
      await execute(['diskutil', 'unmountDisk', parentDiskPath]);
    } catch {
      // 其他卷仍被占用时，跳过 GPT 名刷新，避免中断它们的读写。
      return;
    }

    const partitionIndex = this.getPartitionIndex(disk);
    if (!partitionIndex) {
      return;
    }

    const rawParentDiskPath = parentDiskPath.replace('/dev/disk', '/dev/rdisk');
    try {
      await execute(['gpt', 'label', '-f', '-i', partitionIndex, '-l', newName, rawParentDiskPath]);
    } catch (error) {
      console.warn('[MountOperations] 更新 GPT 分区名失败（可忽略）:', error);
    }
  }

  private async removeStaleMountPoint(
    execute: (args: string[]) => Promise<unknown>,
    mountPoint: string | undefined,
    nextMountPoint: string
  ): Promise<void> {
    if (!mountPoint || mountPoint === nextMountPoint || !mountPoint.startsWith('/Volumes/')) {
      return;
    }

    try {
      await execute(['rmdir', mountPoint]);
    } catch {
      // 目录非空或不存在时忽略，避免误删用户数据
    }
  }

  // 卸载设备
  async unmountDevice(device: NTFSDevice): Promise<string> {
    try {
      const password = await this.passwordManager.getPassword('messages.passwordDialog.unmountDevice', { name: device.volumeName });
      await this.sudoExecutor.executeSudoWithPassword(['diskutil', 'unmount', device.devicePath], password);
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
          await this.sudoExecutor.executeSudoWithPassword(['diskutil', 'unmount', device.devicePath], password);
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
      await execFileAsync('diskutil', ['unmount', device.devicePath]);
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
      // 推出成功后再清理状态；设备忙时应保留原挂载状态。
      await execFileAsync('diskutil', ['eject', device.devicePath]);
      this.mountedDevices.delete(device.disk);
      fs.unlink(`/tmp/ntfs_mounted_${device.disk}`).catch(() => {});
      this.unmountedDevices.delete(device.disk);

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
        await this.sudoExecutor.executeSudoWithPassword(['diskutil', 'unmount', device.devicePath], password);
      } catch (error: any) {
        // 如果密码错误，重新获取密码
        if (error.message?.includes('密码错误') || error.message?.includes('password is incorrect') || error.message?.includes('Sorry, try again')) {
          const retryPassword = await this.passwordManager.getPassword('messages.passwordDialog.restoreToReadOnly', { name: device.volumeName });
          await this.sudoExecutor.executeSudoWithPassword(['diskutil', 'unmount', device.devicePath], retryPassword);
        } else {
          throw error;
        }
      }

      // 从已挂载设备列表中移除
      this.mountedDevices.delete(device.disk);
      fs.unlink(`/tmp/ntfs_mounted_${device.disk}`).catch(() => {});

      // 等待一小段时间，让系统自动以只读模式重新挂载
      await new Promise(resolve => setTimeout(resolve, 1000));

      // 使用 diskutil mount 让系统以只读模式挂载
      try {
        await execFileAsync('diskutil', ['mount', device.devicePath]);
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
  async mountDevice(device: NTFSDevice, passwordOverride?: string): Promise<string> {
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
        const result = await execFileAsync('mount', []);
        const mountLine = result.stdout.split('\n').find(line => line.startsWith(`${device.devicePath} on `));
        if (mountLine && !/\([^()]*\bread-only\b[^()]*\)\s*$/.test(mountLine)) {
          return `设备 ${device.volumeName} 已经是读写模式`;
        }
      } catch {
        // 继续挂载
      }
    }

    try {
      let password = passwordOverride || await this.passwordManager.getPassword('messages.passwordDialog.mountDevice', { name: device.volumeName });

      try {
        await this.sudoExecutor.executeSudoWithPassword(['diskutil', 'unmount', device.devicePath], password);
      } catch (error: any) {
        // 如果密码错误，重新获取密码
        if (error.message?.includes('密码错误') || error.message?.includes('password is incorrect') || error.message?.includes('Sorry, try again')) {
          password = await this.passwordManager.getPassword('messages.passwordDialog.mountDevice', { name: device.volumeName });
          await this.sudoExecutor.executeSudoWithPassword(['diskutil', 'unmount', device.devicePath], password);
        } else {
          throw error;
        }
      }

      // 安全卸载成功后，旧的读写标记已经失效。
      this.mountedDevices.delete(device.disk);
      await fs.unlink(`/tmp/ntfs_mounted_${device.disk}`).catch(() => {});

      const mountUid = process.getuid?.();
      const mountGid = process.getgid?.();
      if (mountUid === undefined || mountGid === undefined) {
        throw new Error('无法读取当前用户 UID/GID，已取消挂载');
      }

      try {
        await this.sudoExecutor.executeSudoWithPassword(['mkdir', '-p', device.volume], password);
      } catch {
        // ntfs-3g 仍可能自行创建挂载点
      }

      const mountArgs = [
        fullPath,
        '-olocal',
        '-oallow_other',
        '-ostreams_interface=openxattr',
        `-ouid=${mountUid}`,
        `-ogid=${mountGid}`,
        `-ovolname=${device.volumeName}`,
        '-onoatime',
        device.devicePath,
        device.volume
      ];

      let retryCount = 0;
      const maxRetries = 1; // 最多重试1次

      while (retryCount <= maxRetries) {
        try {
          console.log(`[MountOperations] 尝试挂载设备 ${device.volumeName} (尝试 ${retryCount + 1}/${maxRetries + 1})`);
          // 等待执行器完成或返回其真实超时，避免提示取消后仍在挂载。
          await this.sudoExecutor.executeSudoWithPassword(mountArgs, password);
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

      // ntfs-3g 对休眠卷可能成功退回只读挂载，不能据退出码报告读写成功。
      const mountResult = await execFileAsync('mount', []);
      const mountLine = mountResult.stdout.split('\n').find(line => line.startsWith(`${device.devicePath} on `));
      if (!mountLine) {
        throw new Error('未检测到挂载结果，请刷新设备状态后再试');
      }
      if (/\([^()]*\bread-only\b[^()]*\)\s*$/.test(mountLine)) {
        throw new Error('设备已挂载为只读。若 Windows 处于休眠或快速启动状态，请回到 Windows 完全关机后再试');
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

  // 重置设备（卸载+修复）- 用于解决 Resource busy 错误
  async resetDevice(device: NTFSDevice): Promise<string> {
    try {
      const ntfsfixPath = await this.getNTFSFixPath();
      let password = await this.passwordManager.getPassword('messages.passwordDialog.resetDevice', { name: device.volumeName });

      // 步骤1：卸载设备
      try {
        await this.sudoExecutor.executeSudoWithPassword(['diskutil', 'unmount', device.devicePath], password);
      } catch (error: any) {
        // 如果密码错误，重新获取密码
        if (error.message?.includes('密码错误') || error.message?.includes('password is incorrect') || error.message?.includes('Sorry, try again')) {
          password = await this.passwordManager.getPassword('messages.passwordDialog.resetDevice', { name: device.volumeName });
          await this.sudoExecutor.executeSudoWithPassword(['diskutil', 'unmount', device.devicePath], password);
        } else {
          throw error;
        }
      }

      // 从已挂载设备列表中移除
      this.mountedDevices.delete(device.disk);
      fs.unlink(`/tmp/ntfs_mounted_${device.disk}`).catch(() => {});

      // 等待一小段时间，确保设备完全卸载
      await new Promise(resolve => setTimeout(resolve, 500));

      // 步骤2：修复文件系统
      try {
        await this.sudoExecutor.executeSudoWithPassword([ntfsfixPath, device.devicePath], password);
      } catch (error: any) {
        // 如果密码错误，重新获取密码
        if (error.message?.includes('密码错误') || error.message?.includes('password is incorrect') || error.message?.includes('Sorry, try again')) {
          password = await this.passwordManager.getPassword('messages.passwordDialog.resetDevice', { name: device.volumeName });
          await this.sudoExecutor.executeSudoWithPassword([ntfsfixPath, device.devicePath], password);
        } else {
          const errorMessage = error instanceof Error ? error.message : String(error);
          throw new Error(`修复文件系统失败: ${errorMessage}`);
        }
      }

      // 等待一小段时间，确保修复完成
      await new Promise(resolve => setTimeout(resolve, 500));

      // 步骤3：重新挂载设备为只读模式（使用系统默认的只读挂载）
      try {
        // 使用 diskutil mount 挂载为只读模式（macOS 默认行为）
        try {
          await execAsync(`diskutil mount ${device.devicePath}`);
        } catch (error: any) {
          // 如果挂载失败，可能是设备已经自动挂载，继续
          const errorMessage = error instanceof Error ? error.message : String(error);
          console.log(`[MountOperations] 挂载为只读模式失败或已挂载: ${errorMessage}`);
        }

        // 重置后设备是只读状态，不添加到已挂载列表（因为不是读写模式）
        // 也不从已卸载列表中移除，因为需要用户手动选择是否挂载为读写

        return `设备 ${device.volumeName} 已重置并重新挂载为只读模式`;
      } catch (error: any) {
        // 如果挂载失败，至少返回修复成功的消息
        const errorMessage = error instanceof Error ? error.message : String(error);
        throw new Error(`修复完成，但重新挂载失败: ${errorMessage}`);
      }
    } catch (error: any) {
      if (error.message?.includes('密码') || error.message?.includes('password')) {
        throw error;
      }
      const errorMessage = error instanceof Error ? error.message : String(error);
      throw new Error(`重置设备失败: ${errorMessage}`);
    }
  }

  // Repair an NTFS volume without applying resetDevice's persistent read-only behavior.
  async repairDevice(device: NTFSDevice): Promise<string> {
    if (!this.isValidDevicePath(device.devicePath)) {
      throw new Error('REPAIR_INVALID_PATH');
    }

    const ntfsfixPath = await this.getNTFSFixPath();
    const wasReadOnly = device.isReadOnly;
    let password = await this.passwordManager.getPassword('messages.passwordDialog.repairDevice', { name: device.volumeName });
    const execute = async (args: string[]) => {
      try {
        return await this.sudoExecutor.executeSudoWithPassword(args, password);
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        if (!/密码错误|password is incorrect|sorry, try again/i.test(errorMessage)) {
          throw error;
        }

        password = await this.passwordManager.getPassword('messages.passwordDialog.repairDevice', { name: device.volumeName });
        return await this.sudoExecutor.executeSudoWithPassword(args, password);
      }
    };

    try {
      await execute(['diskutil', 'unmount', device.devicePath]);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      throw new Error(`REPAIR_UNMOUNT_FAILED:${errorMessage}`);
    }

    this.mountedDevices.delete(device.disk);
    fs.unlink(`/tmp/ntfs_mounted_${device.disk}`).catch(() => {});
    await new Promise(resolve => setTimeout(resolve, 500));

    let repairError: unknown;
    try {
      await execute([ntfsfixPath, device.devicePath]);
    } catch (error) {
      repairError = error;
    }

    await new Promise(resolve => setTimeout(resolve, 500));
    try {
      if (wasReadOnly) {
        await execute(['diskutil', 'mount', device.devicePath]);
      } else {
        await this.mountDevice(device, password);
      }
    } catch (mountError) {
      const mountMessage = mountError instanceof Error ? mountError.message : String(mountError);
      if (repairError) {
        const repairMessage = repairError instanceof Error ? repairError.message : String(repairError);
        throw new Error(`REPAIR_AND_REMOUNT_FAILED:${repairMessage}|${mountMessage}`);
      }
      throw new Error(`REPAIR_REMOUNT_FAILED:${mountMessage}`);
    }

    if (repairError) {
      const errorMessage = repairError instanceof Error ? repairError.message : String(repairError);
      throw new Error(`REPAIR_FILESYSTEM_FAILED:${errorMessage}`);
    }

    return `设备 ${device.volumeName} 的 NTFS 文件系统已修复并恢复原挂载模式`;
  }

  // 写入 NTFS 卷标后，必须挂到新路径，并尽量刷新 GPT/DiskArbitration，
  // 否则 Finder 已是新名，软件和 diskutil 仍会停在旧名，直到整盘推出。
  async renameDevice(device: NTFSDevice, newName: string): Promise<string> {
    if (!this.isValidDevicePath(device.devicePath)) {
      throw new Error('RENAME_INVALID_PATH');
    }

    const trimmedName = newName.trim();
    if (!trimmedName || trimmedName.length > 32 || /[\\/:*?"<>|]/.test(trimmedName)) {
      throw new Error('RENAME_INVALID_NAME');
    }

    const ntfslabelPath = await this.getNTFSLabelPath();
    const wasReadOnly = device.isReadOnly;
    const parentDiskPath = this.getParentDiskPath(device.devicePath);
    const newVolumePath = `/Volumes/${trimmedName}`;
    let password = await this.passwordManager.getPassword('messages.passwordDialog.renameDevice', { name: device.volumeName });
    const execute = async (args: string[]) => {
      try {
        return await this.sudoExecutor.executeSudoWithPassword(args, password);
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        if (!/密码错误|password is incorrect|sorry, try again/i.test(errorMessage)) {
          throw error;
        }

        password = await this.passwordManager.getPassword('messages.passwordDialog.renameDevice', { name: device.volumeName });
        return await this.sudoExecutor.executeSudoWithPassword(args, password);
      }
    };

    try {
      await execute(['diskutil', 'unmount', device.devicePath]);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      throw new Error(`RENAME_UNMOUNT_FAILED:${errorMessage}`);
    }

    this.mountedDevices.delete(device.disk);
    fs.unlink(`/tmp/ntfs_mounted_${device.disk}`).catch(() => {});
    await new Promise(resolve => setTimeout(resolve, 500));

    let labelError: unknown;
    try {
      await execute([ntfslabelPath, device.devicePath, trimmedName]);
    } catch (error) {
      labelError = error;
    }

    if (!labelError) {
      await this.tryRefreshDiskName(execute, device.devicePath, device.disk, trimmedName);
    }
    await new Promise(resolve => setTimeout(resolve, 500));
    try {
      if (wasReadOnly) {
        try {
          await execute(['diskutil', 'mountDisk', parentDiskPath]);
        } catch {
          await execute(['diskutil', 'mount', device.devicePath]);
        }
      } else {
        await this.mountDevice({
          ...device,
          volumeName: trimmedName,
          volume: newVolumePath
        }, password);
      }
      await this.removeStaleMountPoint(execute, device.volume, newVolumePath);
    } catch (mountError) {
      const mountMessage = mountError instanceof Error ? mountError.message : String(mountError);
      if (labelError) {
        const labelMessage = labelError instanceof Error ? labelError.message : String(labelError);
        throw new Error(`RENAME_AND_REMOUNT_FAILED:${labelMessage}|${mountMessage}`);
      }
      throw new Error(`RENAME_REMOUNT_FAILED:${mountMessage}`);
    }

    if (labelError) {
      const errorMessage = labelError instanceof Error ? labelError.message : String(labelError);
      throw new Error(`RENAME_LABEL_FAILED:${errorMessage}`);
    }

    return `设备卷标已从 ${device.volumeName} 更新为 ${trimmedName}`;
  }

  // 整盘抹成 GPT，再把数据分区写成 NTFS。
  // 中间那步 ExFAT 只是让 macOS 先摆好分区表；真正的文件系统由 mkntfs 写。
  async formatDevice(device: NTFSDevice): Promise<string> {
    if (!this.isValidDevicePath(device.devicePath)) {
      throw new Error('FORMAT_INVALID_PATH');
    }

    const parentDiskPath = this.getParentDiskPath(device.devicePath);
    if (!isValidWholeDiskPath(parentDiskPath) || parentDiskPath === device.devicePath) {
      throw new Error('FORMAT_INVALID_PATH');
    }

    const volumeName = sanitizeNtfsVolumeName(device.volumeName);
    const mkntfsPath = await this.getMkntfsPath();
    await this.assertFormattableParentDisk(parentDiskPath);

    let password = await this.passwordManager.getPassword('messages.passwordDialog.formatDevice', { name: volumeName });
    const execute = async (args: string[], timeoutMs?: number) => {
      try {
        return await this.sudoExecutor.executeSudoWithPassword(args, password, timeoutMs);
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        if (!/密码错误|password is incorrect|sorry, try again/i.test(errorMessage)) {
          throw error;
        }

        password = await this.passwordManager.getPassword('messages.passwordDialog.formatDevice', { name: volumeName });
        return await this.sudoExecutor.executeSudoWithPassword(args, password, timeoutMs);
      }
    };

    try {
      // 所有分区都能安全卸载后，才能执行已确认的整盘抹除。
      await execute(['diskutil', 'unmountDisk', parentDiskPath]);
      await execute(['diskutil', 'eraseDisk', 'ExFAT', volumeName, 'GPT', parentDiskPath], 120000);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      throw new Error(`FORMAT_ERASE_FAILED:${errorMessage}`);
    }

    this.mountedDevices.delete(device.disk);
    fs.unlink(`/tmp/ntfs_mounted_${device.disk}`).catch(() => {});
    await new Promise(resolve => setTimeout(resolve, 500));

    try {
      await execute(['diskutil', 'unmountDisk', parentDiskPath]);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      throw new Error(`FORMAT_UNMOUNT_FAILED:${errorMessage}`);
    }

    await new Promise(resolve => setTimeout(resolve, 500));
    const dataPartitionPath = await this.resolveGptDataPartitionPath(parentDiskPath);
    try {
      await execute([mkntfsPath, '-Q', '-L', volumeName, dataPartitionPath], 120000);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      throw new Error(`FORMAT_MKNTFS_FAILED:${errorMessage}`);
    }

    await new Promise(resolve => setTimeout(resolve, 500));
    try {
      await execAsync(`diskutil mountDisk ${parentDiskPath}`);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      throw new Error(`FORMAT_REMOUNT_FAILED:${errorMessage}`);
    }

    return `设备 ${volumeName} 已格式化为 GPT NTFS`;
  }

  private async assertFormattableParentDisk(parentDiskPath: string): Promise<void> {
    const parentDiskId = getParentDiskId(parentDiskPath);
    let parentInfo: string;
    let bootInfo: string;
    try {
      const [parentResult, bootResult] = await Promise.all([
        execAsync(`diskutil info ${parentDiskPath}`),
        execAsync('diskutil info /')
      ]) as Array<{ stdout: string }>;
      parentInfo = parentResult.stdout || '';
      bootInfo = bootResult.stdout || '';
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      throw new Error(`FORMAT_NOT_ALLOWED:${errorMessage}`);
    }

    const bootDevice = parseDiskutilField(bootInfo, 'Device Identifier') || '';
    const bootWholeDiskId = getParentDiskId(bootDevice);
    if (!isExternalFormattableFromInfo(parentInfo, bootWholeDiskId, parentDiskId)) {
      throw new Error('FORMAT_NOT_ALLOWED');
    }
  }

  private async resolveGptDataPartitionPath(parentDiskPath: string): Promise<string> {
    try {
      const result = await execAsync(`diskutil list ${parentDiskPath}`) as { stdout: string };
      const lines = (result.stdout || '').split('\n');
      const dataLine = [...lines].reverse().find(line =>
        /\b(Microsoft Basic Data|ExFAT|Windows_NTFS|NTFS)\b/i.test(line)
      );
      const partitionMatch = dataLine?.match(/(disk\d+s\d+)/i);
      if (partitionMatch) {
        return `/dev/${partitionMatch[1]}`;
      }
    } catch (error) {
      console.warn('[MountOperations] 解析 GPT 数据分区失败，回退 diskXs2:', error);
    }

    return `${parentDiskPath}s2`;
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
