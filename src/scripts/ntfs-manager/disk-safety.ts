// 整盘格式化的路径与安全判断。
// 界面用 diskutil list 的磁盘标签做按钮显隐；真正执行前再用 diskutil info 拦一次。

export function isValidPartitionPath(devicePath: string): boolean {
  return /^\/dev\/disk\d+s\d+$/.test(devicePath);
}

export function isValidWholeDiskPath(devicePath: string): boolean {
  return /^\/dev\/disk\d+$/.test(devicePath);
}

export function getParentDiskPath(devicePath: string): string {
  return devicePath.replace(/s\d+$/, '');
}

export function getParentDiskId(diskOrPath: string): string {
  return diskOrPath.replace(/^\/dev\//, '').replace(/s\d+$/, '');
}

export function canFormatFromListTags(tags: string | undefined): boolean {
  // diskutil list 实际只 grep 了 NTFS 行，父盘标签经常不在。
  // 标签缺失时仍显示按钮；真正执行前用 diskutil info 再拦一次。
  if (!tags) return true;
  const normalized = tags.toLowerCase();
  if (
    normalized.includes('internal') ||
    normalized.includes('virtual') ||
    normalized.includes('disk image') ||
    normalized.includes('synthesized')
  ) {
    return false;
  }
  return true;
}

export function parseParentDiskTags(diskutilListOutput: string): Map<string, string> {
  const tags = new Map<string, string>();
  for (const line of diskutilListOutput.split('\n')) {
    const match = line.match(/^\/dev\/(disk\d+)\s*\(([^)]*)\)/);
    if (match) {
      tags.set(match[1], match[2]);
    }
  }
  return tags;
}

export function sanitizeNtfsVolumeName(name: string): string {
  const cleaned = String(name || '')
    .replace(/[\\/:*?"<>|]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  if (!cleaned) return 'NTFS';
  return cleaned.slice(0, 32);
}

export function parseDiskutilField(info: string, field: string): string | null {
  const match = info.match(new RegExp(`^\\s*${field}:\\s*(.+)$`, 'im'));
  return match ? match[1].trim() : null;
}

export function isExternalFormattableFromInfo(
  parentInfo: string,
  bootWholeDiskId: string,
  parentDiskId: string
): boolean {
  if (!parentDiskId || parentDiskId === bootWholeDiskId) {
    return false;
  }

  const whole = parseDiskutilField(parentInfo, 'Whole');
  if (whole && !/^yes$/i.test(whole)) {
    return false;
  }

  const internal = parseDiskutilField(parentInfo, 'Internal');
  const location = parseDiskutilField(parentInfo, 'Device Location');
  if (/^yes$/i.test(internal || '') || /^internal$/i.test(location || '')) {
    return false;
  }

  const virtual = parseDiskutilField(parentInfo, 'Virtual');
  if (/^yes$/i.test(virtual || '')) {
    return false;
  }

  const protocol = parseDiskutilField(parentInfo, 'Protocol') || '';
  if (/disk image/i.test(protocol)) {
    return false;
  }

  return true;
}
