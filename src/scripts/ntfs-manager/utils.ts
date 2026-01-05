// NTFS Manager 工具函数
import { exec } from 'child_process';
import { promisify } from 'util';
import * as fs from 'fs/promises';

export const execAsync = promisify(exec);

export interface ExecResult {
  stdout: string;
  stderr: string;
}

// 检查命令是否存在（带超时）
// 打包后的应用需要确保 PATH 环境变量包含系统路径
export async function commandExists(command: string): Promise<boolean> {
  try {
    return new Promise<boolean>((resolve) => {
      // 确保 PATH 包含常见的 Homebrew 路径（合并现有 PATH 和默认路径）
      const defaultPaths = [
        '/usr/local/bin',
        '/opt/homebrew/bin',
        '/usr/bin',
        '/bin',
        '/usr/sbin',
        '/sbin'
      ];
      const existingPath = process.env.PATH || '';
      const pathArray = existingPath ? existingPath.split(':') : [];
      // 合并并去重
      const mergedPaths = [...new Set([...defaultPaths, ...pathArray])];

      const env = {
        ...process.env,
        PATH: mergedPaths.join(':')
      };

      const childProcess = exec(`which ${command}`, {
        timeout: 3000,
        env: env
      }, (error) => {
        clearTimeout(timeout);
        resolve(!error);
      });

      const timeout = setTimeout(() => {
        try {
          childProcess.kill();
        } catch {}
        resolve(false);
      }, 3000);
    });
  } catch {
    return false;
  }
}

// 检查文件是否存在
export async function fileExists(filePath: string): Promise<boolean> {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    // 如果直接路径不存在，尝试添加 /System/Volumes/Data 前缀（macOS Big Sur+）
    if (!filePath.startsWith('/System/Volumes/Data')) {
      try {
        await fs.access(`/System/Volumes/Data${filePath}`);
        return true;
      } catch {
        return false;
      }
    }
    return false;
  }
}
