import Foundation
import FSKit
import NigateFSKitCore

@available(macOS 15.4, *)
final class NigateFSFileSystem: FSUnaryFileSystem, FSUnaryFileSystemOperations {
    func probeResource(
        resource: FSResource,
        replyHandler: @escaping (FSProbeResult?, (any Error)?) -> Void
    ) {
        // 骨架阶段不声明任何格式，避免在控制面接通前接管系统磁盘。
        replyHandler(.notRecognized, nil)
    }

    func loadResource(
        resource: FSResource,
        options: FSTaskOptions,
        replyHandler: @escaping (FSVolume?, (any Error)?) -> Void
    ) {
        replyHandler(
            nil,
            NSError(
                domain: NigateFSKit.moduleIdentifier,
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Nigate FSKit backend is not enabled yet"]
            )
        )
    }

    func unloadResource(
        resource: FSResource,
        options: FSTaskOptions,
        replyHandler: @escaping ((any Error)?) -> Void
    ) {
        replyHandler(nil)
    }

    func didFinishLoading() {
        // 入口保留给后续生命周期日志与控制面握手。
    }
}

@available(macOS 15.4, *)
@main
struct NigateFSKitExtension: UnaryFileSystemExtension {
    var fileSystem: NigateFSFileSystem {
        NigateFSFileSystem()
    }
}
