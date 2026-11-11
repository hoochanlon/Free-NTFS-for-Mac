import Foundation

/// 一条内核挂载记录的纯值表示。
///
/// 设计约束：这是"卷已挂载"这一事实的唯一载体。只读状态、挂载点、
/// 驱动名都必须从这里取，不允许由 `diskutil` 的探测结果反推。
struct MountedVolume: Sendable, Equatable {
    /// 设备节点，例如 `/dev/disk4s1`
    let devicePath: String
    /// 挂载点，例如 `/Volumes/Samsung USB`
    let mountPoint: String
    /// 内核报告的挂载类型，例如 `macfuse` / `xntfs` / `msdos`
    let driver: String
    /// 展开后的挂载选项
    let options: [String]

    /// 只读与否只看内核挂载选项。探测接口报什么都不能改变这个结论。
    var isReadOnly: Bool { options.contains("read-only") }

    var isFUSE: Bool { driver.lowercased().contains("fuse") }

    var volumeName: String {
        mountPoint.hasPrefix("/Volumes/")
            ? String(mountPoint.dropFirst("/Volumes/".count))
            : mountPoint
    }

    var disk: String { devicePath.replacingOccurrences(of: "/dev/", with: "") }
}

/// `/sbin/mount` 输出的解析器。
///
/// 行格式固定为：`<device> on <mountPoint> (<opt>, <opt>, ...)`。
/// 解析不出设备与挂载点的对应关系时直接丢弃，不做猜测。
enum MountTable {
    static func parse(_ output: String) -> [MountedVolume] {
        output.split(whereSeparator: \.isNewline).compactMap { parseLine(String($0)) }
    }

    static func parseLine(_ line: String) -> MountedVolume? {
        guard let on = line.range(of: " on ") else { return nil }
        let devicePath = String(line[..<on.lowerBound]).trimmingCharacters(in: .whitespaces)
        guard devicePath.hasPrefix("/dev/") else { return nil }

        let rest = String(line[on.upperBound...]).trimmingCharacters(in: .whitespaces)
        // 选项组恒在行尾；卷名里出现的括号不会在行尾。
        guard let open = rest.range(of: " (", options: .backwards),
              rest.hasSuffix(")") else { return nil }

        let mountPoint = String(rest[..<open.lowerBound]).trimmingCharacters(in: .whitespaces)
        guard mountPoint.hasPrefix("/Volumes/"), mountPoint != "/Volumes/" else { return nil }

        let rawOptions = rest[open.upperBound..<rest.index(before: rest.endIndex)]
        let options = rawOptions
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
        guard let driver = options.first else { return nil }

        return MountedVolume(
            devicePath: devicePath,
            mountPoint: mountPoint,
            driver: driver,
            options: options
        )
    }
}
