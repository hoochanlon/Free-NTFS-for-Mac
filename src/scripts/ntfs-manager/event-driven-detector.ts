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
  private detectionTimeout: NodeJS.Timeout | null = null; // 检测超时定时器
  private readonly maxDetectionTime = 10000; // 最大检测时间10秒
  private healthCheckInterval: NodeJS.Timeout | null = null; // 健康检查定时器

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
        // -o: 只输出事件数量（更高效，避免大量文件路径输出）
        // -r: 递归监控
        const env = this.getEnvWithPath();
        this.fswatchProcess = spawn('fswatch', [
          '-o',           // 只输出事件数量
          '-r',           // 递归监控
          '/Volumes'      // 监控挂载点目录
        ], { env });

        // 监听标准输出（事件触发）
        // 使用 -o 参数时，fswatch 只输出事件数量（数字）
        this.fswatchProcess.stdout?.on('data', (data) => {
          const output = data.toString().trim();
          console.log(`[事件驱动] fswatch 事件触发: ${output}, 进程状态: running=${this.isRunning}, detecting=${this.isDetecting}`);

          if (!this.isRunning) {
            console.warn('[事件驱动] 收到事件但检测器未运行，忽略事件');
            return;
          }

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
          // 如果进程退出，无论什么原因都应该尝试重启（除非是手动停止）
          console.log(`[fswatch] 进程退出，代码: ${code}, 运行状态: ${this.isRunning}, 重启次数: ${this.restartAttempts}`);

          if (code !== 0 && code !== null) {
            console.warn('[fswatch] 进程异常退出，代码:', code);
          } else {
            // 正常退出或 code 为 null（持续监听模式不应该退出）
            console.warn(`[fswatch] 进程退出（持续监听模式不应该退出），代码: ${code}`);
          }

          // 停止健康检查（如果正在运行）
          if (this.healthCheckInterval) {
            clearInterval(this.healthCheckInterval);
            this.healthCheckInterval = null;
          }

          // 只要进程还在运行状态，无论退出代码是什么，都尝试重启
          // 因为持续监听模式下，进程不应该退出
          if (this.isRunning) {
            if (this.restartAttempts < this.maxRestartAttempts) {
              console.log(`[事件驱动] 进程退出，尝试重启 fswatch (${this.restartAttempts + 1}/${this.maxRestartAttempts})`);
              this.restartFswatch();
            } else {
              console.error('[事件驱动] 重启次数过多，停止事件驱动模式');
              this.isRunning = false;
            }
          } else {
            console.log('[事件驱动] 检测器已停止，不重启进程');
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
            // 启动健康检查
            this.startHealthCheck();
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
   * 重启 fswatch（进程退出时调用）
   */
  private restartFswatch(): void {
    if (!this.isRunning) {
      console.log('[事件驱动] 检测器已停止，不重启进程');
      return;
    }

    // 增加重启次数
    this.restartAttempts++;
    console.log(`[事件驱动] 准备重启 fswatch，当前重启次数: ${this.restartAttempts}/${this.maxRestartAttempts}`);

    // 清理旧进程（如果还存在）
    if (this.fswatchProcess) {
      try {
        this.fswatchProcess.removeAllListeners();
        if (!this.fswatchProcess.killed) {
          this.fswatchProcess.kill();
        }
      } catch (error) {
        console.warn('[事件驱动] 清理旧进程时出错:', error);
      }
      this.fswatchProcess = null;
    }

    // 延迟重启，避免过于频繁
    setTimeout(() => {
      if (!this.isRunning) {
        console.log('[事件驱动] 检测器已停止，取消重启');
        return;
      }

      if (this.restartAttempts <= this.maxRestartAttempts) {
        console.log(`[事件驱动] 开始重启 fswatch (${this.restartAttempts}/${this.maxRestartAttempts})`);
        this.startFswatch().catch((error) => {
          console.error('[事件驱动] 重启失败:', error);
          if (this.restartAttempts >= this.maxRestartAttempts) {
            console.error('[事件驱动] 达到最大重启次数，停止事件驱动模式');
            this.isRunning = false;
          } else {
            // 如果重启失败但还没达到最大次数，继续尝试
            console.log('[事件驱动] 重启失败，将在下次事件时重试');
          }
        });
      } else {
        console.error('[事件驱动] 重启次数超过限制，停止事件驱动模式');
        this.isRunning = false;
      }
    }, 500); // 增加延迟到 500ms，给系统更多时间清理
  }

  /**
   * 处理卷变化事件（即时响应模式）
   */
  private async handleVolumeChange(): Promise<void> {
    // 增加待处理事件计数
    this.pendingEvents++;
    console.log(`[事件驱动] 收到卷变化事件，待处理事件数: ${this.pendingEvents}, 正在检测: ${this.isDetecting}`);

    // 如果正在检测，只记录事件，等待检测完成后再处理
    // 但如果检测时间过长（可能是卡住了），强制重置并处理新事件
    if (this.isDetecting) {
      console.log('[事件驱动] 正在检测中，事件已记录，等待检测完成后处理');
      // 检查是否检测超时
      if (this.detectionTimeout) {
        // 已经有超时定时器，说明检测正在进行中，只记录事件
        return;
      } else {
        // 没有超时定时器，说明检测可能卡住了，强制重置
        console.warn('[事件驱动] 检测标志为true但没有超时定时器，强制重置');
        this.isDetecting = false;
      }
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

    // 设置超时保护，防止检测卡住
    this.detectionTimeout = setTimeout(() => {
      if (this.isDetecting) {
        console.error('[事件驱动] 检测超时，强制重置检测状态');
        this.isDetecting = false;
        this.pendingEvents = 0;
        if (this.detectionTimeout) {
          clearTimeout(this.detectionTimeout);
          this.detectionTimeout = null;
        }
      }
    }, this.maxDetectionTime);

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
      // 清除超时定时器
      if (this.detectionTimeout) {
        clearTimeout(this.detectionTimeout);
        this.detectionTimeout = null;
      }

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
            // 确保即使出错也重置状态
            this.isDetecting = false;
            if (this.detectionTimeout) {
              clearTimeout(this.detectionTimeout);
              this.detectionTimeout = null;
            }
          });
        }, 200);
      }
    }
  }

  /**
   * 启动健康检查（定期检查 fswatch 进程是否还在运行）
   */
  private startHealthCheck(): void {
    // 每30秒检查一次进程健康状态
    this.healthCheckInterval = setInterval(() => {
      if (!this.isRunning) {
        if (this.healthCheckInterval) {
          clearInterval(this.healthCheckInterval);
          this.healthCheckInterval = null;
        }
        return;
      }

      // 检查进程是否还在运行
      if (!this.fswatchProcess || this.fswatchProcess.killed) {
        console.warn('[事件驱动] 健康检查：fswatch 进程已停止，尝试重启');
        if (this.isRunning && this.restartAttempts < this.maxRestartAttempts) {
          this.restartFswatch();
        }
      } else {
        // 进程正常，重置重启计数
        if (this.restartAttempts > 0) {
          console.log('[事件驱动] 健康检查：进程正常，重置重启计数');
          this.restartAttempts = 0;
        }
      }

      // 检查检测状态是否卡住
      if (this.isDetecting && !this.detectionTimeout) {
        console.warn('[事件驱动] 健康检查：检测状态异常（isDetecting=true但没有超时定时器），强制重置');
        this.isDetecting = false;
        this.pendingEvents = 0;
      }
    }, 30000); // 每30秒检查一次
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

    if (this.detectionTimeout) {
      clearTimeout(this.detectionTimeout);
      this.detectionTimeout = null;
    }

    if (this.healthCheckInterval) {
      clearInterval(this.healthCheckInterval);
      this.healthCheckInterval = null;
    }

    this.onChangeCallback = undefined;
    this.restartAttempts = 0;
    this.isDetecting = false;
    this.pendingEvents = 0;

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
