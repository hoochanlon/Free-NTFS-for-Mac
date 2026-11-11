import Foundation
import FSKit
import NigateFSKitCore
import os.log

#if canImport(NigateNTFSEngine)
import NigateNTFSEngine
#endif

private let log = Logger(subsystem: NigateFSKit.moduleIdentifier, category: "volume")

/// 把 FSBlockDeviceResource 的同步 read/write 接到 libntfs-3g 的 device ops。
@available(macOS 15.4, *)
final class BlockIOBox {
    let resource: FSBlockDeviceResource
    private let lock = NSLock()

    init(resource: FSBlockDeviceResource) {
        self.resource = resource
    }

    func makeIO() -> NigateBlockIO {
        NigateBlockIO(
            ctx: Unmanaged.passUnretained(self).toOpaque(),
            pread: { ctx, buf, count, offset in
                guard let ctx, let buf else { return -1 }
                let box = Unmanaged<BlockIOBox>.fromOpaque(ctx).takeUnretainedValue()
                return box.pread(buf: buf, count: count, offset: offset)
            },
            pwrite: { ctx, buf, count, offset in
                guard let ctx, let buf else { return -1 }
                let box = Unmanaged<BlockIOBox>.fromOpaque(ctx).takeUnretainedValue()
                return box.pwrite(buf: buf, count: count, offset: offset)
            },
            sync: { ctx in
                guard let ctx else { return -1 }
                let box = Unmanaged<BlockIOBox>.fromOpaque(ctx).takeUnretainedValue()
                return box.sync()
            },
            size: { ctx in
                guard let ctx else { return -1 }
                let box = Unmanaged<BlockIOBox>.fromOpaque(ctx).takeUnretainedValue()
                return box.size()
            }
        )
    }

    private func pread(buf: UnsafeMutableRawPointer, count: Int64, offset: Int64) -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        var error: NSError?
        let n = resource.__read(
            into: buf,
            startingAt: off_t(offset),
            length: Int(count),
            error: &error
        )
        if let error {
            log.error("block pread failed offset=\(offset) err=\(error.localizedDescription, privacy: .public)")
            return -1
        }
        return Int64(n)
    }

    private func pwrite(buf: UnsafeRawPointer, count: Int64, offset: Int64) -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        guard resource.isWritable else { return -1 }
        var error: NSError?
        let n = resource.__write(
            from: UnsafeMutableRawPointer(mutating: buf),
            startingAt: off_t(offset),
            length: Int(count),
            error: &error
        )
        if let error {
            log.error("block pwrite failed offset=\(offset) err=\(error.localizedDescription, privacy: .public)")
            return -1
        }
        return Int64(n)
    }

    private func sync() -> Int32 {
        // FSBlockDeviceResource 没有显式 fsync；metadata flush 在 umount/sync 路径做 best-effort。
        0
    }

    private func size() -> Int64 {
        let blocks = Int64(resource.blockCount)
        let bs = Int64(resource.blockSize)
        guard blocks > 0, bs > 0 else { return -1 }
        return blocks * bs
    }
}

@available(macOS 15.4, *)
final class NigateNTFSVolume: FSVolume, FSVolume.Operations, FSVolume.OpenCloseOperations, FSVolume.ReadWriteOperations {
    private let resource: FSBlockDeviceResource
    private let ioBox: BlockIOBox
    private var engine: OpaquePointer?
    private let engineLock = NSLock()
    private var readOnly: Bool
    private let caps = FSVolume.SupportedCapabilities()
    private let stats: FSStatFSResult
    private var rootItem: NigateNTFSItem!
    private var itemCache: [UInt64: NigateNTFSItem] = [:]

    init(resource: FSBlockDeviceResource, readOnly: Bool) throws {
        self.resource = resource
        self.ioBox = BlockIOBox(resource: resource)
        self.readOnly = readOnly || !resource.isWritable

        var io = ioBox.makeIO()
        var err = [CChar](repeating: 0, count: 256)
        guard let mounted = nigate_ntfs_mount(&io, self.readOnly, &err, err.count) else {
            let message = stringFromBytes(err)
            throw NSError(
                domain: NigateFSKit.moduleIdentifier,
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "ntfs mount failed: \(message)"]
            )
        }
        self.engine = mounted

        let volName = String(cString: nigate_ntfs_volume_name(mounted))
        let volumeID = FSVolume.Identifier(uuid: UUID())
        let name = FSFileName(string: volName.isEmpty ? NigateFSKit.fileSystemName : volName)
        self.stats = FSStatFSResult(fileSystemTypeName: NigateFSKit.shortName)

        super.init(volumeID: volumeID, volumeName: name)

        caps.supportsPersistentObjectIDs = true
        caps.supportsSymbolicLinks = true
        caps.supportsHardLinks = true
        caps.supportsSparseFiles = true
        caps.supportsHiddenFiles = true
        caps.supports64BitObjectIDs = true
        caps.doesNotSupportSettingFilePermissions = true
        caps.caseFormat = .insensitiveCasePreserving

        refreshStatistics()
        let rootMft = nigate_ntfs_root_mft(mounted)
        let root = NigateNTFSItem(mftNo: rootMft, parentMft: rootMft)
        _ = try? root.refresh(using: mounted)
        rootItem = root
        itemCache[rootMft] = root
    }

    deinit {
        if let engine {
            nigate_ntfs_umount(engine, true)
        }
    }

    // MARK: - PathConf

    var maximumLinkCount: Int { 1024 }
    var maximumNameLength: Int { 255 }
    var restrictsOwnershipChanges: Bool { true }
    var truncatesLongNames: Bool { false }
    var maximumXattrSize: Int { 65536 }
    var maximumFileSize: UInt64 { UInt64.max / 2 }

    // MARK: - Common

    var supportedVolumeCapabilities: FSVolume.SupportedCapabilities { caps }
    var volumeStatistics: FSStatFSResult {
        refreshStatistics()
        return stats
    }

    var enableOpenUnlinkEmulation: Bool { true }

    func mount(options: FSTaskOptions, replyHandler reply: @escaping ((any Error)?) -> Void) {
        reply(nil)
    }

    func unmount(replyHandler reply: @escaping () -> Void) {
        engineLock.lock()
        if let engine {
            nigate_ntfs_sync(engine)
            nigate_ntfs_umount(engine, false)
            self.engine = nil
        }
        itemCache.removeAll()
        engineLock.unlock()
        reply()
    }

    func synchronize(flags: FSSyncFlags, replyHandler reply: @escaping ((any Error)?) -> Void) {
        engineLock.lock()
        defer { engineLock.unlock() }
        guard let engine else {
            reply(posixError(ENXIO))
            return
        }
        let rc = nigate_ntfs_sync(engine)
        reply(rc == 0 ? nil : posixError(-rc == 0 ? EIO : -rc))
    }

    func reclaimItem(_ item: FSItem, replyHandler reply: @escaping ((any Error)?) -> Void) {
        // tryReclaim 是 macOS 27+ API；低版本直接回收缓存引用即可（FSKit 已保证 vnode 回调语义）。
        if #available(macOS 27.0, *), item.tryReclaim({
            self.forgetCache(for: item)
        }) {
            reply(nil)
            return
        }
        forgetCache(for: item)
        reply(nil)
    }

    private func forgetCache(for item: FSItem) {
        guard let nt = item as? NigateNTFSItem else { return }
        engineLock.lock()
        itemCache.removeValue(forKey: nt.mftNo)
        engineLock.unlock()
    }

    func activate(options: FSTaskOptions, replyHandler reply: @escaping (FSItem?, (any Error)?) -> Void) {
        reply(rootItem, nil)
    }

    func deactivate(options: FSDeactivateOptions, replyHandler reply: @escaping ((any Error)?) -> Void) {
        if options.contains(.force) {
            engineLock.lock()
            if let engine {
                nigate_ntfs_umount(engine, true)
                self.engine = nil
            }
            engineLock.unlock()
        }
        reply(nil)
    }

    func lookupItem(
        named name: FSFileName,
        inDirectory directory: FSItem,
        replyHandler reply: @escaping (FSItem?, FSFileName?, (any Error)?) -> Void
    ) {
        guard let dir = directory as? NigateNTFSItem else {
            reply(nil, nil, posixError(EINVAL))
            return
        }
        let nameStr = name.string ?? ""
        if nameStr == "." {
            reply(dir, name, nil)
            return
        }
        if nameStr == ".." {
            let parent = item(for: dir.parentMft, parent: dir.parentMft)
            reply(parent, name, nil)
            return
        }
        engineLock.lock()
        defer { engineLock.unlock() }
        guard let engine else {
            reply(nil, nil, posixError(ENXIO))
            return
        }
        var out: UInt64 = 0
        let rc = nameStr.withCString { cName in
            nigate_ntfs_lookup(engine, dir.mftNo, cName, &out)
        }
        guard rc == 0 else {
            reply(nil, nil, posixError(-rc == 0 ? ENOENT : -rc))
            return
        }
        let item = itemLocked(for: out, parent: dir.mftNo, engine: engine)
        reply(item, name, nil)
    }

    func createItem(
        named name: FSFileName,
        type: FSItem.ItemType,
        inDirectory directory: FSItem,
        attributes: FSItem.SetAttributesRequest,
        replyHandler reply: @escaping (FSItem?, FSFileName?, (any Error)?) -> Void
    ) {
        guard let dir = directory as? NigateNTFSItem else {
            reply(nil, nil, posixError(EINVAL))
            return
        }
        if readOnly {
            reply(nil, nil, posixError(EROFS))
            return
        }
        let isDir = type == .directory
        let nameStr = name.string ?? ""
        engineLock.lock()
        defer { engineLock.unlock() }
        guard let engine else {
            reply(nil, nil, posixError(ENXIO))
            return
        }
        var out: UInt64 = 0
        let rc = nameStr.withCString { cName in
            nigate_ntfs_create(engine, dir.mftNo, cName, isDir, &out)
        }
        guard rc == 0 else {
            reply(nil, nil, posixError(-rc == 0 ? EIO : -rc))
            return
        }
        if attributes.isValid(.size), attributes.type == .file {
            _ = nigate_ntfs_truncate(engine, out, Int64(attributes.size))
        }
        let item = itemLocked(for: out, parent: dir.mftNo, engine: engine)
        reply(item, name, nil)
    }

    func createSymbolicLink(
        named name: FSFileName,
        inDirectory directory: FSItem,
        attributes: FSItem.SetAttributesRequest,
        linkContents contents: FSFileName,
        replyHandler reply: @escaping (FSItem?, FSFileName?, (any Error)?) -> Void
    ) {
        guard let dir = directory as? NigateNTFSItem else {
            reply(nil, nil, posixError(EINVAL))
            return
        }
        if readOnly {
            reply(nil, nil, posixError(EROFS))
            return
        }
        let nameStr = name.string ?? ""
        let target = contents.string ?? ""
        engineLock.lock()
        defer { engineLock.unlock() }
        guard let engine else {
            reply(nil, nil, posixError(ENXIO))
            return
        }
        var out: UInt64 = 0
        let rc = nameStr.withCString { cName in
            target.withCString { cTarget in
                nigate_ntfs_symlink(engine, dir.mftNo, cName, cTarget, &out)
            }
        }
        guard rc == 0 else {
            reply(nil, nil, posixError(-rc == 0 ? EIO : -rc))
            return
        }
        let item = itemLocked(for: out, parent: dir.mftNo, engine: engine)
        reply(item, name, nil)
    }

    func createLink(
        to item: FSItem,
        named name: FSFileName,
        inDirectory directory: FSItem,
        replyHandler reply: @escaping (FSFileName?, (any Error)?) -> Void
    ) {
        guard let src = item as? NigateNTFSItem, let dir = directory as? NigateNTFSItem else {
            reply(nil, posixError(EINVAL))
            return
        }
        if readOnly {
            reply(nil, posixError(EROFS))
            return
        }
        let nameStr = name.string ?? ""
        engineLock.lock()
        defer { engineLock.unlock() }
        guard let engine else {
            reply(nil, posixError(ENXIO))
            return
        }
        let rc = nameStr.withCString { cName in
            nigate_ntfs_link(engine, src.mftNo, dir.mftNo, cName)
        }
        reply(rc == 0 ? name : nil, rc == 0 ? nil : posixError(-rc == 0 ? EIO : -rc))
    }

    func removeItem(
        _ item: FSItem,
        named name: FSFileName,
        fromDirectory directory: FSItem,
        replyHandler reply: @escaping ((any Error)?) -> Void
    ) {
        guard let target = item as? NigateNTFSItem, let dir = directory as? NigateNTFSItem else {
            reply(posixError(EINVAL))
            return
        }
        if readOnly {
            reply(posixError(EROFS))
            return
        }
        let nameStr = name.string ?? ""
        engineLock.lock()
        defer { engineLock.unlock() }
        guard let engine else {
            reply(posixError(ENXIO))
            return
        }
        let rc = nameStr.withCString { cName in
            nigate_ntfs_unlink(engine, dir.mftNo, target.mftNo, cName)
        }
        reply(rc == 0 ? nil : posixError(-rc == 0 ? EIO : -rc))
    }

    func renameItem(
        _ item: FSItem,
        inDirectory sourceDirectory: FSItem,
        named sourceName: FSFileName,
        to destinationName: FSFileName,
        inDirectory destinationDirectory: FSItem,
        overItem: FSItem?,
        replyHandler reply: @escaping (FSFileName?, (any Error)?) -> Void
    ) {
        guard
            let target = item as? NigateNTFSItem,
            let srcDir = sourceDirectory as? NigateNTFSItem,
            let dstDir = destinationDirectory as? NigateNTFSItem
        else {
            reply(nil, posixError(EINVAL))
            return
        }
        if readOnly {
            reply(nil, posixError(EROFS))
            return
        }
        let src = sourceName.string ?? ""
        let dst = destinationName.string ?? ""
        let over = (overItem as? NigateNTFSItem)?.mftNo ?? 0
        engineLock.lock()
        defer { engineLock.unlock() }
        guard let engine else {
            reply(nil, posixError(ENXIO))
            return
        }
        let rc = src.withCString { cSrc in
            dst.withCString { cDst in
                nigate_ntfs_rename(
                    engine,
                    srcDir.mftNo,
                    target.mftNo,
                    cSrc,
                    dstDir.mftNo,
                    cDst,
                    over
                )
            }
        }
        reply(rc == 0 ? destinationName : nil, rc == 0 ? nil : posixError(-rc == 0 ? EIO : -rc))
    }

    func getAttributes(
        _ desiredAttributes: FSItem.GetAttributesRequest,
        of item: FSItem,
        replyHandler reply: @escaping (FSItem.Attributes?, (any Error)?) -> Void
    ) {
        guard let nt = item as? NigateNTFSItem else {
            reply(nil, posixError(EINVAL))
            return
        }
        engineLock.lock()
        defer { engineLock.unlock() }
        guard let engine else {
            reply(nil, posixError(ENXIO))
            return
        }
        do {
            let info = try nt.refresh(using: engine)
            reply(makeAttributes(from: info, parent: nt.parentMft), nil)
        } catch {
            reply(nil, error)
        }
    }

    func setAttributes(
        _ newAttributes: FSItem.SetAttributesRequest,
        on item: FSItem,
        replyHandler reply: @escaping (FSItem.Attributes?, (any Error)?) -> Void
    ) {
        guard let nt = item as? NigateNTFSItem else {
            reply(nil, posixError(EINVAL))
            return
        }
        if readOnly {
            reply(nil, posixError(EROFS))
            return
        }
        engineLock.lock()
        defer { engineLock.unlock() }
        guard let engine else {
            reply(nil, posixError(ENXIO))
            return
        }
        if newAttributes.isValid(.size) {
            let rc = nigate_ntfs_truncate(engine, nt.mftNo, Int64(newAttributes.size))
            if rc != 0 {
                reply(nil, posixError(-rc == 0 ? EIO : -rc))
                return
            }
            newAttributes.consumedAttributes.insert(.size)
        }
        do {
            let info = try nt.refresh(using: engine)
            reply(makeAttributes(from: info, parent: nt.parentMft), nil)
        } catch {
            reply(nil, error)
        }
    }

    func enumerateDirectory(
        _ directory: FSItem,
        startingAt cookie: FSDirectoryCookie,
        verifier: FSDirectoryVerifier,
        attributes: FSItem.GetAttributesRequest?,
        packer: FSDirectoryEntryPacker,
        replyHandler reply: @escaping (FSDirectoryVerifier, (any Error)?) -> Void
    ) {
        guard let dir = directory as? NigateNTFSItem else {
            reply(verifier, posixError(EINVAL))
            return
        }
        engineLock.lock()
        defer { engineLock.unlock() }
        guard let engine else {
            reply(verifier, posixError(ENXIO))
            return
        }

        var pos = Int64(bitPattern: UInt64(cookie.rawValue))
        // cookie 0: 先打包 . 与 ..（attributes==nil 时）
        if pos == 0, attributes == nil {
            let dot = FSFileName(string: ".")
            let dotdot = FSFileName(string: "..")
            _ = packer.packEntry(
                name: dot,
                itemType: .directory,
                itemID: FSItem.Identifier(dir.mftNo),
                nextCookie: FSDirectoryCookie(1),
                attributes: nil
            )
            _ = packer.packEntry(
                name: dotdot,
                itemType: .directory,
                itemID: FSItem.Identifier(dir.parentMft),
                nextCookie: FSDirectoryCookie(2),
                attributes: nil
            )
            pos = 2
        } else if pos > 0 && pos < 2 {
            pos = 2
        }

        // ntfs readdir pos 与 cookie 偏移：我们用 cookie>=2 映射到 ntfs pos = cookie-2
        var ntfsPos = max(Int64(0), pos - 2)
        var entries = [NigateNTFSDirEntry](repeating: NigateNTFSDirEntry(), count: 64)
        var written: Int32 = 0
        let rc = entries.withUnsafeMutableBufferPointer { buf in
            nigate_ntfs_readdir(engine, dir.mftNo, &ntfsPos, buf.baseAddress, Int32(buf.count), &written)
        }
        if rc != 0 {
            reply(verifier, posixError(-rc == 0 ? EIO : -rc))
            return
        }
        for i in 0..<Int(written) {
            var e = entries[i]
            let name = stringFromCArray(&e.name)
            if name == "." || name == ".." { continue }
            let type: FSItem.ItemType
            switch e.type {
            case 4: type = .directory
            case 10: type = .symlink
            default: type = .file
            }
            var attrs: FSItem.Attributes?
            if attributes != nil {
                var info = NigateNTFSItemInfo()
                if nigate_ntfs_item_info(engine, e.mft_no, &info) == 0 {
                    attrs = makeAttributes(from: info, parent: dir.mftNo)
                }
            }
            let nextCookie = FSDirectoryCookie(UInt64(bitPattern: Int64(e.next_pos) + 2))
            let keepGoing = packer.packEntry(
                name: FSFileName(string: name),
                itemType: type,
                itemID: FSItem.Identifier(e.mft_no),
                nextCookie: nextCookie,
                attributes: attrs
            )
            if !keepGoing { break }
        }
        reply(verifier, nil)
    }

    func readSymbolicLink(
        _ item: FSItem,
        replyHandler reply: @escaping (FSFileName?, (any Error)?) -> Void
    ) {
        guard let nt = item as? NigateNTFSItem else {
            reply(nil, posixError(EINVAL))
            return
        }
        engineLock.lock()
        defer { engineLock.unlock() }
        guard let engine else {
            reply(nil, posixError(ENXIO))
            return
        }
        var buf = [CChar](repeating: 0, count: 4096)
        let rc = nigate_ntfs_readlink(engine, nt.mftNo, &buf, buf.count)
        guard rc == 0 else {
            reply(nil, posixError(-rc == 0 ? EINVAL : -rc))
            return
        }
        reply(FSFileName(string: stringFromBytes(buf)), nil)
    }

    // MARK: - Open/Close

    // 协议要求 { get set }，get-only 属性不满足 Optional requirement。
    var isOpenCloseInhibited: Bool = false

    func openItem(
        _ item: FSItem,
        modes: FSVolume.OpenModes,
        replyHandler reply: @escaping ((any Error)?) -> Void
    ) {
        if modes.contains(.write) && readOnly {
            reply(posixError(EROFS))
            return
        }
        reply(nil)
    }

    func closeItem(
        _ item: FSItem,
        modes: FSVolume.OpenModes,
        replyHandler reply: @escaping ((any Error)?) -> Void
    ) {
        reply(nil)
    }

    // MARK: - Read/Write

    func read(
        from item: FSItem,
        at offset: off_t,
        length: Int,
        into buffer: FSMutableFileDataBuffer,
        replyHandler reply: @escaping (Int, (any Error)?) -> Void
    ) {
        guard let nt = item as? NigateNTFSItem else {
            reply(0, posixError(EINVAL))
            return
        }
        engineLock.lock()
        defer { engineLock.unlock() }
        guard let engine else {
            reply(0, posixError(ENXIO))
            return
        }
        var got: Int64 = 0
        let rc = buffer.withUnsafeMutableBytes { raw -> Int32 in
            guard let base = raw.baseAddress else { return -Int32(EFAULT) }
            return nigate_ntfs_read(engine, nt.mftNo, Int64(offset), base, Int64(length), &got)
        }
        if rc != 0 {
            reply(Int(got), posixError(-rc == 0 ? EIO : -rc))
            return
        }
        reply(Int(got), nil)
    }

    func write(
        contents: Data,
        to item: FSItem,
        at offset: off_t,
        replyHandler reply: @escaping (Int, (any Error)?) -> Void
    ) {
        guard let nt = item as? NigateNTFSItem else {
            reply(0, posixError(EINVAL))
            return
        }
        if readOnly {
            reply(0, posixError(EROFS))
            return
        }
        engineLock.lock()
        defer { engineLock.unlock() }
        guard let engine else {
            reply(0, posixError(ENXIO))
            return
        }
        var wrote: Int64 = 0
        let rc = contents.withUnsafeBytes { raw -> Int32 in
            guard let base = raw.baseAddress else { return -Int32(EFAULT) }
            return nigate_ntfs_write(engine, nt.mftNo, Int64(offset), base, Int64(contents.count), &wrote)
        }
        if rc != 0 {
            reply(Int(wrote), posixError(-rc == 0 ? EIO : -rc))
            return
        }
        reply(Int(wrote), nil)
    }

    // MARK: - Helpers

    private func refreshStatistics() {
        engineLock.lock()
        defer { engineLock.unlock() }
        guard let engine else { return }
        let cluster = max(UInt64(1), nigate_ntfs_cluster_size(engine))
        let total = nigate_ntfs_total_clusters(engine)
        let free = nigate_ntfs_free_clusters(engine)
        stats.blockSize = Int(cluster)
        stats.ioSize = Int(cluster)
        stats.totalBlocks = total
        stats.freeBlocks = free
        stats.availableBlocks = free
        stats.usedBlocks = total > free ? total - free : 0
    }

    private func item(for mft: UInt64, parent: UInt64) -> NigateNTFSItem {
        engineLock.lock()
        defer { engineLock.unlock() }
        if let engine {
            return itemLocked(for: mft, parent: parent, engine: engine)
        }
        if let cached = itemCache[mft] { return cached }
        let created = NigateNTFSItem(mftNo: mft, parentMft: parent)
        itemCache[mft] = created
        return created
    }

    private func itemLocked(for mft: UInt64, parent: UInt64, engine: OpaquePointer) -> NigateNTFSItem {
        if let cached = itemCache[mft] {
            return cached
        }
        let created = NigateNTFSItem(mftNo: mft, parentMft: parent)
        _ = try? created.refresh(using: engine)
        itemCache[mft] = created
        return created
    }
}
