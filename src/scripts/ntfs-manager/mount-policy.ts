import * as path from 'path';
import type { NTFSDevice } from '../../types/electron';

export interface MountIdentity { uid: number; gid: number; }

interface IdentitySource {
  getuid?: () => number;
  getgid?: () => number;
  geteuid?: () => number;
  getegid?: () => number;
}

function validId(value: number): boolean {
  return Number.isInteger(value) && value >= 0 && value < 0xffffffff;
}

// Read the GUI process identity before sudo. Environment variables such as
// SUDO_UID are not a reliable substitute for the initiating ordinary user.
export function currentMountIdentity(source: IdentitySource = process): MountIdentity {
  if (!source.getuid || !source.getgid || !source.geteuid || !source.getegid) {
    throw new Error('无法读取当前用户身份；请在 macOS 普通用户会话中启动 Nigate');
  }
  const uid = source.getuid();
  const gid = source.getgid();
  if (!validId(uid) || uid === 0 || !validId(gid) || source.geteuid() !== uid || source.getegid() !== gid) {
    throw new Error('请以普通用户启动 Nigate，不要使用 sudo/root 启动整个应用');
  }
  return { uid, gid };
}

export function validateDevicePath(devicePath: string): void {
  if (typeof devicePath !== 'string' || !/^\/dev\/disk\d+(?:s\d+)*$/.test(devicePath)) {
    throw new Error('无效的磁盘设备路径');
  }
}

export function validateMountTarget(device: Pick<NTFSDevice, 'disk' | 'devicePath' | 'volume' | 'volumeName'>): void {
  validateDevicePath(device.devicePath);
  if (device.devicePath !== `/dev/${device.disk}`) throw new Error('磁盘标识与设备路径不一致');
  if (typeof device.volume !== 'string' || path.posix.dirname(device.volume) !== '/Volumes' ||
      path.posix.normalize(device.volume) !== device.volume || /[\x00-\x1f\x7f]/.test(device.volume)) {
    throw new Error('挂载点必须是 /Volumes 下的独立目录');
  }
  if (typeof device.volumeName !== 'string' || !device.volumeName || /[,\x00-\x1f\x7f]/.test(device.volumeName)) {
    throw new Error('卷名不能包含逗号或控制字符（会改变挂载选项）');
  }
}

export function buildMountArgs(driver: string, device: NTFSDevice, identity: MountIdentity): string[] {
  validateMountTarget(device);
  if (!path.isAbsolute(driver) || /[\x00-\x1f\x7f]/.test(driver)) throw new Error('无效的 ntfs-3g 路径');
  if (!validId(identity.uid) || identity.uid === 0 || !validId(identity.gid)) throw new Error('无效的挂载用户身份');
  return [
    driver, '-olocal', '-oallow_other', '-oauto_xattr', `-ovolname=${device.volumeName}`,
    '-onoatime', '-onorecover', `-ouid=${identity.uid}`, `-ogid=${identity.gid}`,
    device.devicePath, device.volume
  ];
}

/**
 * Build the one explicit recovery retry that may remove Windows' hibernation
 * state. This function is only called after the user confirms the warning.
 */
export function buildHibernationRemovalArgs(normalArgs: string[]): string[] {
  if (!normalArgs.includes('-onorecover') || normalArgs.includes('-oremove_hiberfile')) {
    throw new Error('休眠状态恢复参数不符合预期');
  }
  const deviceIndex = normalArgs.findIndex(arg => /^\/dev\/disk\d+(?:s\d+)*$/.test(arg));
  if (deviceIndex < 0) throw new Error('休眠状态恢复参数缺少设备路径');
  return [
    ...normalArgs.slice(0, deviceIndex).filter(arg => arg !== '-onorecover'),
    '-oremove_hiberfile',
    ...normalArgs.slice(deviceIndex)
  ];
}
