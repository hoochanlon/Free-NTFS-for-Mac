// GUI mount service: privileged commands use SudoExecutor, while verification
// always runs as the initiating ordinary user.
import * as fs from 'fs/promises';
import { execFile } from 'child_process';
import { promisify } from 'util';
import type { NTFSDevice } from '../../types/electron';
import type { PasswordManager } from './password-manager';
import type { SudoExecutor } from './sudo-executor';
import { buildHibernationRemovalArgs, buildMountArgs, currentMountIdentity, validateMountTarget } from './mount-policy';
import { assertDeviceIdentity, assertMountState, readMountSnapshot, readMountTable, waitForMountState } from './mount-state';
import type { DiskInfo, MountSnapshot } from './mount-state';
import { verifyFileWrites } from './write-verifier';

const execFileAsync = promisify(execFile);
type Authentication = { password: string };
type HibernationConfirmation = (device: NTFSDevice, errorMessage: string) => Promise<boolean>;

function isHibernationStateError(message: string): boolean {
  return /hibernat|hiberfile|unclean|unsafe state|fast startup|fast restart|volume is dirty|ntfs.*inconsisten/i.test(message);
}

export class MountOperations {
  private activeDevices = new Set<string>();

  constructor(
    private mountedDevices: Set<string>,
    private unmountedDevices: Map<string, NTFSDevice>,
    private passwordManager: PasswordManager,
    private sudoExecutor: SudoExecutor,
    private getNTFS3GPath: () => Promise<string | null>,
    private runSystemCommand: (file: string, args: string[]) => Promise<unknown> =
      (file, args) => execFileAsync(file, args, { timeout: 30000 }),
    private confirmHibernationRemoval: HibernationConfirmation = async () => false
  ) {}

  private async exclusive(device: NTFSDevice, operation: (target: NTFSDevice) => Promise<string>): Promise<string> {
    const target = { ...device, volume: device.volume || '/Volumes/' + device.volumeName };
    validateMountTarget(target);
    if (this.activeDevices.has(target.disk)) throw new Error('该设备正在执行其他操作，请稍后刷新重试');
    this.activeDevices.add(target.disk);
    try {
      return await operation(target);
    } finally {
      this.activeDevices.delete(target.disk);
    }
  }

  private async initialState(device: NTFSDevice): Promise<MountSnapshot> {
    const snapshot = await readMountSnapshot(device.devicePath);
    assertDeviceIdentity(snapshot.info, device);
    if (snapshot.entry && snapshot.entry.volume !== device.volume) throw new Error('设备挂载点已变化，请刷新设备列表');
    return snapshot;
  }

  private async authenticate(device: NTFSDevice, prompt: string): Promise<Authentication> {
    return { password: await this.passwordManager.getPassword(prompt, { name: device.volumeName }) };
  }

  private async sudo(args: string[], auth: Authentication, device: NTFSDevice, prompt: string): Promise<void> {
    try {
      await this.sudoExecutor.executeSudoWithPassword(args, auth.password);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      if (!/密码错误|密码不能为空|password is incorrect|Sorry, try again/i.test(message)) throw error;
      auth.password = await this.passwordManager.getPassword(prompt, { name: device.volumeName });
      await this.sudoExecutor.executeSudoWithPassword(args, auth.password);
    }
  }

  private async clearManaged(device: NTFSDevice): Promise<void> {
    this.mountedDevices.delete(device.disk);
    await fs.unlink('/tmp/ntfs_mounted_' + device.disk).catch(() => {});
  }

  private async markVerified(device: NTFSDevice): Promise<void> {
    this.mountedDevices.add(device.disk);
    this.unmountedDevices.delete(device.disk);
    // Never follow a marker symlink or truncate another user's file.
    await fs.writeFile('/tmp/ntfs_mounted_' + device.disk, '', { flag: 'wx', mode: 0o600 }).catch(() => {});
  }

  private async unmountNormally(device: NTFSDevice, baseline: DiskInfo, auth: Authentication): Promise<void> {
    const snapshot = await readMountSnapshot(device.devicePath);
    assertDeviceIdentity(snapshot.info, device, baseline);
    if (snapshot.entry) {
      if (snapshot.entry.volume !== device.volume) throw new Error('挂载点已变化，已停止卸载');
      // Busy volumes must fail here. Never force unmount or ignore errors.
      await this.sudo(['/usr/sbin/diskutil', 'unmount', device.devicePath], auth, device, 'messages.passwordDialog.unmountDevice');
    }
    await waitForMountState(device, baseline, 'unmounted');
    await this.clearManaged(device);
    this.unmountedDevices.set(device.disk, { ...device, isMounted: false, isUnmounted: true });
  }

  private async systemReadOnly(device: NTFSDevice, baseline: DiskInfo, auth: Authentication): Promise<void> {
    const snapshot = await readMountSnapshot(device.devicePath);
    assertDeviceIdentity(snapshot.info, device, baseline);
    if (snapshot.entry) {
      assertMountState(snapshot, device, baseline, 'readOnly');
    } else {
      await this.prepareMountPoint(device, auth);
      await this.runSystemCommand('/usr/sbin/diskutil', ['mount', 'readOnly', '-mountPoint', device.volume, device.devicePath]);
    }
    await waitForMountState(device, baseline, 'readOnly');
    await this.clearManaged(device);
    this.unmountedDevices.delete(device.disk);
  }

  private async prepareMountPoint(device: NTFSDevice, auth: Authentication): Promise<void> {
    const inspect = async () => {
      try {
        const stat = await fs.lstat(device.volume);
        if (!stat.isDirectory() || stat.isSymbolicLink()) throw new Error('挂载点不是普通目录');
        if ((await fs.readdir(device.volume)).length) throw new Error('挂载点目录非空，已停止挂载');
        return true;
      } catch (error: any) {
        if (error.code === 'ENOENT') return false;
        throw error;
      }
    };
    if (!await inspect()) {
      await this.sudo(['/bin/mkdir', '-p', device.volume], auth, device, 'messages.passwordDialog.mountDevice');
      if (!await inspect()) throw new Error('无法创建挂载点');
    }
  }

  async mountDevice(device: NTFSDevice): Promise<string> {
    return this.exclusive(device, async target => {
      const identity = currentMountIdentity(); // before sudo, on every invocation
      const ntfs3gPath = await this.getNTFS3GPath();
      if (!ntfs3gPath) throw new Error('未找到 ntfs-3g，请先安装依赖');
      let fullPath = ntfs3gPath;
      try {
        await fs.access(fullPath);
      } catch {
        fullPath = '/System/Volumes/Data' + ntfs3gPath;
        await fs.access(fullPath).catch(() => { throw new Error('ntfs-3g 路径不存在: ' + ntfs3gPath); });
      }
      const mountArgs = buildMountArgs(fullPath, target, identity);
      const initial = await this.initialState(target);
      const baseline = initial.info;
      if (baseline.WritableMedia === false) throw new Error('设备介质为只读，不能挂载为读写');

      if (this.mountedDevices.has(target.disk) && initial.entry?.isFuse && !initial.entry.isReadOnly) {
        const owner = await fs.lstat(target.volume);
        if (!owner.isSymbolicLink() && owner.uid === identity.uid && owner.gid === identity.gid) {
          assertMountState(initial, target, baseline, 'readWrite');
          await verifyFileWrites(target.volume, identity);
          assertMountState(await readMountSnapshot(target.devicePath), target, baseline, 'readWrite');
          return '设备 ' + target.volumeName + ' 已是读写模式，文件读写自检通过';
        }
        // Old root-owned GUI mounts must use the normal remount flow.
      }

      const auth = await this.authenticate(target, 'messages.passwordDialog.mountDevice');
      let changedMount = false;
      try {
        await this.unmountNormally(target, baseline, auth);
        changedMount = true;
        await this.prepareMountPoint(target, auth);
        assertMountState(await readMountSnapshot(target.devicePath), target, baseline, 'unmounted');
        await this.sudo(mountArgs, auth, target, 'messages.passwordDialog.mountDeviceRetry');
        await waitForMountState(target, baseline, 'readWrite');
        await verifyFileWrites(target.volume, identity);
        assertMountState(await readMountSnapshot(target.devicePath), target, baseline, 'readWrite');
        await this.markVerified(target);
        return '设备 ' + target.volumeName + ' 已成功挂载为读写模式，文件读写自检通过';
      } catch (error) {
        const firstMessage = error instanceof Error ? error.message : String(error);
        let message = firstMessage;
        let retainedHibernation = false;
        let removalConfirmed = false;

        if (changedMount && isHibernationStateError(firstMessage)) {
          removalConfirmed = await this.confirmHibernationRemoval(target, firstMessage).catch(() => false);
          if (!removalConfirmed) {
            retainedHibernation = true;
          } else {
            try {
              // The first attempt has failed. Establish a clean unmounted
              // state before the explicitly confirmed recovery retry.
              await this.unmountNormally(target, baseline, auth);
              await this.prepareMountPoint(target, auth);
              assertMountState(await readMountSnapshot(target.devicePath), target, baseline, 'unmounted');
              await this.sudo(buildHibernationRemovalArgs(mountArgs), auth, target, 'messages.passwordDialog.mountDeviceRetry');
              await waitForMountState(target, baseline, 'readWrite');
              await verifyFileWrites(target.volume, identity);
              assertMountState(await readMountSnapshot(target.devicePath), target, baseline, 'readWrite');
              await this.markVerified(target);
              return '设备 ' + target.volumeName + ' 已按你的选择删除 Windows 休眠状态并挂载为读写模式，文件读写自检通过';
            } catch (retryError) {
              message = retryError instanceof Error ? retryError.message : String(retryError);
            }
          }
        }

        // Timeout is not proof that a privileged child stopped. Do not race
        // it with another mount or falsely report successful cancellation.
        if (/超时|timed? ?out|timeout/i.test(message)) {
          throw new Error('挂载等待超时，实际状态尚未确认；请刷新设备列表后再操作。' + message);
        }
        let recovery = '';
        if (changedMount) {
          try {
            await this.unmountNormally(target, baseline, auth);
            await this.systemReadOnly(target, baseline, auth);
            recovery = '；已验证恢复为只读模式';
          } catch (recoveryError) {
            recovery = '；恢复只读未完成，请刷新确认设备状态：' + String(recoveryError);
          }
        }
        const windowsHint = retainedHibernation
          ? '；已保留 Windows 休眠状态，未删除；当前未继续读写挂载。请在 Windows 中完全关机后再试'
          : isHibernationStateError(firstMessage) && !removalConfirmed
            ? '；请在 Windows 中完全关机后再试，未自动删除休眠文件或修复卷'
            : isHibernationStateError(firstMessage)
              ? '；已尝试按你的选择删除 Windows 休眠状态，但读写挂载仍未通过；请刷新设备状态并检查卷'
              : '';
        throw new Error('挂载失败：' + message + windowsHint + recovery);
      }
    });
  }

  async unmountDevice(device: NTFSDevice): Promise<string> {
    return this.exclusive(device, async target => {
      const { info } = await this.initialState(target);
      const auth = await this.authenticate(target, 'messages.passwordDialog.unmountDevice');
      await this.unmountNormally(target, info, auth);
      return '设备 ' + target.volumeName + ' 已卸载';
    });
  }

  async unmountWithDiskutil(device: NTFSDevice): Promise<string> {
    return this.exclusive(device, async target => {
      const { info, entry } = await this.initialState(target);
      if (entry) await this.runSystemCommand('/usr/sbin/diskutil', ['unmount', target.devicePath]);
      await waitForMountState(target, info, 'unmounted');
      await this.clearManaged(target);
      this.unmountedDevices.set(target.disk, { ...target, isMounted: false, isUnmounted: true });
      return '设备 ' + target.volumeName + ' 已卸载';
    });
  }

  async restoreToReadOnly(device: NTFSDevice): Promise<string> {
    return this.exclusive(device, async target => {
      const initial = await this.initialState(target);
      if (initial.entry?.isReadOnly && initial.info.WritableVolume === false) {
        await waitForMountState(target, initial.info, 'readOnly');
        await this.clearManaged(target);
        this.unmountedDevices.delete(target.disk);
        return '设备 ' + target.volumeName + ' 已是只读模式';
      }
      const auth = await this.authenticate(target, 'messages.passwordDialog.restoreToReadOnly');
      await this.unmountNormally(target, initial.info, auth);
      await this.systemReadOnly(target, initial.info, auth);
      return '设备 ' + target.volumeName + ' 已还原为只读模式';
    });
  }

  async ejectDevice(device: NTFSDevice): Promise<string> {
    return this.exclusive(device, async target => {
      await this.initialState(target);
      await this.runSystemCommand('/usr/sbin/diskutil', ['eject', target.devicePath]);
      if ((await readMountTable()).some(entry => entry.devicePath === target.devicePath)) {
        throw new Error('推出后仍检测到挂载，不能确认安全拔出');
      }
      await this.clearManaged(target);
      this.unmountedDevices.delete(target.disk);
      return '设备 ' + target.volumeName + ' 已推出，可以安全拔出';
    });
  }

  // Preserve the existing explicitly invoked repair action. Mounting and
  // fallback recovery never call resetDevice or automatically run ntfsfix.
  async resetDevice(device: NTFSDevice): Promise<string> {
    return this.exclusive(device, async target => {
      const { info } = await this.initialState(target);
      const auth = await this.authenticate(target, 'messages.passwordDialog.resetDevice');
      await this.unmountNormally(target, info, auth);
      await this.sudo(['ntfsfix', target.devicePath], auth, target, 'messages.passwordDialog.resetDevice');
      await this.systemReadOnly(target, info, auth);
      return '设备 ' + target.volumeName + ' 已重置并重新挂载为只读模式';
    });
  }

  async cleanupOldMounts(): Promise<void> {
    try {
      const entries = await readMountTable();
      for (const marker of await fs.readdir('/tmp')) {
        const match = marker.match(/^ntfs_mounted_(disk\d+(?:s\d+)*)$/);
        if (!match) continue;
        const disk = match[1];
        const entry = entries.find(item => item.devicePath === '/dev/' + disk);
        if (!entry?.isFuse || entry.isReadOnly) {
          await fs.unlink('/tmp/' + marker).catch(() => {});
          this.mountedDevices.delete(disk);
        }
      }
    } catch {
      // Failed inspection never establishes that a volume is writable.
    }
  }
}
