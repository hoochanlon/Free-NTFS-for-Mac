import Foundation
import Darwin

struct ShellResult: Sendable {
    var stdout: String
    var stderr: String
    var status: Int32

    var ok: Bool { status == 0 }
    var text: String {
        let out = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let err = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return out.isEmpty ? err : out
    }
}

enum Shell {
    // Privileged and dependency commands must not inherit PATH or loader settings from the user shell.
    static let trustedPath = [
        "/opt/homebrew/bin", "/opt/homebrew/sbin",
        "/usr/local/bin", "/usr/local/sbin",
        "/usr/bin", "/bin", "/usr/sbin", "/sbin"
    ]

    private static let trustedRoots = [
        "/opt/homebrew", "/usr/local", "/usr/bin", "/bin", "/usr/sbin", "/sbin"
    ]

    static var extraPath: [String] { trustedPath }

    static var environment: [String: String] {
        [
            "PATH": trustedPath.joined(separator: ":"),
            "HOME": FileManager.default.homeDirectoryForCurrentUser.path,
            "LANG": "C",
            "LC_ALL": "C"
        ]
    }

    static func which(_ name: String) -> String? {
        trustedExecutable(name)
    }

    static func trustedExecutable(_ nameOrPath: String) -> String? {
        let candidate: String?
        if nameOrPath.hasPrefix("/") {
            candidate = nameOrPath
        } else {
            candidate = trustedPath
                .map { "\($0)/\(nameOrPath)" }
                .first { FileManager.default.isExecutableFile(atPath: $0) }
        }
        guard let candidate,
              FileManager.default.isExecutableFile(atPath: candidate) else { return nil }
        let resolved = URL(fileURLWithPath: candidate).resolvingSymlinksInPath().path
        guard FileManager.default.isExecutableFile(atPath: resolved), isTrustedPath(resolved) else {
            return nil
        }
        return resolved
    }

    static func exists(_ path: String) -> Bool {
        if FileManager.default.fileExists(atPath: path) { return true }
        if !path.hasPrefix("/System/Volumes/Data") {
            return FileManager.default.fileExists(atPath: "/System/Volumes/Data" + path)
        }
        return false
    }

    static func run(
        _ launchPath: String,
        _ args: [String] = [],
        timeout: TimeInterval = 15,
        env: [String: String]? = nil
    ) async throws -> ShellResult {
        guard let executable = trustedExecutable(launchPath) else {
            throw AppError.missingTool("不受信任或不存在的可执行文件: \(launchPath)")
        }
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = args
            process.environment = env ?? environment
            let out = Pipe()
            let err = Pipe()
            process.standardOutput = out
            process.standardError = err

            let box = ContinuationBox(continuation)
            process.terminationHandler = { proc in
                let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                box.resume(ShellResult(stdout: stdout, stderr: stderr, status: proc.terminationStatus))
            }

            do {
                try process.run()
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

    static func runQuiet(_ launchPath: String, _ args: [String] = [], timeout: TimeInterval = 8) async -> ShellResult {
        (try? await run(launchPath, args, timeout: timeout)) ?? ShellResult(stdout: "", stderr: "", status: -1)
    }

    private static func isTrustedPath(_ path: String) -> Bool {
        trustedRoots.contains { path == $0 || path.hasPrefix($0 + "/") }
    }
}

private final class ContinuationBox: @unchecked Sendable {
    private var continuation: CheckedContinuation<ShellResult, Error>?
    private let lock = NSLock()

    init(_ continuation: CheckedContinuation<ShellResult, Error>) {
        self.continuation = continuation
    }

    func resume(_ value: ShellResult) {
        lock.lock()
        let item = continuation
        continuation = nil
        lock.unlock()
        item?.resume(returning: value)
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
