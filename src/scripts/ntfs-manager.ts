// NTFS Manager 主文件 - 整合各个模块
import { PathFinder } from './ntfs-manager/path-finder';
import { checkDependencies } from './ntfs-manager/dependencies';
import type { NTFSDevice } from '../types/electron';
import { DeviceDetector } from './ntfs-manager/device-detector';
import { PasswordManager } from './ntfs-manager/password-manager';
import { SudoExecutor } from './ntfs-manager/sudo-executor';
import { MountOperations } from './ntfs-manager/mount-operations';
import { HybridDetector } from './ntfs-manager/hybrid-detector';

class NTFSManager {
  private pathFinder: PathFinder;
  private mountedDevices: Set<string> = new Set();
  private unmountedDevices: Map<string, NTFSDevice> = new Map(); // 保存已卸载的设备信息
  private deviceDetector: DeviceDetector;
  private passwordManager: PasswordManager;
  private sudoExecutor: SudoExecutor;
  private mountOperations: MountOperations;
  private hybridDetector: HybridDetector | null = null;
  private deviceChangeCallbacks: Set<(devices: NTFSDevice[]) => void> = new Set();

  constructor() {
    this.pathFinder = new PathFinder();
    this.passwordManager = new PasswordManager();
    this.sudoExecutor = new SudoExecutor();
    this.deviceDetector = new DeviceDetector(this.mountedDevices, this.unmountedDevices);
    this.mountOperations = new MountOperations(
      this.mountedDevices,
      this.unmountedDevices,
      this.passwordManager,
      this.sudoExecutor,
      () => this.getNTFS3GPath()
    );

    // 初始化混合检测器（延迟初始化，在需要时启动）
    this.hybridDetector = new HybridDetector(this.deviceDetector);
  }

  // 检查依赖
  async checkDependencies() {
    return await checkDependencies();
  }

  // 获取 ntfs-3g 路径
  async getNTFS3GPath(): Promise<string | null> {
    return await this.pathFinder.getNTFS3GPath();
  }

  // 获取 NTFS 设备列表
  async getNTFSDevices(forceRefresh: boolean = false): Promise<NTFSDevice[]> {
    return await this.deviceDetector.getNTFSDevices(forceRefresh);
  }

  // 挂载设备
  async mountDevice(device: NTFSDevice): Promise<string> {
    return await this.mountOperations.mountDevice(device);
  }

  // 卸载设备
  async unmountDevice(device: NTFSDevice): Promise<string> {
    return await this.mountOperations.unmountDevice(device);
  }

  // 还原设备为只读模式
  async restoreToReadOnly(device: NTFSDevice): Promise<string> {
    return await this.mountOperations.restoreToReadOnly(device);
  }

  // 清理旧的挂载标记
  async cleanupOldMounts(): Promise<void> {
    return await this.mountOperations.cleanupOldMounts();
  }

  // 推出设备
  async ejectDevice(device: NTFSDevice): Promise<string> {
    return await this.mountOperations.ejectDevice(device);
  }

  // 启动混合检测（事件驱动 + 智能轮询备用）
  async startHybridDetection(callback: (devices: NTFSDevice[]) => void): Promise<void> {
    if (!this.hybridDetector) {
      this.hybridDetector = new HybridDetector(this.deviceDetector);
    }

    this.deviceChangeCallbacks.add(callback);

    await this.hybridDetector.initialize((devices) => {
      // 通知所有注册的回调
      this.deviceChangeCallbacks.forEach(cb => {
        try {
          cb(devices);
        } catch (error) {
          console.error('设备变化回调执行失败:', error);
        }
      });
    });
  }

  // 停止混合检测
  stopHybridDetection(): void {
    if (this.hybridDetector) {
      this.hybridDetector.stop();
    }
    this.deviceChangeCallbacks.clear();
  }

  // 移除设备变化回调
  removeDeviceChangeCallback(callback: (devices: NTFSDevice[]) => void): void {
    this.deviceChangeCallbacks.delete(callback);
  }

  // 更新窗口可见性（用于优化轮询频率）
  updateWindowVisibility(isVisible: boolean): void {
    if (this.hybridDetector) {
      this.hybridDetector.updateWindowVisibility(isVisible);
    }
  }

  // 获取检测模式（用于调试）
  getDetectionMode(): 'event-driven' | 'polling' | 'not-started' {
    if (!this.hybridDetector) {
      return 'not-started';
    }
    return this.hybridDetector.getMode();
  }

  // 获取检测状态（用于调试）
  getDetectionStatus() {
    if (!this.hybridDetector) {
      return null;
    }
    return this.hybridDetector.getStatus();
  }

  // 检查事件驱动是否可用
  async checkEventDrivenAvailable(): Promise<boolean> {
    if (!this.hybridDetector) {
      return false;
    }
    return await this.hybridDetector.checkEventDrivenAvailable();
  }
}

export default new NTFSManager();
