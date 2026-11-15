import Darwin
import Foundation

/// 直接读挂载点的 statfs。不走 diskutil，拷文件时也能跟上 Finder。
enum VolumeStat {
    static func capacity(volume: String, devicePath: String, previous: Capacity?) -> Capacity? {
        guard let row = row(at: volume) else { return nil }
        let partitionTotal = previous?.total
        let df = VolumeCapacity.trustedDf(
            row,
            devicePath: devicePath,
            volume: volume,
            partitionTotal: partitionTotal
        )
        let partition = partitionTotal.map { Capacity(total: $0, used: 0, available: $0) }
        let resolved = VolumeCapacity.resolve(df: df, partition: partition, previous: previous)
        guard let resolved, resolved != previous else { return nil }
        return resolved
    }

    private static func row(at path: String) -> VolumeCapacity.DfRow? {
        var stats = statfs()
        guard path.withCString({ statfs($0, &stats) }) == 0 else { return nil }
        let block = Int64(stats.f_bsize)
        guard block > 0, stats.f_blocks > 0 else { return nil }
        let total = Int64(stats.f_blocks) * block
        let available = Int64(stats.f_bavail) * block
        let used = max(0, total - Int64(stats.f_bfree) * block)
        return VolumeCapacity.DfRow(
            filesystem: cString(stats.f_mntfromname),
            total: total,
            used: used,
            available: available,
            mountPoint: cString(stats.f_mntonname)
        )
    }

    private static func cString<T>(_ tuple: T) -> String {
        withUnsafePointer(to: tuple) {
            $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<T>.size) {
                String(cString: $0)
            }
        }
    }
}
