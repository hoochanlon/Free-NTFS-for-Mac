// NTFS Manager 工具函数
import { exec, execFile } from 'child_process';
import { promisify } from 'util';
import * as fs from 'fs/promises';
import { constants } from 'fs';
import * as os from 'os';
import * as path from 'path';

export const execAsync = promisify(exec);
export const execFileAsync = promisify(execFile);

export interface ExecResult {
  stdout: string;
  stderr: string;
}

export function getCommandEnv(overrides: NodeJS.ProcessEnv = {}): NodeJS.ProcessEnv {
  const prefixes = [
    process.env.HOMEBREW_PREFIX,
    path.join(os.homedir(), '.homebrew'),
    '/opt/homebrew',
    '/usr/local'
  ].filter((prefix): prefix is string => Boolean(prefix));
  const homebrewPaths = prefixes.flatMap(prefix => [
    path.join(prefix, 'bin'),
    path.join(prefix, 'sbin')
  ]);
  const systemPaths = ['/usr/bin', '/bin', '/usr/sbin', '/sbin'];
  const existingPaths = (process.env.PATH || '').split(path.delimiter).filter(Boolean);

  return {
    ...process.env,
    ...overrides,
    PATH: [...new Set([...homebrewPaths, ...systemPaths, ...existingPaths])].join(path.delimiter)
  };
}

export async function findExecutablePath(command: string, searchPath = getCommandEnv().PATH || ''): Promise<string | null> {
  const candidates = path.isAbsolute(command)
    ? [command]
    : searchPath.split(path.delimiter).filter(Boolean).map(directory => path.join(directory, command));

  for (const candidate of candidates) {
    try {
      const stats = await fs.stat(candidate);
      if (stats.isFile()) {
        await fs.access(candidate, constants.X_OK);
        return candidate;
      }
    } catch {
      // Continue searching other candidate paths.
    }
  }

  return null;
}

// 检查命令是否存在（带超时）
// 打包后的应用需要确保 PATH 环境变量包含系统路径
export async function commandExists(command: string): Promise<boolean> {
  try {
    return Boolean(await findExecutablePath(command));
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
