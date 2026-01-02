// NTFS Manager 主文件 - 整合各个模块
import { PathFinder } from './ntfs-manager/path-finder';
import { checkDependencies } from './ntfs-manager/dependencies';
import type { NTFSDevice } from '../types/electron';
import { DeviceDetector } from './ntfs-manager/device-detector';
import { PasswordManager } from './ntfs-manager/password-manager';
import { SudoExecutor } from './ntfs-manager/sudo-executor';
import { MountOperations } from './ntfs-manager/mount-operations';

class NTFSManager {
  private pathFinder: PathFinder;
  private mountedDevices: Set<string> = new Set();
  private unmountedDevices: Map<string, NTFSDevice> = new Map(); // 保存已卸载的设备信息
  private deviceDetector: DeviceDetector;
  private passwordManager: PasswordManager;
  private sudoExecutor: SudoExecutor;
  private mountOperations: MountOperations;

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
  async getNTFSDevices(): Promise<NTFSDevice[]> {
    return await this.deviceDetector.getNTFSDevices();
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
}

export default new NTFSManager();
