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
        var restoreRO: [Item] = []
        var eject: [Item] = []
        var unmount: [Item] = []
        var mount: [Item] = []
    }

    enum Kind: Equatable, Sendable {
        case format(names: [String])
        case remountReadWrite(names: [String])
        case restoreReadOnly(names: [String])
        case eject(names: [String])
        case unmount(names: [String])
        case mount(names: [String])
    }

    /// 格式化压过推出：更长、更危险。推出压过挂载切换：卡片会从列表消失，空表还得靠这句转圈。
    /// 只读转读写压过读写转只读。挂载切换压过卸载/挂载。
    static func kind(_ session: Session) -> Kind? {
        if let names = named(session.format) {
            return .format(names: names)
        }
        if let names = named(session.eject) { return .eject(names: names) }
        if let names = named(session.remountRW) { return .remountReadWrite(names: names) }
        if let names = named(session.restoreRO) { return .restoreReadOnly(names: names) }
        if let names = named(session.unmount) { return .unmount(names: names) }
        if let names = named(session.mount) { return .mount(names: names) }
        return nil
    }

    static func text(_ kind: Kind?, t: (String, [String: String]) -> String) -> String? {
        switch kind {
        case .format(let names):
            if names.count == 1 {
                return t("messages.formattingHint", ["name": names[0]])
            }
            return t("messages.formattingHintMany", [
                "count": "\(names.count)",
                "names": names.joined(separator: t("messages.nameListSeparator", [:]))
            ])
        case .remountReadWrite(let names):
            return namedText(names, one: "messages.remountingReadWrite", many: "messages.remountingReadWriteMany", t: t)
        case .restoreReadOnly(let names):
            return namedText(names, one: "messages.restoringReadOnly", many: "messages.restoringReadOnlyMany", t: t)
        case .eject(let names):
            return namedText(names, one: "messages.ejecting", many: "messages.ejectingMany", t: t)
        case .unmount(let names):
            return namedText(names, one: "messages.unmounting", many: "messages.unmountingMany", t: t)
        case .mount(let names):
            return namedText(names, one: "messages.mounting", many: "messages.mountingMany", t: t)
        case nil:
            return nil
        }
    }

    static func remountItem(from device: NTFSDevice) -> Item? {
        guard device.isMounted, device.isReadOnly, !device.isUnmounted else { return nil }
        return namedItem(from: device)
    }

    static func remountItems(from devices: [NTFSDevice]) -> [Item] {
        devices.compactMap(remountItem(from:))
    }

    static func restoreItem(from device: NTFSDevice) -> Item? {
        guard device.isReadWrite else { return nil }
        return namedItem(from: device)
    }

    static func restoreItems(from devices: [NTFSDevice]) -> [Item] {
        devices.compactMap(restoreItem(from:))
    }

    static func mountItem(from device: NTFSDevice) -> Item? {
        guard device.needsMount else { return nil }
        return namedItem(from: device)
    }

    static func mountItems(from devices: [NTFSDevice]) -> [Item] {
        devices.compactMap(mountItem(from:))
    }

    static func unmountItem(from device: NTFSDevice) -> Item? {
        guard !device.needsMount else { return nil }
        return namedItem(from: device)
    }

    static func unmountItems(from devices: [NTFSDevice]) -> [Item] {
        devices.compactMap(unmountItem(from:))
    }

    static func ejectItem(from device: NTFSDevice) -> Item {
        namedItem(from: device)
    }

    static func ejectItems(from devices: [NTFSDevice]) -> [Item] {
        devices.map(ejectItem(from:))
    }

    static func insertingFormat(_ session: Session, id: String, name: String) -> Session {
        inserting(session, Item(id: id, name: name), into: \.format)
    }

    static func insertingRemount(_ session: Session, _ item: Item) -> Session {
        inserting(session, item, into: \.remountRW)
    }

    static func insertingRemounts(_ session: Session, _ items: [Item]) -> Session {
        items.reduce(session, insertingRemount)
    }

    static func insertingRestore(_ session: Session, _ item: Item) -> Session {
        inserting(session, item, into: \.restoreRO)
    }

    static func insertingRestores(_ session: Session, _ items: [Item]) -> Session {
        items.reduce(session, insertingRestore)
    }

    static func insertingMount(_ session: Session, _ item: Item) -> Session {
        inserting(session, item, into: \.mount)
    }

    static func insertingMounts(_ session: Session, _ items: [Item]) -> Session {
        items.reduce(session, insertingMount)
    }

    static func insertingUnmount(_ session: Session, _ item: Item) -> Session {
        inserting(session, item, into: \.unmount)
    }

    static func insertingUnmounts(_ session: Session, _ items: [Item]) -> Session {
        items.reduce(session, insertingUnmount)
    }

    static func insertingEject(_ session: Session, _ item: Item) -> Session {
        inserting(session, item, into: \.eject)
    }

    static func insertingEjects(_ session: Session, _ items: [Item]) -> Session {
        items.reduce(session, insertingEject)
    }

    static func removingFormat(_ session: Session, id: String) -> Session {
        removing(session, id: id, from: \.format)
    }

    static func removingRemount(_ session: Session, id: String) -> Session {
        removing(session, id: id, from: \.remountRW)
    }

    static func removingRestore(_ session: Session, id: String) -> Session {
        removing(session, id: id, from: \.restoreRO)
    }

    static func removingMount(_ session: Session, id: String) -> Session {
        removing(session, id: id, from: \.mount)
    }

    static func removingUnmount(_ session: Session, id: String) -> Session {
        removing(session, id: id, from: \.unmount)
    }

    static func removingEject(_ session: Session, id: String) -> Session {
        removing(session, id: id, from: \.eject)
    }

    static func isFormatting(_ session: Session, id: String) -> Bool {
        session.format.contains { $0.id == id }
    }

    static func isFormatting(_ session: Session, parentDisk: String) -> Bool {
        session.format.contains { DiskSafety.parentDiskId($0.id) == DiskSafety.parentDiskId(parentDisk) }
    }

    static func removingDeviceAfterDisappearance(_ session: Session, id: String) -> Session {
        var session = removingRemount(session, id: id)
        session = removingRestore(session, id: id)
        session = removingMount(session, id: id)
        session = removingUnmount(session, id: id)
        session = removingEject(session, id: id)
        return isFormatting(session, id: id) ? session : removingFormat(session, id: id)
    }

    /// 卡片已经是读写，底部就不要再转圈。中间卸载、列表暂时缺这张卡时先留着。
    static func droppingFinishedRemounts(_ session: Session, devices: [NTFSDevice]) -> Session {
        droppingFinished(session, into: \.remountRW, devices: devices) { $0.isReadWrite }
    }

    /// 卡片已经是只读，底部就不要再转圈。中间卸载、列表暂时缺这张卡时先留着。
    static func droppingFinishedRestores(_ session: Session, devices: [NTFSDevice]) -> Session {
        droppingFinished(session, into: \.restoreRO, devices: devices) {
            $0.isMounted && $0.isReadOnly && !$0.isUnmounted
        }
    }

    /// 未挂载的卡已经挂上，底部就不要再转圈。列表暂时缺这张卡时先留着。
    static func droppingFinishedMounts(_ session: Session, devices: [NTFSDevice]) -> Session {
        droppingFinished(session, into: \.mount, devices: devices) { $0.isReadWrite }
    }

    /// 卡片已经卸下，底部就不要再转圈。列表暂时缺这张卡时先留着。
    static func droppingFinishedUnmounts(_ session: Session, devices: [NTFSDevice]) -> Session {
        droppingFinished(session, into: \.unmount, devices: devices) { $0.needsMount }
    }

    /// 卡片已经从列表消失，底部就不要再转圈。整表暂时空着（正在推出最后一块）时先留着。
    static func droppingFinishedEjects(_ session: Session, devices: [NTFSDevice]) -> Session {
        var session = session
        if devices.isEmpty { return session }
        session.eject.removeAll { item in
            !devices.contains { live in
                isSameProgressTarget(item, live, devices: devices)
            }
        }
        return session
    }

    /// 转读写过程中节点写法可能和会话里记下的不一致；卷名只在全表唯一时才用来对。
    private static func isSameProgressTarget(_ item: Item, _ device: NTFSDevice, devices: [NTFSDevice]) -> Bool {
        if device.devicePath == item.id || device.disk == item.id || "/dev/\(device.disk)" == item.id {
            return true
        }
        guard device.volumeName == item.name else { return false }
        return devices.filter { $0.volumeName == item.name }.count == 1
    }

    private static func namedItem(from device: NTFSDevice) -> Item {
        Item(id: device.devicePath, name: device.volumeName.isEmpty ? device.disk : device.volumeName)
    }

    private static func named(_ items: [Item]) -> [String]? {
        let names = items.map(\.name)
        return names.isEmpty ? nil : names
    }

    private static func namedText(
        _ names: [String],
        one: String,
        many: String,
        t: (String, [String: String]) -> String
    ) -> String {
        if names.count == 1 {
            return t(one, ["name": names[0]])
        }
        return t(many, [
            "count": "\(names.count)",
            "names": names.joined(separator: t("messages.nameListSeparator", [:]))
        ])
    }

    /// 同一 id 保持先到的位置，后到的同 id 不插第二份。
    private static func inserting(
        _ session: Session,
        _ item: Item,
        into keyPath: WritableKeyPath<Session, [Item]>
    ) -> Session {
        var session = session
        if session[keyPath: keyPath].contains(where: { $0.id == item.id }) { return session }
        session[keyPath: keyPath].append(item)
        return session
    }

    private static func removing(
        _ session: Session,
        id: String,
        from keyPath: WritableKeyPath<Session, [Item]>
    ) -> Session {
        var session = session
        session[keyPath: keyPath].removeAll { $0.id == id }
        return session
    }

    private static func droppingFinished(
        _ session: Session,
        into keyPath: WritableKeyPath<Session, [Item]>,
        devices: [NTFSDevice],
        done: (NTFSDevice) -> Bool
    ) -> Session {
        var session = session
        session[keyPath: keyPath].removeAll { item in
            devices.contains { live in
                done(live) && isSameProgressTarget(item, live, devices: devices)
            }
        }
        return session
    }
}
