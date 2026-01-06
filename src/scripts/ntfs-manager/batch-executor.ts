// 批量命令执行器 - 优化系统命令调用
// 优化策略：
// 1. 批量执行多个命令，减少进程创建开销
// 2. 并行执行独立命令
// 3. 复用命令结果
// 4. 避免重复执行相同命令

import { execAsync } from './utils';

export interface CommandResult {
  stdout: string;
  stderr?: string;
  success: boolean;
}

export class BatchExecutor {
  private commandCache: Map<string, { result: CommandResult; timestamp: number; ttl: number }> = new Map();
  private readonly defaultTTL = 2000; // 默认缓存2秒

  /**
   * 批量执行命令（并行）
   * @param commands 命令数组
   * @param cacheTTL 缓存时间（毫秒），0表示不缓存
   */
  async executeBatch(
    commands: Array<{ cmd: string; key?: string; ttl?: number }>,
    cacheTTL: number = 2000
  ): Promise<Map<string, CommandResult>> {
    const results = new Map<string, CommandResult>();
    const toExecute: Array<{ cmd: string; key: string; ttl: number }> = [];

    // 检查缓存
    for (const { cmd, key, ttl = cacheTTL } of commands) {
      const cacheKey = key || cmd;
      const cached = this.getCached(cacheKey, ttl);
      if (cached) {
        results.set(cacheKey, cached);
      } else {
        toExecute.push({ cmd, key: cacheKey, ttl });
      }
    }

    // 并行执行未缓存的命令
    if (toExecute.length > 0) {
      const promises = toExecute.map(async ({ cmd, key, ttl }) => {
        try {
          const result = await execAsync(cmd) as { stdout: string; stderr?: string };
          const commandResult: CommandResult = {
            stdout: result.stdout || '',
            stderr: result.stderr,
            success: true
          };

          // 缓存结果
          if (ttl > 0) {
            this.setCached(key, commandResult, ttl);
          }

          return { key, result: commandResult };
        } catch (error: any) {
          const commandResult: CommandResult = {
            stdout: error.stdout || '',
            stderr: error.stderr || error.message || '',
            success: false
          };

          // 即使失败也缓存短暂时间，避免重复失败
          if (ttl > 0) {
            this.setCached(key, commandResult, Math.min(ttl, 500));
          }

          return { key, result: commandResult };
        }
      });

      const executed = await Promise.all(promises);
      for (const { key, result } of executed) {
        results.set(key, result);
      }
    }

    return results;
  }

  /**
   * 执行单个命令（带缓存）
   */
  async execute(cmd: string, cacheKey?: string, ttl: number = 2000): Promise<CommandResult> {
    const key = cacheKey || cmd;
    const cached = this.getCached(key, ttl);
    if (cached) {
      return cached;
    }

    try {
      const result = await execAsync(cmd) as { stdout: string; stderr?: string };
      const commandResult: CommandResult = {
        stdout: result.stdout || '',
        stderr: result.stderr,
        success: true
      };

      if (ttl > 0) {
        this.setCached(key, commandResult, ttl);
      }

      return commandResult;
    } catch (error: any) {
      const commandResult: CommandResult = {
        stdout: error.stdout || '',
        stderr: error.stderr || error.message || '',
        success: false
      };

      if (ttl > 0) {
        this.setCached(key, commandResult, Math.min(ttl, 500));
      }

      return commandResult;
    }
  }

  /**
   * 获取缓存的结果
   */
  private getCached(key: string, ttl: number): CommandResult | null {
    const cached = this.commandCache.get(key);
    if (cached) {
      const age = Date.now() - cached.timestamp;
      if (age < cached.ttl) {
        return cached.result;
      } else {
        // 缓存过期，删除
        this.commandCache.delete(key);
      }
    }
    return null;
  }

  /**
   * 设置缓存
   */
  private setCached(key: string, result: CommandResult, ttl: number): void {
    this.commandCache.set(key, {
      result,
      timestamp: Date.now(),
      ttl
    });
  }

  /**
   * 使缓存失效
   */
  invalidate(key?: string): void {
    if (key) {
      this.commandCache.delete(key);
    } else {
      this.commandCache.clear();
    }
  }

  /**
   * 清理过期缓存
   */
  cleanup(): void {
    const now = Date.now();
    for (const [key, cached] of this.commandCache.entries()) {
      const age = now - cached.timestamp;
      if (age >= cached.ttl) {
        this.commandCache.delete(key);
      }
    }
  }

  /**
   * 获取缓存统计
   */
  getStats(): { size: number; keys: string[] } {
    return {
      size: this.commandCache.size,
      keys: Array.from(this.commandCache.keys())
    };
  }
}
