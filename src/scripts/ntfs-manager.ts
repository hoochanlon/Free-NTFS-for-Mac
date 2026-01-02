// NTFS Manager 主文件 - 整合各个模块
import { PathFinder } from './ntfs-manager/path-finder';
import { checkDependencies } from './ntfs-manager/dependencies';
import { fileExists, execAsync, ExecResult } from './ntfs-manager/utils';
import { spawn } from 'child_process';
import * as fs from 'fs/promises';
import type { NTFSDevice } from '../types/electron';
import { KeychainManager } from './utils/keychain';
import { SettingsManager } from './utils/settings';

class NTFSManager {
  private pathFinder: PathFinder;
  private mountedDevices: Set<string> = new Set();

  constructor() {
    this.pathFinder = new PathFinder();
  }

  // 检查依赖
  async checkDependencies() {
    return await checkDependencies();
  }

  // 已移除自动安装功能，改为仅检测和提供安装指引
  // async installDependencies(): Promise<string> {
  //   const result = await installDependencies();
  //   // 重新获取路径
  //   this.pathFinder.reset();
  //   return result;
  // }

  // 获取 ntfs-3g 路径
  async getNTFS3GPath(): Promise<string | null> {
    return await this.pathFinder.getNTFS3GPath();
  }

  // 获取 NTFS 设备列表
  async getNTFSDevices(): Promise<NTFSDevice[]> {
    try {
      let stdout = '';
      try {
        // 同时检查 ntfs 和 ntfs-3g 的挂载信息（ntfs-3g 使用 FUSE）
        const result = await execAsync('mount | grep -iE "(ntfs|fuse)"') as { stdout: string };
        stdout = result.stdout || '';
      } catch (error: any) {
        if (error.code === 1) {
          stdout = error.stdout || '';
          if (!stdout) {
            return [];
          }
        } else {
          return [];
        }
      }

      const lines = stdout.trim().split('\n').filter(line => line.length > 0 && (line.toLowerCase().includes('ntfs') || line.toLowerCase().includes('fuse')));

      if (lines.length === 0) {
        return [];
      }

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

        const markerFile = `/tmp/ntfs_mounted_${disk}`;
        let markerExists = false;
        try {
          markerExists = await fileExists(markerFile);
          // 如果标记文件存在，将设备添加到 mountedDevices Set 中
          // 这样可以确保应用重启后仍能正确识别已挂载的设备
          if (markerExists) {
            this.mountedDevices.add(disk);
          }
        } catch {
          markerExists = false;
        }

        // 判断设备是否已通过 ntfs-3g 挂载为读写模式
        // 如果设备在 mountedDevices Set 中，说明它已经成功挂载过
        // 或者标记文件存在，说明之前挂载过（应用重启后恢复状态）
        const isInMountedSet = this.mountedDevices.has(disk);
        const deviceIsMounted = isInMountedSet || markerExists;

        // 如果设备已通过 ntfs-3g 挂载为读写模式，强制设置 isReadOnly 为 false
        // 即使 mount 命令输出可能仍显示 read-only（因为系统可能先以只读模式挂载）
        const finalIsReadOnly = deviceIsMounted ? false : isReadOnly;

        devices.push({
          disk,
          devicePath,
          volume,
          volumeName,
          isReadOnly: finalIsReadOnly,
          options,
          isMounted: deviceIsMounted
        });
      }

      return devices;
    } catch (error) {
      console.error('获取 NTFS 设备列表失败:', error);
      return [];
    }
  }

  // 获取管理员密码
  async getPassword(prompt: string = '需要管理员权限'): Promise<string> {
    // 先检查设置，看是否允许使用保存的密码
    const settings = await SettingsManager.getSettings();

    if (settings.savePassword) {
      try {
        const savedPassword = await KeychainManager.getPassword();
        if (savedPassword && savedPassword.length > 0) {
          // 直接返回保存的密码，在实际使用时验证
          // 这样可以避免预验证可能的问题
          console.log('使用保存的密码');
          return savedPassword;
        }
      } catch (error) {
        console.warn('读取保存的密码失败:', error);
      }
    }

    // 如果没有保存的密码或密码无效，提示用户输入
    try {
      const escapedPrompt = prompt.replace(/"/g, '\\"').replace(/\n/g, ' ');
      const scriptPath = `/tmp/ntfs_password_${Date.now()}.scpt`;
      const script = `tell application "System Events"
  activate
end tell
tell application "System Events"
  set theAnswer to display dialog "${escapedPrompt}" & return & return & "请输入您的管理员密码：" default answer "" with hidden answer buttons {"取消", "确定"} default button "确定" with icon caution
  return text returned of theAnswer
end tell`;

      await fs.writeFile(scriptPath, script);

      try {
        const result = await execAsync(`osascript "${scriptPath}"`) as { stdout: string };
        const match = result.stdout.match(/text returned:(.+)/i);
        let password: string;

        if (match && match[1]) {
          password = match[1].trim();
        } else {
          const trimmed = result.stdout.trim();
          if (trimmed && !trimmed.toLowerCase().includes('error')) {
            password = trimmed;
          } else {
            throw new Error('无法解析密码输入结果');
          }
        }

        // 如果设置允许保存密码，保存新输入的密码
        if (settings.savePassword && password) {
          try {
            await KeychainManager.savePassword(password);
            console.log('密码已保存到 Keychain');
          } catch (error) {
            console.warn('保存密码失败:', error);
          }
        }

        return password;
      } finally {
        fs.unlink(scriptPath).catch(() => {});
      }
    } catch (error: any) {
      if (error.code === 1 || error.stderr?.includes('User canceled') || error.stderr?.includes('用户取消了') || error.message?.includes('取消')) {
        throw new Error('用户取消了密码输入');
      }
      const errorMessage = error instanceof Error ? error.message : String(error);
      throw new Error(`获取密码失败: ${errorMessage}`);
    }
  }

  // 使用密码执行 sudo 命令
  async executeSudoWithPassword(args: string[], password: string): Promise<ExecResult> {
    return new Promise<ExecResult>((resolve, reject) => {
      const process = spawn('sudo', ['-S', ...args], {
        stdio: ['pipe', 'pipe', 'pipe']
      });

      let stdout = '';
      let stderr = '';

      process.stdout?.on('data', (data) => {
        stdout += data.toString();
      });

      process.stderr?.on('data', (data) => {
        stderr += data.toString();
      });

      process.stdin?.write(password + '\n');
      process.stdin?.end();

      const timeout = setTimeout(() => {
        try {
          process.kill('SIGKILL');
        } catch {}
        reject(new Error('操作超时'));
      }, 30000);

      process.on('close', async (code) => {
        clearTimeout(timeout);
        if (code === 0) {
          resolve({ stdout, stderr });
        } else {
          // 检查是否是密码错误
          if (stderr.includes('password is incorrect') || stderr.includes('Sorry, try again') || stderr.includes('incorrect password')) {
            // 如果密码错误，删除保存的密码
            const settings = await SettingsManager.getSettings();
            if (settings.savePassword) {
              try {
                await KeychainManager.deletePassword();
                console.log('密码错误，已删除保存的密码');
              } catch (error) {
                console.warn('删除保存的密码失败:', error);
              }
            }
            reject(new Error('密码错误，请重试'));
          } else {
            reject(new Error(stderr.trim() || stdout.trim() || `退出码 ${code}`));
          }
        }
      });

      process.on('error', (error) => {
        clearTimeout(timeout);
        reject(new Error(`执行失败: ${error.message}`));
      });
    });
  }

  // 卸载设备
  async unmountDevice(device: NTFSDevice): Promise<string> {
    try {
      const password = await this.getPassword(`卸载设备 ${device.volumeName}`);
      await this.executeSudoWithPassword(['umount', '-f', device.devicePath], password);
      this.mountedDevices.delete(device.disk);
      fs.unlink(`/tmp/ntfs_mounted_${device.disk}`).catch(() => {});
      return `设备 ${device.volumeName} 已卸载`;
    } catch (error: any) {
      // 如果密码错误，重新获取密码并重试
      if (error.message?.includes('密码错误') || error.message?.includes('password is incorrect') || error.message?.includes('Sorry, try again')) {
        try {
          // 删除保存的密码后，重新获取
          const password = await this.getPassword(`卸载设备 ${device.volumeName}`);
          await this.executeSudoWithPassword(['umount', '-f', device.devicePath], password);
          this.mountedDevices.delete(device.disk);
          fs.unlink(`/tmp/ntfs_mounted_${device.disk}`).catch(() => {});
          return `设备 ${device.volumeName} 已卸载`;
        } catch (retryError) {
          throw retryError;
        }
      }
      if (error.message?.includes('密码') || error.message?.includes('password')) {
        throw error;
      }
      try {
        return await this.unmountWithDiskutil(device);
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
      let password = await this.getPassword(`挂载设备 ${device.volumeName} 为读写模式`);

      try {
        await this.executeSudoWithPassword(['umount', '-f', device.devicePath], password);
      } catch (error: any) {
        // 如果密码错误，重新获取密码
        if (error.message?.includes('密码错误') || error.message?.includes('password is incorrect') || error.message?.includes('Sorry, try again')) {
          password = await this.getPassword(`挂载设备 ${device.volumeName} 为读写模式`);
          try {
            await this.executeSudoWithPassword(['umount', '-f', device.devicePath], password);
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

      try {
        const mountPromise = this.executeSudoWithPassword(mountArgs, password);
        const timeoutPromise = new Promise<never>((_, reject) => {
          setTimeout(() => reject(new Error('挂载超时（10秒）。可能是 Windows 快速启动导致文件系统处于脏状态。建议在 Windows 中完全关闭（而非休眠），或禁用快速启动功能。')), 10000);
        });

        await Promise.race([mountPromise, timeoutPromise]);
      } catch (error: any) {
        // 如果密码错误，重新获取密码并重试
        if (error.message?.includes('密码错误') || error.message?.includes('password is incorrect') || error.message?.includes('Sorry, try again')) {
          password = await this.getPassword(`挂载设备 ${device.volumeName} 为读写模式`);
          const mountPromise = this.executeSudoWithPassword(mountArgs, password);
          const timeoutPromise = new Promise<never>((_, reject) => {
            setTimeout(() => reject(new Error('挂载超时（10秒）。可能是 Windows 快速启动导致文件系统处于脏状态。建议在 Windows 中完全关闭（而非休眠），或禁用快速启动功能。')), 10000);
          });
          await Promise.race([mountPromise, timeoutPromise]);
        } else {
          throw error;
        }
      }

      this.mountedDevices.add(device.disk);
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

export default new NTFSManager();
