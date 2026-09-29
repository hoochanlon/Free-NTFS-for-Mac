import { execFile } from 'child_process';
import { promisify } from 'util';
import type { NTFSDevice } from '../../types/electron';
import { validateDevicePath } from './mount-policy';

const execFileAsync = promisify(execFile);

export interface MountEntry {
  devicePath: string;
  volume: string;
  options: string;
  isReadOnly: boolean;
  isFuse: boolean;
}

export interface DiskInfo {
  DeviceNode: string;
  FilesystemType: string;
  VolumeUUID?: string;
  DiskUUID?: string;
  Size?: number;
  MountPoint?: string;
  WritableMedia?: boolean;
  WritableVolume?: boolean;
}

export interface MountSnapshot { info: DiskInfo; entry?: MountEntry; }
export type MountMode = 'readWrite' | 'readOnly' | 'unmounted';

export function parseMountTable(output: string): MountEntry[] {
  return output.split('\n').flatMap(line => {
    // Capture up to the final option block: volume names may contain spaces,
    // parentheses, or even the words " on ". Match the device exactly.
    const match = line.match(/^(\/dev\/disk\d+(?:s\d+)*) on (.+) \(([^\n]*)\)$/);
    if (!match) return [];
    const tokens = match[3].split(',').map(option => option.trim().toLowerCase());
    return [{
      devicePath: match[1], volume: match[2], options: match[3],
      isReadOnly: tokens.includes('read-only') || tokens.includes('ro'),
      isFuse: tokens.some(option => ['macfuse', 'osxfuse', 'fusefs', 'fuse', 'ntfs-3g'].includes(option))
    }];
  });
}

export async function readMountTable(timeoutMs: number = 3000): Promise<MountEntry[]> {
  const { stdout } = await execFileAsync('/sbin/mount', [], { encoding: 'utf8', timeout: timeoutMs });
  return parseMountTable(stdout);
}

export async function readDiskInfo(devicePath: string, timeoutMs: number = 10000): Promise<DiskInfo> {
  validateDevicePath(devicePath);
  const deadline = Date.now() + timeoutMs;
  const { stdout: plist } = await execFileAsync('/usr/sbin/diskutil', ['info', '-plist', devicePath], { encoding: 'utf8', timeout: timeoutMs });
  // Use macOS's plist parser, with stdin instead of a shell pipeline or a
  // temporary file. No user-supplied string is evaluated as shell code.
  const json = await new Promise<string>((resolve, reject) => {
    const remainingMs = Math.max(1, Math.min(3000, deadline - Date.now()));
    const child = execFile('/usr/bin/plutil', ['-convert', 'json', '-o', '-', '--', '-'], { encoding: 'utf8', timeout: remainingMs }, (error, stdout) => {
      if (error) reject(error);
      else resolve(stdout);
    });
    child.stdin?.on('error', reject);
    child.stdin?.end(plist);
  });
  return JSON.parse(json) as DiskInfo;
}

export async function readMountSnapshot(devicePath: string, timeoutMs: number = 10000): Promise<MountSnapshot> {
  const [info, entries] = await Promise.all([readDiskInfo(devicePath, timeoutMs), readMountTable(Math.min(3000, timeoutMs))]);
  return { info, entry: entries.find(entry => entry.devicePath === devicePath) };
}

export function assertDeviceIdentity(info: DiskInfo, device: NTFSDevice, baseline?: DiskInfo): void {
  if (info.DeviceNode !== device.devicePath || info.FilesystemType?.toLowerCase() !== 'ntfs') {
    throw new Error('设备已变化或不是 NTFS；已停止操作');
  }
  const uuids = [info.VolumeUUID, info.DiskUUID].filter(Boolean).map(uuid => uuid!.toUpperCase());
  if (!uuids.length || (device.volumeUuid && !uuids.includes(device.volumeUuid.toUpperCase()))) {
    throw new Error('无法确认卷 UUID 或卷 UUID 已变化；请刷新设备列表');
  }
  if (baseline) {
    for (const key of ['VolumeUUID', 'DiskUUID'] as const) {
      if (baseline[key] && info[key]?.toUpperCase() !== baseline[key]!.toUpperCase()) {
        throw new Error(`设备身份已变化：${key}`);
      }
    }
    // TotalSize is filesystem-dependent and changes after unmounting. Size
    // describes the physical partition and is the stable comparison field.
    if (baseline.Size !== undefined && info.Size !== baseline.Size) throw new Error('分区容量已变化');
  }
}

export function assertMountState(snapshot: MountSnapshot, device: NTFSDevice, baseline: DiskInfo, mode: MountMode): void {
  assertDeviceIdentity(snapshot.info, device, baseline);
  const { entry, info } = snapshot;
  if (mode === 'unmounted') {
    if (entry || info.MountPoint) throw new Error('设备仍在挂载，不能继续');
    return;
  }
  if (!entry || entry.devicePath !== device.devicePath || entry.volume !== device.volume || info.MountPoint !== device.volume) {
    throw new Error('实际挂载点与预期不一致');
  }
  if (mode === 'readWrite' && (!entry.isFuse || entry.isReadOnly || info.WritableVolume !== true || info.WritableMedia === false)) {
    throw new Error('尚未确认 NTFS/FUSE 读写挂载');
  }
  if (mode === 'readOnly' && (!entry.isReadOnly || info.WritableVolume !== false)) {
    throw new Error('尚未确认只读挂载');
  }
}

export async function waitForMountState(
  device: NTFSDevice, baseline: DiskInfo, mode: MountMode,
  options: { timeoutMs?: number; intervalMs?: number; read?: typeof readMountSnapshot } = {}
): Promise<MountSnapshot> {
  const deadline = Date.now() + (options.timeoutMs ?? 30000);
  const read = options.read ?? readMountSnapshot;
  let consecutive = 0;
  let lastError = '未观察到稳定状态';
  do {
    try {
      const remainingMs = Math.max(1, Math.min(10000, deadline - Date.now()));
      const snapshot = await read(device.devicePath, remainingMs);
      assertMountState(snapshot, device, baseline, mode);
      if (++consecutive >= 2) return snapshot;
    } catch (error) {
      consecutive = 0;
      lastError = error instanceof Error ? error.message : String(error);
    }
    if (Date.now() >= deadline) break;
    await new Promise(resolve => setTimeout(resolve, options.intervalMs ?? 250));
  } while (Date.now() <= deadline);
  throw new Error(`挂载状态校验未通过（${mode}）：${lastError}`);
}
