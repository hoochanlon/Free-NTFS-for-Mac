import Foundation

/// 容量真值跟分区走；df 只在挂载点已经是当前卷、且总量对得上时才采信。
/// 只读转读写会先留下空目录再挂 FUSE，这段窗口里 df 会落到宿主系统盘。
enum VolumeCapacity {
    struct DfRow: Equatable, Sendable {
        var filesystem: String
        var total: Int64
        var used: Int64
        var available: Int64
        var mountPoint: String
    }

    static func parseDf(_ stdout: String) -> DfRow? {
        let lines = stdout
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var pendingFilesystem: String?
        var rows: [DfRow] = []
        for line in lines {
            if line.lowercased().hasPrefix("filesystem") { continue }
            let tokens = line.split(whereSeparator: \.isWhitespace)
            if let first = tokens.first, Int64(first) != nil {
                let merged = pendingFilesystem.map { "\($0) \(line)" } ?? line
                pendingFilesystem = nil
                if let row = parseDfDataLine(merged) { rows.append(row) }
                continue
            }
            if let row = parseDfDataLine(line) {
                pendingFilesystem = nil
                rows.append(row)
                continue
            }
            pendingFilesystem = line
        }
        return rows.last
    }

    static func parseDiskutil(_ info: String) -> Capacity? {
        func bytes(_ label: String) -> Int64? {
            let pattern = label + #"\s*[\d.]+ [KMGT]?B\s*\((\d+)\s+Bytes\)"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
            let range = NSRange(info.startIndex..., in: info)
            guard let match = regex.firstMatch(in: info, range: range),
                  let capture = Range(match.range(at: 1), in: info) else { return nil }
            return Int64(info[capture])
        }
        guard let total = bytes("Total Size:") ?? bytes("Disk Size:") else { return nil }
        var used = bytes("Volume Used Space:") ?? 0
        var available = bytes("Volume Free Space:") ?? 0
        if available > 0 && used == 0 { used = total - available }
        if used > 0 && available == 0 { available = total - used }
        if used == 0 && available == 0 { available = total }
        return Capacity(total: total, used: max(0, used), available: max(0, available))
    }

    static func trustedDf(
        _ row: DfRow?,
        devicePath: String,
        volume: String,
        partitionTotal: Int64?
    ) -> Capacity? {
        guard let row, isTrusted(row, devicePath: devicePath, volume: volume, partitionTotal: partitionTotal) else {
            return nil
        }
        return Capacity(total: row.total, used: row.used, available: row.available)
    }

    static func resolve(df: Capacity?, partition: Capacity?, previous: Capacity?) -> Capacity? {
        let total = [partition?.total, df?.total, previous?.total]
            .compactMap { $0 }
            .first { $0 > 0 }
        guard let total else { return nil }

        let available: Int64
        if let df {
            available = clamp(df.available, to: total)
        } else if let previous, totalsAgree(previous.total, total) {
            available = clamp(previous.available, to: total)
        } else if let partition, hasMeasuredFree(partition) {
            available = clamp(partition.available, to: total)
        } else {
            available = total
        }
        return Capacity(total: total, used: max(0, total - available), available: available)
    }

    static func totalsAgree(_ a: Int64, _ b: Int64) -> Bool {
        let high = max(a, b)
        let low = min(a, b)
        guard low > 0, high > 0 else { return false }
        return high - low <= high / 4
    }

    private static func isTrusted(
        _ row: DfRow,
        devicePath: String,
        volume: String,
        partitionTotal: Int64?
    ) -> Bool {
        let volume = normalize(volume)
        guard !volume.isEmpty, normalize(row.mountPoint) == volume else { return false }
        if let reported = diskIdentity(row.filesystem),
           let expected = diskIdentity(devicePath),
           reported != expected {
            return false
        }
        if let partitionTotal, partitionTotal > 0 {
            return totalsAgree(row.total, partitionTotal)
        }
        return row.total > 0
    }

    private static func parseDfDataLine(_ line: String) -> DfRow? {
        let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count >= 6,
              let totalKB = Int64(parts[1]),
              let usedKB = Int64(parts[2]),
              let availableKB = Int64(parts[3]),
              totalKB > 0,
              parts[4].hasSuffix("%") else { return nil }
        let mountIndex: Int
        if parts.count >= 9, parts[7].hasSuffix("%") {
            mountIndex = 8
        } else {
            mountIndex = 5
        }
        guard parts.count > mountIndex else { return nil }
        return DfRow(
            filesystem: parts[0],
            total: totalKB * 1024,
            used: usedKB * 1024,
            available: availableKB * 1024,
            mountPoint: parts[mountIndex...].joined(separator: " ")
        )
    }

    private static func hasMeasuredFree(_ capacity: Capacity) -> Bool {
        capacity.used > 0 || (capacity.available > 0 && capacity.available != capacity.total)
    }

    private static func clamp(_ available: Int64, to total: Int64) -> Int64 {
        min(max(0, available), total)
    }

    private static func normalize(_ path: String) -> String {
        var path = path.trimmingCharacters(in: .whitespacesAndNewlines)
        while path.count > 1, path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }

    private static func diskIdentity(_ text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"disk\d+s\d+|disk\d+"#) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let captured = Range(match.range, in: text) else { return nil }
        return String(text[captured])
    }
}
