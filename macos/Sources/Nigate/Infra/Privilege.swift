import Foundation
import Darwin

enum Privilege {
    static func sudo(_ args: [String], password: String, timeout: TimeInterval = 30) async throws -> ShellResult {
        if password.isEmpty { throw AppError.emptyPassword }
        let executable = Shell.trustedExecutable("/usr/bin/sudo") ?? "/usr/bin/sudo"
        let arguments = try validatedArguments(args)

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = ["-S"] + arguments
            process.environment = Shell.environment
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
