import Foundation

/// 已挂载卷的占用样本。没有变化就返回 nil，避免整表重绘。
enum CapacityRefresh {
    static func applying(_ devices: [NTFSDevice], samples: [String: Capacity]) -> [NTFSDevice]? {
        guard !samples.isEmpty else { return nil }
        var changed = false
        let next = devices.map { device -> NTFSDevice in
            guard device.isMounted, !device.isUnmounted,
                  let capacity = samples[device.devicePath],
                  capacity != device.capacity else { return device }
            changed = true
            var copy = device
            copy.capacity = capacity
            return copy
        }
        return changed ? next : nil
    }
}
