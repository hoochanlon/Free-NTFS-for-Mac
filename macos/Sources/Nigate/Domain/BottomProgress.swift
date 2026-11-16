import Foundation

/// 窗口底部的长提示。多个操作同时进行时按优先级合成一句，不能互相覆盖成空白。
enum BottomProgress {
    struct Item: Equatable, Sendable {
        var id: String
        var name: String
    }

    struct Session: Equatable, Sendable {
        var format: [Item] = []
        var remountRW: [Item] = []
    }

    enum Kind: Equatable, Sendable {
        case format(name: String)
        case remountReadWrite(names: [String])
    }

    /// 格式化压过只读转读写：格式化更长、更危险。
    static func kind(_ session: Session) -> Kind? {
        if let name = session.format.first?.name {
            return .format(name: name)
        }
        let names = session.remountRW.map(\.name)
        if names.isEmpty { return nil }
        return .remountReadWrite(names: names)
    }

    static func text(_ kind: Kind?, t: (String, [String: String]) -> String) -> String? {
        switch kind {
        case .format(let name):
            return t("messages.formattingHint", ["name": name])
        case .remountReadWrite(let names) where names.count == 1:
            return t("messages.remountingReadWrite", ["name": names[0]])
        case .remountReadWrite(let names):
            return t("messages.remountingReadWriteMany", [
                "count": "\(names.count)",
                "names": names.joined(separator: t("messages.nameListSeparator", [:]))
            ])
        case nil:
            return nil
        }
    }

    static func remountItem(from device: NTFSDevice) -> Item? {
        guard device.isMounted, device.isReadOnly, !device.isUnmounted else { return nil }
        let name = device.volumeName.isEmpty ? device.disk : device.volumeName
        return Item(id: device.devicePath, name: name)
    }

    static func remountItems(from devices: [NTFSDevice]) -> [Item] {
        devices.compactMap(remountItem(from:))
    }

    static func insertingFormat(_ session: Session, id: String, name: String) -> Session {
        inserting(session.format, id: id, name: name) { next in
            var session = session
            session.format = next
            return session
        }
    }

    static func insertingRemount(_ session: Session, _ item: Item) -> Session {
        inserting(session.remountRW, id: item.id, name: item.name) { next in
            var session = session
            session.remountRW = next
            return session
        }
    }

    static func insertingRemounts(_ session: Session, _ items: [Item]) -> Session {
        items.reduce(session, insertingRemount)
    }

    static func removingFormat(_ session: Session, id: String) -> Session {
        var session = session
        session.format.removeAll { $0.id == id }
        return session
    }

    static func removingRemount(_ session: Session, id: String) -> Session {
        var session = session
        session.remountRW.removeAll { $0.id == id }
        return session
    }

    /// 卡片已经是读写，底部就不要再转圈。中间卸载、列表暂时缺这张卡时先留着。
    static func droppingFinishedRemounts(_ session: Session, devices: [NTFSDevice]) -> Session {
        var session = session
        session.remountRW.removeAll { item in
            devices.contains { live in
                live.isReadWrite && isSameRemountTarget(item, live)
            }
        }
        return session
    }

    /// 转读写过程中节点写法可能和会话里记下的不一致，路径、盘号、卷名任一能对上即可。
    private static func isSameRemountTarget(_ item: Item, _ device: NTFSDevice) -> Bool {
        device.devicePath == item.id
            || device.disk == item.id
            || "/dev/\(device.disk)" == item.id
            || device.volumeName == item.name
    }

    /// 同一 id 保持先到的位置，后到的同 id 不插第二份。
    private static func inserting(
        _ items: [Item],
        id: String,
        name: String,
        update: ([Item]) -> Session
    ) -> Session {
        if items.contains(where: { $0.id == id }) { return update(items) }
        return update(items + [Item(id: id, name: name)])
    }
}
