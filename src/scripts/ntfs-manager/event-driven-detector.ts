// 事件驱动检测器 - 使用 fswatch 监控 /Volumes 目录变化
// 优势：零延迟响应，极低CPU使用，完全消除轮询

import { spawn, ChildProcess } from 'child_process';
import { DeviceDetector } from './device-detector';
import type { NTFSDevice } from '../../types/electron';

export class EventDrivenDetector {
  private fswatchProcess: ChildProcess | null = null;
  private deviceDetector: DeviceDetector;
  private onChangeCallback?: (devices: NTFSDevice[]) => void;
  private debounceTimer: NodeJS.Timeout | null = null;
  private isRunning: boolean = false;
  private restartAttempts: number = 0;
  private readonly maxRestartAttempts = 3;
  private readonly debounceMs = 100; // 防抖100ms（减少延迟）

  constructor(deviceDetector: DeviceDetector) {
    this.deviceDetector = deviceDetector;
  }

  /**
   * 获取正确的 PATH 环境变量（包含 Homebrew 路径）
   */
  private getEnvWithPath(): NodeJS.ProcessEnv {
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

    return {
      ...process.env,
      PATH: mergedPaths.join(':')
    };
  }

  /**
   * 检查 fswatch 是否可用
   */
  async checkFswatchAvailable(): Promise<boolean> {
    return new Promise((resolve) => {
      const env = this.getEnvWithPath();
      const check = spawn('which', ['fswatch'], { env });
      check.on('close', (code) => {
        resolve(code === 0);
      });
      check.on('error', () => {
        resolve(false);
      });
    });
  }

  /**
   * 启动事件驱动检测
   */
  async start(callback: (devices: NTFSDevice[]) => void): Promise<boolean> {
    if (this.isRunning) {
      console.warn('[事件驱动] 检测已在运行');
      return true;
    }

    // 检查 fswatch 是否可用
    const available = await this.checkFswatchAvailable();
    if (!available) {
      console.warn('[事件驱动] fswatch 未安装，无法使用事件驱动模式');
      return false;
    }

    try {
      this.onChangeCallback = callback;
      this.isRunning = true;
      this.restartAttempts = 0;

      await this.startFswatch();

      console.log('✅ [事件驱动] 检测已启动');
      return true;
    } catch (error) {
      console.error('❌ [事件驱动] 启动失败:', error);
      this.isRunning = false;
      return false;
    }
  }

  /**
   * 启动 fswatch 进程
   */
  private async startFswatch(): Promise<void> {
    return new Promise((resolve, reject) => {
      try {
        // 使用 fswatch 监控 /Volumes 目录
        // -o: 只输出事件数量
        // -1: 只监听一次（配合循环使用）
        // -r: 递归监控
        // -E: 只监控目录创建/删除事件
        const env = this.getEnvWithPath();
        this.fswatchProcess = spawn('fswatch', [
          '-o',           // 只输出事件数量
          '-1',           // 只监听一次（配合循环使用）
          '/Volumes'      // 监控挂载点目录
        ], { env });

        // 监听标准输出（事件触发）
        this.fswatchProcess.stdout?.on('data', () => {
          this.handleVolumeChange();
          // 事件触发后，重新启动监听（因为使用了 -1 参数）
          this.restartFswatch();
        });

        // 监听错误输出
        this.fswatchProcess.stderr?.on('data', (data) => {
          const errorMsg = data.toString();
          // 忽略一些非关键错误
          if (!errorMsg.includes('No such file') && !errorMsg.includes('Permission denied')) {
            console.error('[fswatch] 错误:', errorMsg);
          }
        });

        // 监听进程退出
        this.fswatchProcess.on('close', (code) => {
          if (code !== 0 && code !== null) {
            console.warn('[fswatch] 进程退出，代码:', code);
          }

          // 如果还在运行状态，尝试重启
          if (this.isRunning && this.restartAttempts < this.maxRestartAttempts) {
            this.restartFswatch();
          } else if (this.isRunning) {
            console.error('[事件驱动] 重启次数过多，停止事件驱动模式');
            this.isRunning = false;
          }
        });

        // 监听进程错误
        this.fswatchProcess.on('error', (error) => {
          console.error('[fswatch] 进程错误:', error);
          if (this.isRunning && this.restartAttempts < this.maxRestartAttempts) {
            this.restartFswatch();
          } else {
            this.isRunning = false;
            reject(error);
          }
        });

        // 给进程一点时间启动
        setTimeout(() => {
          if (this.fswatchProcess && !this.fswatchProcess.killed) {
            resolve();
          } else {
            reject(new Error('fswatch 进程启动失败'));
          }
        }, 100);
      } catch (error) {
        reject(error);
      }
    });
  }

  /**
   * 重启 fswatch（当事件触发后）
   */
  private restartFswatch(): void {
    if (!this.isRunning) {
      return;
    }

    // 清理旧进程
    if (this.fswatchProcess) {
      this.fswatchProcess.removeAllListeners();
      if (!this.fswatchProcess.killed) {
        this.fswatchProcess.kill();
      }
      this.fswatchProcess = null;
    }

    // 延迟重启，避免过于频繁
    setTimeout(() => {
      if (this.isRunning) {
        this.restartAttempts++;
        this.startFswatch().catch((error) => {
          console.error('[事件驱动] 重启失败:', error);
          if (this.restartAttempts >= this.maxRestartAttempts) {
            this.isRunning = false;
          }
        });
      }
    }, 100);
  }

  /**
   * 处理卷变化事件
   */
  private async handleVolumeChange(): Promise<void> {
    // 防抖：200ms内多次事件只处理一次
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
    }

    this.debounceTimer = setTimeout(async () => {
      try {
        // 延迟一小段时间，确保系统完成挂载/卸载操作（减少延迟）
        await new Promise(resolve => setTimeout(resolve, 150));

        // 强制刷新，失效所有缓存，确保获取最新状态
        const devices = await this.deviceDetector.getNTFSDevices(true);

        if (this.onChangeCallback) {
          this.onChangeCallback(devices);
        }
      } catch (error) {
        console.error('[事件驱动] 处理设备变化失败:', error);
      } finally {
        this.debounceTimer = null;
      }
    }, this.debounceMs);
  }

  /**
   * 停止事件驱动检测
   */
  stop(): void {
    this.isRunning = false;

    if (this.fswatchProcess) {
      this.fswatchProcess.removeAllListeners();
      if (!this.fswatchProcess.killed) {
        this.fswatchProcess.kill();
      }
      this.fswatchProcess = null;
    }

    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
      this.debounceTimer = null;
    }

    this.onChangeCallback = undefined;
    this.restartAttempts = 0;

    console.log('[事件驱动] 检测已停止');
  }

  /**
   * 检查是否正在运行
   */
  isActive(): boolean {
    return this.isRunning && this.fswatchProcess !== null && !this.fswatchProcess.killed;
  }

  /**
   * 获取安装提示信息
   */
  static getInstallMessage(): string {
    return 'fswatch 未安装。要使用事件驱动模式（零延迟、极低CPU），请运行：\nbrew install fswatch';
  }
}
