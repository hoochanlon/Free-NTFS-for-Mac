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
export async function commandExists(command: string): Promise<boolean> {
  try {
    return new Promise<boolean>((resolve) => {
      const childProcess = exec(`which ${command}`, { timeout: 3000 }, (error) => {
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
