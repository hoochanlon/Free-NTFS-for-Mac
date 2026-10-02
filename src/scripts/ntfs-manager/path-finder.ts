// NTFS-3G 路径查找模块
/// <reference types="node" />
import * as path from 'path';
import { execFileAsync, findExecutablePath, getCommandEnv } from './utils';

export class PathFinder {
  private ntfs3gPath: string | null = null;

  // 获取 ntfs-3g 路径
  async getNTFS3GPath(): Promise<string | null> {
    if (this.ntfs3gPath) {
      return this.ntfs3gPath;
    }

    const env = getCommandEnv();
    const ntfs3gPath = await findExecutablePath('ntfs-3g', env.PATH);
    if (ntfs3gPath) {
      this.ntfs3gPath = ntfs3gPath;
      return ntfs3gPath;
    }

    const brewPath = await findExecutablePath('brew', env.PATH);
    if (!brewPath) {
      return null;
    }

    for (const formula of ['ntfs-3g-mac', 'ntfs-3g']) {
      try {
        const { stdout } = await execFileAsync(brewPath, ['--prefix', formula], {
          env,
          timeout: 3000
        });
        const formulaPrefix = stdout.trim();
        if (!formulaPrefix) {
          continue;
        }

        for (const directory of ['bin', 'sbin']) {
          const candidate = path.join(formulaPrefix, directory, 'ntfs-3g');
          if (await findExecutablePath(candidate)) {
            this.ntfs3gPath = candidate;
            return candidate;
          }
        }
      } catch {
        // A formula can return a predicted prefix even when it is not installed.
      }
    }

    return null;
  }

  reset(): void {
    this.ntfs3gPath = null;
  }
}
