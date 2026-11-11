import Foundation
import FSKit

#if canImport(NigateNTFSEngine)
import NigateNTFSEngine
#endif

@available(macOS 15.4, *)
final class NigateNTFSItem: FSItem {
    let mftNo: UInt64
    let parentMft: UInt64
    private(set) var cachedInfo: NigateNTFSItemInfo?

    init(mftNo: UInt64, parentMft: UInt64, info: NigateNTFSItemInfo? = nil) {
        self.mftNo = mftNo
        self.parentMft = parentMft
        self.cachedInfo = info
        super.init()
    }

    func refresh(using engine: OpaquePointer) throws -> NigateNTFSItemInfo {
        var info = NigateNTFSItemInfo()
        let rc = nigate_ntfs_item_info(engine, mftNo, &info)
        guard rc == 0 else {
            throw posixError(-rc == 0 ? EIO : -rc)
        }
        cachedInfo = info
        return info
    }
}

@available(macOS 15.4, *)
func posixError(_ code: Int32) -> NSError {
    NSError(domain: NSPOSIXErrorDomain, code: Int(code), userInfo: nil)
}

/// C 定长字符数组（`char[1024]` 之类）转 String，截断到首个 NUL。
@available(macOS 15.4, *)
func stringFromCArray<T>(_ buffer: inout T) -> String {
    withUnsafePointer(to: &buffer) { ptr in
        ptr.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<T>.size) { cstr in
            String(cString: cstr)
        }
    }
}

/// `[CChar]` 转 String（UTF-8，截断到首个 NUL）。
@available(macOS 15.4, *)
func stringFromBytes(_ bytes: [CChar]) -> String {
    let end = bytes.firstIndex(of: 0) ?? bytes.count
    return String(decoding: bytes[..<end].map { UInt8(bitPattern: $0) }, as: UTF8.self)
}

@available(macOS 15.4, *)
func makeAttributes(from info: NigateNTFSItemInfo, parent: UInt64) -> FSItem.Attributes {    let attrs = FSItem.Attributes()
    if info.is_dir {
        attrs.type = .directory
    } else if info.is_symlink {
        attrs.type = .symlink
    } else {
        attrs.type = .file
    }
    // FSItem.Identifier 的非可选 init 内部强解包 rawValue：0 会崩，用 invalid 兜底。
    let id = info.mft_no == 0 ? FSItem.Identifier.invalid : FSItem.Identifier(info.mft_no)
    let parentID = parent == 0 ? FSItem.Identifier.parentOfRoot : FSItem.Identifier(parent)
    attrs.fileID = id
    attrs.parentID = parentID
    attrs.size = info.size
    attrs.allocSize = info.alloc_size
    attrs.linkCount = UInt32(max(1, info.nlink))
    attrs.mode = UInt32(info.mode) & 0o7777
    attrs.uid = getuid()
    attrs.gid = getgid()
    attrs.accessTime = timespec(tv_sec: Int(info.atime_sec), tv_nsec: 0)
    attrs.modifyTime = timespec(tv_sec: Int(info.mtime_sec), tv_nsec: 0)
    attrs.changeTime = timespec(tv_sec: Int(info.ctime_sec), tv_nsec: 0)
    attrs.birthTime = timespec(tv_sec: Int(info.birth_sec), tv_nsec: 0)
    return attrs
}
