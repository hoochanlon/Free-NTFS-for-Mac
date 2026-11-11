import Foundation
import Darwin

enum DiskSafety {
    static func isPartition(_ path: String) -> Bool {
        path.range(of: #"^/dev/disk\d+s\d+$"#, options: .regularExpression) != nil
    }

    static func isWholeDisk(_ path: String) -> Bool {
        path.range(of: #"^/dev/disk\d+$"#, options: .regularExpression) != nil
    }

    static func isNTFSFilesystem(_ description: String) -> Bool {
        let patterns = [
            #"(?im)^\s*(?:File System Personality|File System Type|Type \(Bundle\)|Partition Type|Format|格式):\s*(?:(?:xntfs|ntfs(?:-[\w-]+)?|windows_ntfs)\b|(?:Unknown|未知)\s+\((?:xntfs|ntfs(?:-[\w-]+)?|windows_ntfs)\))\s*$"#,
            #"(?im)^\s*\d+:\s*(?:xntfs|ntfs(?:-[\w-]+)?|windows_ntfs)\b"#,
            #"(?im)^/dev/disk\d+s\d+\s+on\s+/Volumes/.*\s+\((?:xntfs|ntfs(?:-[\w-]+)?|windows_ntfs)\b[^)]*\)\s*$"#
        ]
        return patterns.contains { pattern in
            description.range(of: pattern, options: .regularExpression) != nil
        }
    }

    static func isMountedXNTFSFilesystem(_ mountOutput: String, devicePath: String, mountPoint: String) -> Bool {
        guard isPartition(devicePath),
              mountPoint.hasPrefix("/Volumes/"),
              mountPoint != "/Volumes/" else { return false }
        let device = NSRegularExpression.escapedPattern(for: devicePath)
        let volume = NSRegularExpression.escapedPattern(for: mountPoint)
        let pattern = #"(?im)^"# + device + #"[ \t]+on[ \t]+"# + volume
            + #"[ \t]+\([ \t]*xntfs(?:,[ \t]*[^)]*)?\)[ \t]*$"#
        return mountOutput.range(of: pattern, options: .regularExpression) != nil
    }

    static func parentDiskPath(_ devicePath: String) -> String {
        String(devicePath.replacingOccurrences(of: #"s\d+$"#, with: "", options: .regularExpression))
    }

    static func parentDiskId(_ diskOrPath: String) -> String {
        diskOrPath
            .replacingOccurrences(of: "^/dev/", with: "", options: .regularExpression)
            .replacingOccurrences(of: #"s\d+$"#, with: "", options: .regularExpression)
    }

    static func partitionIndex(_ disk: String) -> String? {
        guard let match = disk.range(of: #"s(\d+)$"#, options: .regularExpression) else { return nil }
        return String(disk[match].dropFirst())
    }

    static func canFormat(fromListTags tags: String?) -> Bool {
        guard let tags else { return false }
        let normalized = tags.lowercased()
        let tokens = Set(normalized.split { !$0.isLetter && !$0.isNumber }.map(String.init))
        let blocked = ["internal", "virtual", "synthesized", "image", "unknown"]
        let negative = ["not", "non", "no", "false"]
        guard tokens.contains("external"), tokens.contains("physical") else { return false }
        guard negative.allSatisfy({ !tokens.contains($0) }) else { return false }
        return blocked.allSatisfy { !tokens.contains($0) }
    }

    static func parentDiskTags(from listOutput: String) -> [String: String] {
        var tags: [String: String] = [:]
        for line in listOutput.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            guard let match = line.range(of: #"^/dev/(disk\d+)\s*\(([^)]*)\)"#, options: .regularExpression) else { continue }
            let body = String(line[match])
            if let disk = body.split(separator: " ").first?.replacingOccurrences(of: "/dev/", with: ""),
               let open = body.firstIndex(of: "("),
               let close = body.firstIndex(of: ")") {
                tags[disk] = String(body[body.index(after: open)..<close])
            }
        }
        return tags
    }

    static func dataPartition(fromListOutput listOutput: String, parent: String) -> String? {
        guard isWholeDisk(parent),
              canFormat(fromListTags: parentDiskTags(from: listOutput)[parentDiskId(parent)]) else { return nil }
        return listOutput.split(whereSeparator: \.isNewline).map(String.init).reversed().first { line in
            guard line.range(
                of: #"\b(Microsoft Basic Data|ExFAT|Windows_NTFS|x?NTFS)\b"#,
                options: [.regularExpression, .caseInsensitive]
            ) != nil,
                  let match = line.range(of: #"disk\d+s\d+"#, options: .regularExpression) else { return false }
            return parentDiskPath("/dev/\(line[match])") == parent
        }.flatMap { line in
            guard let match = line.range(of: #"disk\d+s\d+"#, options: .regularExpression) else { return nil }
            return "/dev/\(line[match])"
        }
    }

    static func isSafeMountPoint(_ path: String) -> Bool {
        guard path.hasPrefix("/Volumes/"),
              path != "/Volumes/",
              !path.contains("\0"),
              !path.contains("//") else { return false }
        let name = String(path.dropFirst("/Volumes/".count))
        guard !name.isEmpty, !name.contains("/") else { return false }
        guard URL(fileURLWithPath: path).standardizedFileURL.path == path else { return false }
        return !containsSymlink(at: "/Volumes") && !containsSymlink(at: path)
    }

    static func sanitizeVolumeName(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: #"[\\/:*?"<>|]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty || cleaned == "." || cleaned == ".." || cleaned.rangeOfCharacter(from: .controlCharacters) != nil {
            return "NTFS"
        }
        return String(cleaned.prefix(32))
    }

    static func field(_ info: String, _ name: String) -> String? {
        let pattern = #"^\s*"# + NSRegularExpression.escapedPattern(for: name) + #":\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines, .caseInsensitive]) else {
            return nil
        }
        let range = NSRange(info.startIndex..., in: info)
        guard let match = regex.firstMatch(in: info, range: range),
              let value = Range(match.range(at: 1), in: info) else { return nil }
        return String(info[value]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isExternalFormattable(parentInfo: String, bootWholeDiskId: String, parentDiskId: String) -> Bool {
        guard !parentDiskId.isEmpty,
              !bootWholeDiskId.isEmpty,
              parentDiskId != bootWholeDiskId,
              isWholeDisk("/dev/\(parentDiskId)") else { return false }
        guard let identifier = field(parentInfo, "Device Identifier"),
              DiskSafety.parentDiskId(identifier) == parentDiskId,
              field(parentInfo, "Whole")?.caseInsensitiveCompare("Yes") == .orderedSame,
              field(parentInfo, "Internal")?.caseInsensitiveCompare("No") == .orderedSame,
              field(parentInfo, "Device Location")?.caseInsensitiveCompare("External") == .orderedSame,
              field(parentInfo, "Virtual")?.caseInsensitiveCompare("No") == .orderedSame,
              let protocolName = field(parentInfo, "Protocol"),
              !protocolName.isEmpty else { return false }
        return !protocolName.localizedCaseInsensitiveContains("disk image")
            && !protocolName.localizedCaseInsensitiveContains("synthesized")
            && !protocolName.localizedCaseInsensitiveContains("unknown")
    }

    private static func containsSymlink(at path: String) -> Bool {
        var info = stat()
        guard lstat(path, &info) == 0 else { return errno != ENOENT }
        return (info.st_mode & S_IFMT) == S_IFLNK
    }
}
