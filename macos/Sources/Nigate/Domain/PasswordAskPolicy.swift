import Foundation

enum PasswordAskDecision: Equatable {
    case useRemembered(String)
    case prompt
}

/// 无 Developer ID 时，登录钥匙串会按当前二进制提问。
/// 管理员密码只留在本次进程：开着「记住」且内存里有值才自动用，否则弹窗。
enum PasswordAskPolicy {
    static func decide(savePassword: Bool, remembered: String?) -> PasswordAskDecision {
        guard savePassword, let remembered, !remembered.isEmpty else { return .prompt }
        return .useRemembered(remembered)
    }
}
