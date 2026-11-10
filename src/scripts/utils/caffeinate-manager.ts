// Caffeinate 进程管理器
// 实际启停由 PreventSleepController 在有 NTFS 传输时调用

import { spawn, ChildProcess } from 'child_process';

export class CaffeinateManager {
  private caffeinateProcess: ChildProcess | null = null;
  private isActive: boolean = false;
  private startPromise: Promise<{ success: boolean; error?: string }> | null = null;

  /**
   * 启动防止休眠
   * 使用 caffeinate -i -m：
   * -i: 防止系统空闲休眠（-u 无 -t 仅约 5 秒）
   * -m: 防止磁盘空闲休眠
   */
  async start(): Promise<{ success: boolean; error?: string }> {
    if (this.getStatus()) {
      return { success: true };
    }
    if (this.startPromise) {
      return this.startPromise;
    }

    this.startPromise = this.spawnCaffeinate();
    try {
      return await this.startPromise;
    } finally {
      this.startPromise = null;
    }
  }

  private spawnCaffeinate(): Promise<{ success: boolean; error?: string }> {
    this.killProcess();

    const proc = spawn('caffeinate', ['-i', '-m'], {
      stdio: 'ignore'
    });
    this.caffeinateProcess = proc;

    proc.on('error', (error) => {
      console.error('[Caffeinate] 进程错误:', error);
      if (this.caffeinateProcess === proc) {
        this.isActive = false;
        this.caffeinateProcess = null;
      }
    });

    proc.on('close', (code) => {
      console.log(`[Caffeinate] 进程退出，代码: ${code}`);
      if (this.caffeinateProcess === proc) {
        this.isActive = false;
        this.caffeinateProcess = null;
      }
    });

    return new Promise<{ success: boolean; error?: string }>((resolve) => {
      setTimeout(() => {
        if (this.caffeinateProcess === proc && !proc.killed) {
          this.isActive = true;
          console.log('[Caffeinate] 防止休眠已启动');
          resolve({ success: true });
          return;
        }
        this.isActive = false;
        if (this.caffeinateProcess === proc) {
          this.caffeinateProcess = null;
        }
        resolve({ success: false, error: 'caffeinate 进程启动失败' });
      }, 100);
    });
  }

  /**
   * 停止防止休眠
   */
  stop(): void {
    this.killProcess();
    this.isActive = false;
  }

  private killProcess(): void {
    const proc = this.caffeinateProcess;
    this.caffeinateProcess = null;
    this.isActive = false;
    if (proc && !proc.killed) {
      try {
        proc.kill();
        console.log('[Caffeinate] 防止休眠已停止');
      } catch (error) {
        console.error('[Caffeinate] 停止失败:', error);
      }
    }
  }

  /**
   * 获取当前是否正在阻止休眠（进程态，不是用户开关）
   */
  getStatus(): boolean {
    return this.isActive && this.caffeinateProcess !== null && !this.caffeinateProcess.killed;
  }

  /**
   * 切换进程状态（仅内部/调试使用；UI 开关走 PreventSleepController）
   */
  async toggle(): Promise<{ success: boolean; isActive: boolean; error?: string }> {
    if (this.getStatus()) {
      this.stop();
      return { success: true, isActive: false };
    }
    const result = await this.start();
    return { ...result, isActive: result.success };
  }
}

export const caffeinateManager = new CaffeinateManager();
