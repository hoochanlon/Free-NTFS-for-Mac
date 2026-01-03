// NTFS-3G 路径查找模块
import { execAsync, fileExists } from './utils';

export class PathFinder {
  private ntfs3gPath: string | null = null;

  // 获取 ntfs-3g 路径
  async getNTFS3GPath(): Promise<string | null> {
    if (this.ntfs3gPath) {
      return this.ntfs3gPath;
    }

    try {
      // 确保 PATH 包含 Homebrew 路径
      const env = {
        ...process.env,
        PATH: process.env.PATH || [
          '/usr/local/bin',
          '/opt/homebrew/bin',
          '/usr/bin',
          '/bin',
          '/usr/sbin',
          '/sbin'
        ].join(':')
      };
      const result = await execAsync('which ntfs-3g', { env }) as { stdout: string };
      const path = result.stdout.trim();
      if (path && await fileExists(path)) {
        this.ntfs3gPath = path;
        return path;
      }
    } catch {}

    // 尝试常见路径
    const commonPaths = [
      '/opt/homebrew/bin/ntfs-3g',
      '/usr/local/bin/ntfs-3g'
    ];

    for (const commonPath of commonPaths) {
      if (await fileExists(commonPath)) {
        this.ntfs3gPath = commonPath;
        return commonPath;
      }
    }

    return null;
  }

  reset(): void {
    this.ntfs3gPath = null;
  }
}
