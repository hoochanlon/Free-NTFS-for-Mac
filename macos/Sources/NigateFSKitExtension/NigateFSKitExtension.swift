import Foundation
import FSKit
import NigateFSKitCore
import os.log

// SwiftPM 下 C 引擎是独立 target；Xcode 工程里通过 bridging header 注入。
#if canImport(NigateNTFSEngine)
import NigateNTFSEngine
#endif

private let log = Logger(subsystem: NigateFSKit.moduleIdentifier, category: "fs")

@available(macOS 15.4, *)
final class NigateFSFileSystem: FSUnaryFileSystem, FSUnaryFileSystemOperations, FSManageableResourceMaintenanceOperations {
    private var loadedVolume: NigateNTFSVolume?

    func probeResource(
        resource: FSResource,
        replyHandler: @escaping (FSProbeResult?, (any Error)?) -> Void
    ) {
        guard let block = resource as? FSBlockDeviceResource else {
            replyHandler(.notRecognized, nil)
            return
        }

        let ioBox = BlockIOBox(resource: block)
        var io = ioBox.makeIO()
        var nameBuf = [CChar](repeating: 0, count: 256)
        let rc = nigate_ntfs_probe_boot(&io, &nameBuf, nameBuf.count)
        switch rc {
        case 1:
            let name = stringFromBytes(nameBuf)
            let container = FSContainerIdentifier()
            let display = name.isEmpty ? NigateFSKit.fileSystemName : name
            // 可写资源声明 usable；只读/受限声明 limited，避免强行 RW。
            if block.isWritable {
                replyHandler(.usable(name: display, containerID: container), nil)
            } else {
                replyHandler(.usableButLimited(name: display, containerID: container), nil)
            }
        case 0:
            replyHandler(.notRecognized, nil)
        default:
            replyHandler(nil, posixError(EIO))
        }
    }

    func loadResource(
        resource: FSResource,
        options: FSTaskOptions,
        replyHandler: @escaping (FSVolume?, (any Error)?) -> Void
    ) {
        guard let block = resource as? FSBlockDeviceResource else {
            replyHandler(
                nil,
                NSError(
                    domain: NigateFSKit.moduleIdentifier,
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "NigateNTFS only supports block device resources"]
                )
            )
            return
        }

        // 选项里若带 rdonly/ro，强制只读。
        let optionTokens = Set(options.taskOptions.map { $0.lowercased() })
        let wantRO = optionTokens.contains("rdonly")
            || optionTokens.contains("ro")
            || optionTokens.contains("readonly")
            || !block.isWritable

        do {
            let volume = try NigateNTFSVolume(resource: block, readOnly: wantRO)
            loadedVolume = volume
            log.info("loaded NTFS on \(block.bsdName, privacy: .public) ro=\(wantRO)")
            replyHandler(volume, nil)
        } catch {
            log.error("loadResource failed: \(error.localizedDescription, privacy: .public)")
            replyHandler(nil, error)
        }
    }

    func unloadResource(
        resource: FSResource,
        options: FSTaskOptions,
        replyHandler: @escaping ((any Error)?) -> Void
    ) {
        loadedVolume = nil
        replyHandler(nil)
    }

    func didFinishLoading() {
        log.info("Nigate FSKit extension ready")
    }

    // MARK: - Maintenance (required for block resources; format/check 走主应用)

    // 注意：ObjC 的 (nullable 返回 + NSError**) 在 Swift 侧收敛为 `throws -> Progress`，
    // 返回值不能是可选类型，否则不满足 @objc requirement。
    func startCheck(
        task: FSTask,
        options: FSTaskOptions
    ) throws -> Progress {
        throw posixError(ENOTSUP)
    }

    func startFormat(
        task: FSTask,
        options: FSTaskOptions
    ) throws -> Progress {
        throw posixError(ENOTSUP)
    }
}

@available(macOS 15.4, *)
@main
struct NigateFSKitExtension: UnaryFileSystemExtension {
    var fileSystem: NigateFSFileSystem {
        NigateFSFileSystem()
    }
}
