# Nigate

**语言 / Language / 言語**: [简体中文](README.zh-CN.md) | [English](README.md) | [日本語](README.ja.md)

Nigate 是使用 Swift 与 SwiftUI 构建的原生 macOS NTFS 管理应用。仓库仅保留根目录的 Swift Package Manager 工程入口，不再包含可运行的 Electron/Node 应用。

## 功能

- 扫描已挂载和未挂载的 NTFS 卷，显示挂载状态与容量。
- 以读写模式挂载 NTFS 卷，恢复只读挂载、卸载或推出设备。
- 使用 `ntfsfix` 修复、重命名卷标，并管理自动挂载。
- 可选择将管理员密码保存在 macOS 钥匙串中。
- 提供依赖检查、菜单栏模式、登录时启动、防止睡眠和多语言设置。
- 仅允许格式化已验证的外置物理整盘；格式化会清除整盘及其分区。

## 环境要求

- macOS 14 或更高版本。
- 从源码构建需要 Swift 6 工具链。
- NTFS 读写挂载需要 MacFUSE 和 `ntfs-3g`（可通过 Homebrew 安装）；`fswatch` 为可选依赖。

应用内的依赖安装器会打开终端，并可安装 Xcode Command Line Tools、Homebrew、MacFUSE 和 `ntfs-3g`。macOS 可能要求在“系统设置”中批准文件系统扩展并重新启动。安装器不会关闭 Gatekeeper，也不会修改全局系统安全设置。

## 构建与运行

以下命令均在仓库根目录执行：

```sh
swift test
swift build
./dev.sh
```

唯一 SwiftPM 入口为 `Package.swift`，应用源码位于 `macos/Sources/Nigate`。另一个等价开发启动脚本是 `./macos/Scripts/dev.sh`。如需在 `dist/Nigate.app` 生成本地 `.app` 包：

```sh
./macos/Scripts/build.sh          # Release
./macos/Scripts/build.sh debug    # Debug
```

构建脚本仅生成本地临时签名的应用包，不提供公证或正式发布打包流程。

## 安全边界与限制

- **格式化会销毁数据。** 只有在完整确认目标为外置、物理整盘且不是启动盘时才允许执行。内置盘、虚拟盘、磁盘映像、分区目标、设备信息未知或不完整、带有负面安全标记的目标一律拒绝。格式化前请备份整块磁盘。
- **NTFS 修复仅为尽力而为。** `ntfsfix` 只能处理有限的 NTFS 问题，不能替代 Windows `chkdsk`。
- **读写挂载依赖 `ntfs-3g`。** 兼容性和数据完整性受设备、文件系统状态以及 macFUSE/驱动版本影响，请保留备份。Windows 快速启动或休眠状态下的卷可能无法安全挂载。
- 当前测试覆盖磁盘格式化安全判断和自动挂载决策；真实设备挂载、修复、格式化尚未纳入硬件集成测试。
- 仓库提供本地构建流程，不包含正式签名与公证发布流水线。

## 许可证

请参阅 [LICENSE](LICENSE) 和 [ACKNOWLEDGMENTS.md](ACKNOWLEDGMENTS.md)。
