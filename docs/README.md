# Nigate 文档

Nigate 是原生 Swift/SwiftUI macOS 应用，最低支持 macOS 14。仓库只有根目录 `Package.swift` 一个 Swift Package Manager 入口，应用源码位于 `macos/Sources/Nigate`。

## 本地构建

在仓库根目录执行：

```sh
swift test
swift build
./dev.sh
./macos/Scripts/dev.sh
./macos/Scripts/build.sh
```

`build.sh` 只生成本地 `dist/Nigate.app` 并进行临时签名，不提供公证或正式发布流程。

## 安全边界

- 格式化是不可逆的数据销毁操作。
- 只有在设备信息完整、明确为外置物理整盘、不是启动盘且没有任何负面安全标记时才允许格式化。
- 内置盘、虚拟盘、磁盘映像、分区、设备类型未知、信息缺失或验证失败的目标一律拒绝。
- `ntfsfix` 只能处理有限的 NTFS 问题，不能替代 Windows `chkdsk`。
- 读写挂载依赖 MacFUSE 与 `ntfs-3g`，真实设备操作需要硬件集成测试。

## 运行时结构

```text
Domain        纯数据模型与磁盘安全策略
Infra         Shell、提权、路径、Keychain、设置等系统适配
NTFS          扫描、监控、挂载、修复、格式化与依赖服务
App           SwiftUI 应用状态、生命周期与菜单栏协调
UI            SwiftUI 页面、弹窗和交互
Tests         磁盘安全与自动挂载决策测试
```

应用内帮助位于 `macos/Sources/Nigate/Resources/Help`，本文件只描述当前 Swift 工程，不保留历史运行时或旧安装绕过指南。
