import Foundation
import Security

/// 默认钥匙串 ACL 带 `unsigned` 提示。ad-hoc 签名每次读取都会弹登录钥匙串密码。
/// 「始终允许」绑的是当前二进制 cdhash，下一轮读取或退出重开仍会再问。
enum KeychainAccessPolicy {
    static func shouldRewritePromptSelector(_ selector: SecKeychainPromptSelector) -> Bool {
        !selector.isEmpty
    }
}

enum KeychainStore {
    private static let service = appId
    private static let lock = NSLock()
    nonisolated(unsafe) private static var memory: String?

    static func save(_ password: String) throws {
        remember(password)
        guard let access = makeSilentAccess() else {
            throw AppError.failed("保存密码失败")
        }
        deleteItem()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: service,
            kSecAttrLabel as String: "Nigate",
            kSecAttrAccess as String: access,
            kSecValueData as String: Data(password.utf8)
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AppError.failed("保存密码失败")
        }
    }

    static func read() -> String? {
        if let cached = remembered() { return cached }
        guard let password = copyFromKeychain() else { return nil }
        remember(password)
        return password
    }

    static func delete() {
        remember(nil)
        deleteItem()
    }

    static func hasPassword() -> Bool { read() != nil }

    private static func remembered() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return memory
    }

    private static func remember(_ password: String?) {
        lock.lock()
        memory = password
        lock.unlock()
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: service
        ]
    }

    private static func deleteItem() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private static func copyFromKeychain() -> String? {
        var item: CFTypeRef?
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecReturnRef as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }

        let data: Data
        let keychainItem: SecKeychainItem?
        if let dict = item as? [String: Any] {
            guard let value = dict[kSecValueData as String] as? Data else { return nil }
            data = value
            keychainItem = dict[kSecValueRef as String].flatMap(asKeychainItem)
        } else if let value = item as? Data {
            data = value
            keychainItem = nil
        } else {
            return nil
        }

        guard let password = String(data: data, encoding: .utf8), !password.isEmpty else { return nil }
        if let keychainItem {
            silenceExistingItem(keychainItem, password: password)
        }
        return password
    }

    private static func asKeychainItem(_ value: Any) -> SecKeychainItem? {
        let cf = value as CFTypeRef
        guard CFGetTypeID(cf) == SecKeychainItemGetTypeID() else { return nil }
        return (cf as! SecKeychainItem)
    }

    /// 旧条目仍带着 unsigned 提示。刚读到明文后把 ACL 改成当前应用、不再弹窗。
    private static func silenceExistingItem(_ item: SecKeychainItem, password: String) {
        var access: SecAccess?
        if SecKeychainItemCopyAccess(item, &access) == errSecSuccess, let access {
            if !accessNeedsRewrite(access) { return }
            silencePrompts(in: access)
            if SecKeychainItemSetAccess(item, access) == errSecSuccess { return }
        }
        try? save(password)
    }

    private static func makeSilentAccess() -> SecAccess? {
        var trusted: SecTrustedApplication?
        guard SecTrustedApplicationCreateFromPath(nil, &trusted) == errSecSuccess,
              let trusted else { return nil }
        let apps = [trusted] as CFArray
        var access: SecAccess?
        guard SecAccessCreate("Nigate" as CFString, apps, &access) == errSecSuccess,
              let access else { return nil }
        silencePrompts(in: access, trustedApps: apps)
        return access
    }

    private static func accessNeedsRewrite(_ access: SecAccess) -> Bool {
        var list: CFArray?
        guard SecAccessCopyACLList(access, &list) == errSecSuccess,
              let acls = list as? [SecACL] else { return true }
        for acl in acls {
            var apps: CFArray?
            var description: CFString?
            var selector = SecKeychainPromptSelector()
            guard SecACLCopyContents(acl, &apps, &description, &selector) == errSecSuccess else { continue }
            if KeychainAccessPolicy.shouldRewritePromptSelector(selector) { return true }
        }
        return false
    }

    private static func silencePrompts(in access: SecAccess, trustedApps: CFArray? = nil) {
        var list: CFArray?
        guard SecAccessCopyACLList(access, &list) == errSecSuccess,
              let acls = list as? [SecACL] else { return }
        for acl in acls {
            var apps: CFArray?
            var description: CFString?
            var selector = SecKeychainPromptSelector()
            guard SecACLCopyContents(acl, &apps, &description, &selector) == errSecSuccess else { continue }
            guard KeychainAccessPolicy.shouldRewritePromptSelector(selector) else { continue }
            let desc = description ?? ("Nigate" as CFString)
            _ = SecACLSetContents(acl, trustedApps ?? apps, desc, [])
        }
    }
}
