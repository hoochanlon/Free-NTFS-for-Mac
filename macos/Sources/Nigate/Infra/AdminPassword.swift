import Foundation
import Security

/// 管理员密码的唯一入口：本次进程可记住，退出即丢。
/// 旧版写入登录钥匙串的条目只删不读，避免 ad-hoc 签名反复弹窗。
enum AdminPassword {
    static func remembered() -> String? {
        PasswordMemory.read()
    }

    static func remember(_ password: String) {
        PasswordMemory.remember(password)
        LoginKeychainResidue.delete()
    }

    static func forget() {
        PasswordMemory.forget()
        LoginKeychainResidue.delete()
    }
}

enum PasswordMemory {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var memory: String?

    static func read() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return memory
    }

    static func remember(_ password: String) {
        lock.lock()
        memory = password
        lock.unlock()
    }

    static func forget() {
        lock.lock()
        memory = nil
        lock.unlock()
    }
}

enum LoginKeychainResidue {
    private static let service = appId

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }
}
