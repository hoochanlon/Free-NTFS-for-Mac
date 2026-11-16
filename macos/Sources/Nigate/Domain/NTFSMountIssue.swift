import Foundation

/// ntfs-3g / ntfslabel 把 Windows 脏卷、休眠、未安全弹出打成英文 stderr。
/// 识别后走 recover 或本地化提示，不能把原文弹给用户。
enum NTFSMountIssue {
    static func isUnclean(_ text: String) -> Bool {
        let n = text.lowercased()
        return n.contains("unclean file system")
            || n.contains("wasn't safely closed")
            || n.contains("was not safely closed")
            || n.contains("scheduled for check")
            || n.contains("volume is dirty")
            || n.contains("dirty volume")
            || n.contains("hibernat")
            || n.contains("unsafe state")
            || n.contains("windows cache")
    }

    static func isUnclean(_ error: Error) -> Bool {
        if let app = error as? AppError {
            switch app {
            case .uncleanVolume:
                return true
            case .failed(let message), .timeout(let message):
                return isUnclean(message)
            default:
                break
            }
        }
        return isUnclean(error.localizedDescription)
    }

    static func mapped(_ error: Error) -> Error {
        isUnclean(error) ? AppError.uncleanVolume : error
    }
}
