import ntfsManager from '../ntfs-manager';
import type { NTFSDevice } from '../../types/electron';

/**
 * 等待设备状态更新（轮询直到状态改变或超时）
 * 对于 restoreToReadOnly 操作，需要更长的等待时间，因为系统需要重新挂载
 */
export async function waitForDeviceStatusUpdate(
  device: NTFSDevice,
  expectedReadOnly: boolean,
  maxWaitTime: number = 3000,
  pollInterval: number = 200
): Promise<boolean> {
  const startTime = Date.now();
  let lastStatus: boolean | null = null;
  let consecutiveMatches = 0; // 连续匹配次数，确保状态稳定
  const requiredMatches = 2; // 需要连续 2 次检测到正确状态才认为更新成功

  while (Date.now() - startTime < maxWaitTime) {
    try {
      // 强制刷新，确保获取最新状态
      const devices = await ntfsManager.getNTFSDevices(true);
      const updatedDevice = devices.find(d => d.disk === device.disk);

      if (updatedDevice) {
        // 记录当前状态
        const currentStatus = updatedDevice.isReadOnly;

        // 如果状态已经改变到期望值
        if (currentStatus === expectedReadOnly) {
          consecutiveMatches++;
          // 需要连续多次检测到正确状态，确保状态稳定
          if (consecutiveMatches >= requiredMatches) {
            console.log(`设备 ${device.volumeName} 状态已更新为 ${expectedReadOnly ? '只读' : '可读写'}`);
            return true; // 状态已更新且稳定
          }
        } else {
          // 状态不匹配，重置连续匹配计数
          consecutiveMatches = 0;
        }

        // 如果状态发生了变化（即使不是期望值），说明系统正在更新
        if (lastStatus !== null && lastStatus !== currentStatus) {
          // 状态正在变化，继续等待
          console.log(`设备 ${device.volumeName} 状态正在更新: ${lastStatus} -> ${currentStatus}`);
          consecutiveMatches = 0; // 状态变化时重置计数
        }

        lastStatus = currentStatus;
      } else {
        // 设备未找到，可能是正在卸载/重新挂载
        consecutiveMatches = 0;
      }

      await new Promise(resolve => setTimeout(resolve, pollInterval));
    } catch (error) {
      console.warn('轮询设备状态失败:', error);
      consecutiveMatches = 0;
      // 继续尝试，不立即退出
    }
  }

  // 如果超时，最后一次检查状态（多次检查确保准确性）
  for (let i = 0; i < 3; i++) {
    try {
      await new Promise(resolve => setTimeout(resolve, 200)); // 等待一小段时间
      // 强制刷新，确保获取最新状态
      const devices = await ntfsManager.getNTFSDevices(true);
      const updatedDevice = devices.find(d => d.disk === device.disk);
      if (updatedDevice && updatedDevice.isReadOnly === expectedReadOnly) {
        console.log(`设备 ${device.volumeName} 状态已更新为 ${expectedReadOnly ? '只读' : '可读写'}（超时后检测到）`);
        return true;
      }
    } catch (error) {
      console.warn('最后检查设备状态失败:', error);
    }
  }

  console.warn(`设备 ${device.volumeName} 状态更新超时，期望: ${expectedReadOnly ? '只读' : '可读写'}`);
  return false; // 超时或失败
}
