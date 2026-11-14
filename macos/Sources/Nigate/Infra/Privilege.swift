import Foundation
import Darwin

enum Privilege {
    private static let extraEnvAllowlist: Set<String> = [
        "DYLD_LIBRARY_PATH",
        "DYLD_FALLBACK_LIBRARY_PATH"
    ]

    /// 这些命令的子进程不应看到 Homebrew sbin（其中的 mount_ntfs 会强制走 ntfs-3g）。
    private static let systemPathCommands: Set<String> = [
        "diskutil", "umount", "mount", "mkdir", "rmdir", "gpt"
    ]

    static func sudo(
        _ args: [String],
        password: String,
        timeout: TimeInterval = 30,
        extraEnv: [String: String] = [:]
    ) async throws -> ShellResult {
        if password.isEmpty { throw AppError.emptyPassword }
        let executable = Shell.trustedExecutable("/usr/bin/sudo") ?? "/usr/bin/sudo"
        let arguments = try validatedArguments(args)
        let wrapped = try wrap(arguments, extraEnv: extraEnv)

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = ["-S"] + wrapped
            process.environment = environment(for: arguments.first ?? "")
            let out = Pipe()
            let err = Pipe()
            let input = Pipe()
            process.standardOutput = out
            process.standardError = err
            process.standardInput = input

            let box = SudoBox(continuation)
            process.terminationHandler = { proc in
                let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                box.finish(status: proc.terminationStatus, stdout: stdout, stderr: stderr)
            }

            do {
                try process.run()
                try input.fileHandleForWriting.write(contentsOf: Data((password + "\n").utf8))
                try? input.fileHandleForWriting.close()
            } catch {
                box.fail(error)
                return
            }

            if timeout > 0 {
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                    guard process.isRunning else { return }
                    process.terminate()
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                        if process.isRunning {
                            kill(process.processIdentifier, SIGKILL)
                        }
                        box.timeout()
                    }
                }
            }
        }
    }

    private static func validatedArguments(_ args: [String]) throws -> [String] {
        guard let command = args.first else { return args }
        // sudo -v is a validation probe and has no executable argument.
        if command.hasPrefix("-") { return args }
        guard let executable = Shell.trustedExecutable(command) else {
            throw AppError.missingTool("不受信任或不存在的特权命令: \(command)")
        }
        return [executable] + args.dropFirst()
    }

    /// sudo 会丢掉 DYLD_*；用 /usr/bin/env 在提权后再注入。
    private static func wrap(_ arguments: [String], extraEnv: [String: String]) throws -> [String] {
        guard !extraEnv.isEmpty else { return arguments }
        var assignments: [String] = []
        for (key, value) in extraEnv {
            guard extraEnvAllowlist.contains(key) else {
                throw AppError.failed("不受信任的环境变量: \(key)")
            }
            guard value.hasPrefix("/"), !value.contains("\0"), !value.contains("\n") else {
                throw AppError.failed("不受信任的库路径")
            }
            assignments.append("\(key)=\(value)")
        }
        let env = Shell.trustedExecutable("/usr/bin/env") ?? "/usr/bin/env"
        return [env] + assignments + arguments
    }

    private static func environment(for executable: String) -> [String: String] {
        var env = Shell.environment
        let name = URL(fileURLWithPath: executable).lastPathComponent
        if systemPathCommands.contains(name) {
            env["PATH"] = Shell.systemPath.joined(separator: ":")
        }
        return env
    }
}

private final class SudoBox: @unchecked Sendable {
    private var continuation: CheckedContinuation<ShellResult, Error>?
    private let lock = NSLock()

    init(_ continuation: CheckedContinuation<ShellResult, Error>) {
        self.continuation = continuation
    }

    func finish(status: Int32, stdout: String, stderr: String) {
        lock.lock()
        let item = continuation
        continuation = nil
        lock.unlock()
        guard let item else { return }
        if status == 0 {
            item.resume(returning: ShellResult(stdout: stdout, stderr: stderr, status: status))
            return
        }
        let combined = (stderr + " " + stdout)
        if PasswordError.isIncorrect(combined) || (status == 1 && combined.lowercased().contains("password")) {
            item.resume(throwing: AppError.incorrectPassword)
        } else if FuseLibrary.isMissingLibraryError(combined) {
            item.resume(throwing: AppError.macfuseMissing)
        } else {
            let message = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            item.resume(throwing: AppError.failed(message.isEmpty ? "退出码 \(status)" : message))
        }
    }

    func fail(_ error: Error) {
        lock.lock()
        let item = continuation
        continuation = nil
        lock.unlock()
        item?.resume(throwing: error)
    }

    func timeout() {
        lock.lock()
        let item = continuation
        continuation = nil
        lock.unlock()
        item?.resume(throwing: AppError.timeout("操作超时"))
    }
}
