import Foundation
import NigateFSKitCore
import ObjectiveC

#if canImport(FSKit)
import FSKit
#endif

/// 主应用侧 FSKit 挂载入口。
///
/// 优先：`FSClient.mountSingleVolume` + block-device proxy（需要 fskit.mount entitlement）。
/// 回退：`mount -t NigateNTFS`（扩展已注册时由 fskitd 接管）。
@MainActor
enum FSKitMountService {
    static func mount(
        device: NTFSDevice,
        readOnly: Bool,
        run: (_ args: [String], _ password: inout String, _ refreshKey: String, _ name: String, _ timeout: TimeInterval) async throws -> ShellResult,
        password: inout String
    ) async throws -> String {
        try await assertControlPlaneReady()

        if device.isMounted && !device.isUnmounted {
            _ = try await run(
                ["umount", "-f", device.devicePath],
                &password,
                "messages.passwordDialog.mountDevice",
                device.volumeName,
                30
            )
        }

        let clientError = await mountViaFSClient(device: device, readOnly: readOnly)
        if clientError == nil {
            return "设备 \(device.volumeName) 已通过 FSKit 挂载为\(readOnly ? "只读" : "读写")模式"
        }

        // FSClient 失败时（常见：无 fskit.mount 签名 entitlement），走 mount(8) 短名路径。
        try await mountViaMountCommand(
            device: device,
            readOnly: readOnly,
            run: run,
            password: &password
        )
        return "设备 \(device.volumeName) 已通过 FSKit(\(NigateFSKit.shortName)) 挂载为\(readOnly ? "只读" : "读写")模式"
    }

    static func unmount(
        device: NTFSDevice,
        run: (_ args: [String], _ password: inout String, _ refreshKey: String, _ name: String, _ timeout: TimeInterval) async throws -> ShellResult,
        password: inout String
    ) async throws {
        do {
            _ = try await run(
                ["umount", "-f", device.devicePath],
                &password,
                "messages.passwordDialog.unmountDevice",
                device.volumeName,
                30
            )
        } catch {
            let fallback = await Shell.runQuiet("/usr/sbin/diskutil", ["unmount", "force", device.devicePath], timeout: 8)
            if !fallback.ok {
                throw AppError.failed("卸载失败: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private

    private static func assertControlPlaneReady() async throws {
        // 挂载前再探测一次，避免启动后用户刚启用扩展却仍读到旧快照。
        let state = await FSKitControlPlaneService.probe()
        MountBackendPolicy.updateControlPlaneState(state)
        guard state.isControlPlaneAvailable else {
            throw AppError.fsKitUnavailable
        }
    }

    private static func mountViaFSClient(device: NTFSDevice, readOnly: Bool) async -> Error? {
        // mountSingleVolume 是 macOS 27 才导出的 V3 API；旧系统直接走 mount(8)。
        guard #available(macOS 27.0, *) else {
            return AppError.failed("mountSingleVolume unavailable")
        }
        #if canImport(FSKit)
        guard let resource = FSBlockDeviceResourceProxy.make(bsdName: device.disk, writable: !readOnly) else {
            return AppError.failed("无法创建 FSBlockDeviceResource proxy")
        }
        var options: [String] = []
        if readOnly {
            options.append("rdonly")
        }
        do {
            _ = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL, Error>) in
                FSClient.shared.mountSingleVolume(
                    resource: resource,
                    bundleID: NigateFSKit.moduleIdentifier,
                    options: options
                ) { url, error in
                    if let error {
                        cont.resume(throwing: error)
                    } else if let url {
                        cont.resume(returning: url)
                    } else {
                        cont.resume(throwing: AppError.failed("FSKit mount returned empty path"))
                    }
                }
            }
            return nil
        } catch {
            return error
        }
        #else
        return AppError.fsKitUnavailable
        #endif
    }

    private static func mountViaMountCommand(
        device: NTFSDevice,
        readOnly: Bool,
        run: (_ args: [String], _ password: inout String, _ refreshKey: String, _ name: String, _ timeout: TimeInterval) async throws -> ShellResult,
        password: inout String
    ) async throws {
        let mountPoint = device.volume.isEmpty
            ? "/Volumes/\(DiskSafety.sanitizeVolumeName(device.volumeName))"
            : device.volume
        guard DiskSafety.isSafeMountPoint(mountPoint) else {
            throw AppError.invalidPath
        }

        _ = try await run(
            ["mkdir", "-p", mountPoint],
            &password,
            "messages.passwordDialog.mountDevice",
            device.volumeName,
            30
        )

        var args = ["mount", "-t", NigateFSKit.shortName]
        if readOnly {
            args += ["-o", "rdonly"]
        }
        args += [device.devicePath, mountPoint]

        do {
            _ = try await run(
                args,
                &password,
                "messages.passwordDialog.mountDeviceRetry",
                device.volumeName,
                15
            )
        } catch {
            // 部分系统更认 diskutil + filesystem 选项
            var diskutilArgs = ["diskutil", "mount"]
            if readOnly {
                diskutilArgs.append("readOnly")
            }
            diskutilArgs += ["-mountOptions", "filesystem=\(NigateFSKit.shortName)", device.devicePath]
            do {
                _ = try await run(
                    diskutilArgs,
                    &password,
                    "messages.passwordDialog.mountDeviceRetry",
                    device.volumeName,
                    15
                )
            } catch {
                throw AppError.failed(
                    "FSKit 挂载失败（FSClient 与 mount -t \(NigateFSKit.shortName) 均未成功）。请确认扩展已在“系统设置 → 文件系统扩展”中启用。底层错误: \(error.localizedDescription)"
                )
            }
        }
    }
}

#if canImport(FSKit)
/// 公开头文件未导出 proxy factory；运行时 selector 已验证存在。
@available(macOS 15.4, *)
enum FSBlockDeviceResourceProxy {
    static func make(bsdName: String, writable: Bool) -> FSBlockDeviceResource? {
        let cls: AnyClass = FSBlockDeviceResource.self
        let sel = NSSelectorFromString("proxyResourceForBSDName:isWritable:")
        guard let method = class_getClassMethod(cls, sel) else {
            return nil
        }
        typealias Factory = @convention(c) (AnyClass, Selector, NSString, Bool) -> FSBlockDeviceResource?
        let impl = unsafeBitCast(method_getImplementation(method), to: Factory.self)
        return impl(cls, sel, bsdName as NSString, writable)
    }
}
#endif
