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
  private readonly debounceMs = 100; // 防抖100ms，避免过于频繁
  private isDetecting: boolean = false; // 标记是否正在检测中
  private pendingEvents: number = 0; // 待处理的事件数量

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
        // 使用持续监听模式，避免重启导致的延迟
        // -o: 只输出事件数量
        // -r: 递归监控
        const env = this.getEnvWithPath();
        this.fswatchProcess = spawn('fswatch', [
          '-o',           // 只输出事件数量
          '/Volumes'      // 监控挂载点目录
        ], { env });

        // 监听标准输出（事件触发）
        this.fswatchProcess.stdout?.on('data', (data) => {
          const output = data.toString().trim();
          console.log(`[事件驱动] fswatch 事件触发: ${output}`);
          this.handleVolumeChange();
          // 持续监听模式，不需要重启
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
          // 持续监听模式下，进程不应该退出
          // 如果进程退出，可能是异常情况
          if (code !== 0 && code !== null) {
            console.warn('[fswatch] 进程异常退出，代码:', code);
          } else if (code === 0) {
            // 正常退出（不应该发生，但如果是正常退出，不增加重启次数）
            console.warn('[fswatch] 进程正常退出（持续监听模式不应该退出）');
          }

          // 只有在异常退出时才尝试重启
          if (this.isRunning && code !== 0 && code !== null) {
            if (this.restartAttempts < this.maxRestartAttempts) {
              console.log(`[事件驱动] 尝试重启 fswatch (${this.restartAttempts + 1}/${this.maxRestartAttempts})`);
            this.restartFswatch();
            } else {
            console.error('[事件驱动] 重启次数过多，停止事件驱动模式');
            this.isRunning = false;
            }
          } else if (this.isRunning && code === 0) {
            // 正常退出但仍在运行状态，可能是手动停止，不重启
            console.log('[事件驱动] 进程正常退出，不重启');
          }
        });

        // 监听进程错误
        this.fswatchProcess.on('error', (error) => {
          console.error('[fswatch] 进程错误:', error);
          if (this.isRunning) {
            if (this.restartAttempts < this.maxRestartAttempts) {
              console.log(`[事件驱动] 进程错误，尝试重启 (${this.restartAttempts + 1}/${this.maxRestartAttempts})`);
            this.restartFswatch();
            } else {
              console.error('[事件驱动] 重启次数过多，停止事件驱动模式');
              this.isRunning = false;
              reject(error);
            }
          } else {
            reject(error);
          }
        });

        // 给进程一点时间启动
        setTimeout(() => {
          if (this.fswatchProcess && !this.fswatchProcess.killed) {
            // 成功启动后，重置重启次数（连续成功运行一段时间后重置）
            // 这样可以避免因为临时问题导致的重启次数累积
            if (this.restartAttempts > 0) {
              console.log('[事件驱动] fswatch 进程成功启动，重置重启计数');
              this.restartAttempts = 0;
            }
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
   * 重启 fswatch（仅在进程异常退出时调用）
   */
  private restartFswatch(): void {
    if (!this.isRunning) {
      return;
    }

    // 增加重启次数
    this.restartAttempts++;

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
      if (this.isRunning && this.restartAttempts <= this.maxRestartAttempts) {
        this.startFswatch().catch((error) => {
          console.error('[事件驱动] 重启失败:', error);
          if (this.restartAttempts >= this.maxRestartAttempts) {
            console.error('[事件驱动] 达到最大重启次数，停止事件驱动模式');
            this.isRunning = false;
          }
        });
      } else if (this.isRunning) {
        console.error('[事件驱动] 重启次数超过限制，停止事件驱动模式');
        this.isRunning = false;
      }
    }, 200); // 增加延迟，避免过于频繁重启
  }

  /**
   * 处理卷变化事件（即时响应模式）
   */
  private async handleVolumeChange(): Promise<void> {
    // 增加待处理事件计数
    this.pendingEvents++;
    console.log(`[事件驱动] 收到卷变化事件，待处理事件数: ${this.pendingEvents}, 正在检测: ${this.isDetecting}`);

    // 如果正在检测，只记录事件，等待检测完成后再处理
    if (this.isDetecting) {
      console.log('[事件驱动] 正在检测中，事件已记录，等待检测完成后处理');
      return;
    }

    // 清除之前的防抖定时器
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
    }

    // 使用防抖，但确保每次事件都会被处理
    this.debounceTimer = setTimeout(async () => {
      const eventsToProcess = this.pendingEvents;
      this.pendingEvents = 0;
      this.debounceTimer = null;

      console.log(`[事件驱动] 开始处理 ${eventsToProcess} 个事件`);
      // 执行检测
      await this.performDetection(eventsToProcess);
    }, this.debounceMs);
  }

  /**
   * 执行设备检测
   */
  private async performDetection(eventCount: number): Promise<void> {
    if (this.isDetecting) {
      console.log('[事件驱动] 检测已在进行中，跳过');
      return; // 防止并发检测
    }

    this.isDetecting = true;
    console.log(`[事件驱动] 开始检测，事件数: ${eventCount}`);

    try {
      // 立即检测一次
      console.log('[事件驱动] 第一次检测...');
      const devices1 = await this.deviceDetector.getNTFSDevices(true);
      console.log(`[事件驱动] 第一次检测完成，设备数: ${devices1.length}`);
      if (this.onChangeCallback) {
        this.onChangeCallback(devices1);
      }

      // 延迟检测，确保系统完成挂载操作
      await new Promise(resolve => setTimeout(resolve, 300));

      // 二次检测
      console.log('[事件驱动] 第二次检测...');
      const devices2 = await this.deviceDetector.getNTFSDevices(true);
      console.log(`[事件驱动] 第二次检测完成，设备数: ${devices2.length}`);
      if (this.onChangeCallback) {
        this.onChangeCallback(devices2);
      }

      // 如果检测期间有多个事件（连续插入多块U盘），增加检测次数
      if (eventCount > 1) {
        console.log(`[事件驱动] 检测到多个事件(${eventCount})，增加检测次数`);
        await new Promise(resolve => setTimeout(resolve, 400));
        const devices3 = await this.deviceDetector.getNTFSDevices(true);
        console.log(`[事件驱动] 第三次检测完成，设备数: ${devices3.length}`);
        if (this.onChangeCallback) {
          this.onChangeCallback(devices3);
        }

        // 再检测一次，确保捕获所有设备
        await new Promise(resolve => setTimeout(resolve, 500));
        const devices4 = await this.deviceDetector.getNTFSDevices(true);
        console.log(`[事件驱动] 第四次检测完成，设备数: ${devices4.length}`);
        if (this.onChangeCallback) {
          this.onChangeCallback(devices4);
        }
      }

      // 检查是否有新事件在检测期间到达
      // 注意：这里不重置 isDetecting，让后续检测能够继续
      if (this.pendingEvents > 0) {
        console.log(`[事件驱动] 检测期间有新事件(${this.pendingEvents}个)，立即继续处理`);
        // 有新事件，立即再次检测（不等待）
        const remainingEvents = this.pendingEvents;
        this.pendingEvents = 0;
        // 不等待，立即继续检测
        await this.performDetection(remainingEvents);
        return; // 返回，让 finally 块处理
        }
      } catch (error) {
        console.error('[事件驱动] 处理设备变化失败:', error);
      } finally {
      this.isDetecting = false;
      console.log('[事件驱动] 检测完成，待处理事件数:', this.pendingEvents);

      // 如果检测完成后还有待处理的事件，继续处理
      if (this.pendingEvents > 0) {
        console.log(`[事件驱动] 检测完成后还有 ${this.pendingEvents} 个待处理事件，继续处理`);
        const remainingEvents = this.pendingEvents;
        this.pendingEvents = 0;
        setTimeout(() => {
          this.performDetection(remainingEvents).catch(error => {
            console.error('[事件驱动] 后续检测失败:', error);
          });
        }, 200);
      }
    }
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
