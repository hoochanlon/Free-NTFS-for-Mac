// Caffeinate 进程管理器
// 用于管理防止休眠功能

import { spawn, ChildProcess } from 'child_process';

export class CaffeinateManager {
  private caffeinateProcess: ChildProcess | null = null;
  private isActive: boolean = false;

  /**
   * 启动防止休眠
   * 使用 caffeinate -u -m 参数：
   * -u: 防止系统休眠（当有用户活动时）
   * -m: 防止磁盘休眠
   */
  async start(): Promise<{ success: boolean; error?: string }> {
    if (this.isActive && this.caffeinateProcess && !this.caffeinateProcess.killed) {
      console.log('[Caffeinate] 防止休眠已启动，跳过重复启动');
      return { success: true };
    }

    try {
      // 停止旧的进程（如果存在）
      this.stop();

      // 启动 caffeinate 进程
      this.caffeinateProcess = spawn('caffeinate', ['-u', '-m']);

      this.caffeinateProcess.on('error', (error) => {
        console.error('[Caffeinate] 进程错误:', error);
        this.isActive = false;
        this.caffeinateProcess = null;
      });

      this.caffeinateProcess.on('close', (code) => {
        console.log(`[Caffeinate] 进程退出，代码: ${code}`);
        this.isActive = false;
        this.caffeinateProcess = null;
      });

      // 等待进程启动
      await new Promise<void>((resolve, reject) => {
        if (!this.caffeinateProcess) {
          reject(new Error('caffeinate 进程启动失败'));
          return;
        }

        // 检查进程是否成功启动
        setTimeout(() => {
          if (this.caffeinateProcess && !this.caffeinateProcess.killed) {
            this.isActive = true;
            console.log('[Caffeinate] 防止休眠已启动');
            resolve();
          } else {
            reject(new Error('caffeinate 进程启动失败'));
          }
        }, 100);
      });

      return { success: true };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      console.error('[Caffeinate] 启动失败:', errorMessage);
      this.isActive = false;
      this.caffeinateProcess = null;
      return { success: false, error: errorMessage };
    }
  }

  /**
   * 停止防止休眠
   */
  stop(): void {
    if (this.caffeinateProcess && !this.caffeinateProcess.killed) {
      try {
        this.caffeinateProcess.kill();
        console.log('[Caffeinate] 防止休眠已停止');
      } catch (error) {
        console.error('[Caffeinate] 停止失败:', error);
      }
    }
    this.isActive = false;
    this.caffeinateProcess = null;
  }

  /**
   * 获取当前状态
   */
  getStatus(): boolean {
    return this.isActive && this.caffeinateProcess !== null && !this.caffeinateProcess.killed;
  }

  /**
   * 切换状态
   */
  async toggle(): Promise<{ success: boolean; isActive: boolean; error?: string }> {
    if (this.getStatus()) {
      this.stop();
      return { success: true, isActive: false };
    } else {
      const result = await this.start();
      return { ...result, isActive: result.success };
    }
  }
}

// 导出单例
export const caffeinateManager = new CaffeinateManager();
