import Foundation

enum AppError: Error, Sendable {
    case cancelled
    case emptyPassword
    case incorrectPassword
    case passwordRequestInProgress
    case timeout(String)
    case missingTool(String)
    case ntfs3gMissing
    case invalidPath
    case invalidName
    case formatNotAllowed
    case failed(String)
    case coded(String)

    var code: String? {
        if case .coded(let value) = self { return value }
        return nil
    }
}

extension AppError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .cancelled: return L10n.t("messages.passwordDialog.userCancelled")
        case .emptyPassword: return L10n.t("messages.passwordDialog.passwordEmpty")
        case .incorrectPassword: return L10n.t("messages.passwordError")
        case .passwordRequestInProgress: return "已有密码验证请求正在等待处理"
        case .timeout(let message): return message
        case .missingTool(let name): return name
        case .ntfs3gMissing: return "未找到 ntfs-3g，请先安装依赖"
        case .invalidPath: return L10n.t("messages.repairDeviceUnavailable")
        case .invalidName: return L10n.t("messages.renameInvalidName")
        case .formatNotAllowed: return L10n.t("messages.formatNotAllowed")
        case .failed(let message): return message
        case .coded(let code): return code
        }
    }
}

enum PasswordError {
    static func isIncorrect(_ message: String) -> Bool {
        let n = message.lowercased()
        return [
            "密码错误", "密码不正确", "password is incorrect", "sorry, try again",
            "incorrect password", "wrong password", "authentication failure",
            "authentication failed", "パスワードが間違っています"
        ].contains { n.contains($0.lowercased()) }
    }

    static func isCancelled(_ message: String) -> Bool {
        let n = message.lowercased()
        return ["user canceled", "user cancelled", "用户取消", "キャンセル", "cancel"].contains { n.contains($0) }
    }
}
