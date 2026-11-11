# Nigate

**语言 / Language / 言語**: [简体中文](README.zh-CN.md) | [English](README.md) | [日本語](README.ja.md)

快速开始：从 [发布标签](https://github.com/hoochanlon/Free-NTFS-for-Mac/tags) 下载并使用。

![](https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/src/imgs/example/demo.gif)

演示界面为 1.5.4 以下版本，界面随功能增强可能略有变化。

## 功能特性

- 🎨 **现代化界面**：采用简洁美观的深色主题
- 📱 **实时监控**：自动检测 NTFS 设备连接
- ✅ **依赖检查**：自动检查并安装所需的系统依赖
- 🔄 **一键挂载**：轻松将只读 NTFS 设备挂载为读写模式
- ⚡ **自动读写**：启用后，新接入的 NTFS 设备会自动以读写模式挂载；对于手动设置为只读的设备会智能跳过，尊重用户选择
- 📊 **状态显示**：清晰显示设备状态和操作日志
- ☕ **防止休眠**：一键阻止系统休眠，确保长时间操作期间系统保持唤醒
- 🍃 **状态保护**：长按 3 秒切换保护状态。启用保护后，自动读写、托盘模式和防止休眠功能将被禁用，以避免误操作
- **🌍 应用界面支持多种语言**：简体中文、繁体中文、日语、英语、德语等

## 重要说明

> [!CAUTION]
> 本软件的稳定运行和数据完整性取决于存储设备的性能。为避免数据读写错误、传输中断或设备识别失败，建议使用采用高质量闪存芯片且读写性能可靠的 USB 存储设备。

> [!important]
> **读写说明**：
> - **基本操作**：支持文件复制、剪切、删除和重命名等操作（元数据级操作）
> - **编辑与保存**：GUI 会以读写模式挂载 NTFS 卷，并将文件所有者映射到当前 macOS 用户的 `uid` / `gid`。在已测试的配置中，文本和图片可以编辑并保存；但兼容性可能因编辑器和具体保存操作而异
> - **保存失败时**：请提前备份重要数据。可将文件复制到 Mac 本地编辑，再复制回设备。通过临时文件创建并重命名替换的编辑器在某些情况下可能有帮助，但不能保证绕过所有限制

- **管理员权限**：挂载操作需要管理员权限，系统会提示输入密码
- **Windows 快速启动**：如果设备曾在启用快速启动的 Windows 系统中使用，挂载可能失败。建议在 Windows 中完全关机（而非休眠），或关闭快速启动
- **设备名称**：USB 存储设备名称不支持空格和非法字符
- **Gatekeeper（允许任何来源）**：首次运行未签名应用时，可能需要调整 Gatekeeper 设置。可在终端运行 `sudo spctl --master-disable`；调整后，可在“系统设置”>“隐私与安全性”中查看“任何来源”选项
- **系统完整性保护（SIP，可选）**：如需关闭 SIP，必须进入 macOS 恢复模式：
  1. 重启 Mac，按住电源按钮，直到出现 Apple 标志和进度条，然后进入恢复模式
  2. 在屏幕顶部工具栏中打开“终端”，运行 `csrutil disable`
  3. 关闭终端并重启 Mac
  4. 重启后可在终端运行 `csrutil status` 查看状态
- **可启动 USB 设备**：如果 USB 设备曾用于制作 Ventoy、微 PE 等启动介质，以读写模式挂载时可能需要等待一段时间

## 运行与开发

### 运行已发布版本

从 [发布标签](https://github.com/hoochanlon/Free-NTFS-for-Mac/tags) 下载最新版本的应用，并将 `Nigate.app` 拖入“应用程序”目录后运行。

首次启动未签名或临时签名的应用时，macOS 可能需要在“系统设置”>“隐私与安全性”中允许打开。挂载操作需要管理员权限；读写挂载还需要 MacFUSE 和 `ntfs-3g`，应用会在依赖页面中显示检查与安装状态。

### 从源码运行

环境要求：

- macOS 14 或更高版本
- Swift 6 兼容的 Swift Package Manager 工具链
- 真实设备测试需要 MacFUSE、`ntfs-3g` 和可测试的 NTFS 存储设备

在仓库根目录执行：

```sh
git clone https://github.com/hoochanlon/Free-NTFS-for-Mac.git
cd Free-NTFS-for-Mac
swift test
./dev.sh
```

`./dev.sh` 和 `./macos/Scripts/dev.sh` 都会通过 Swift Package Manager 启动 Nigate；后者适合从 `macos/Scripts` 目录附近直接调用。首次运行会创建 `.build` 目录。

### 构建应用包

默认构建 Release 版本，并将临时签名的应用输出到 `dist/Nigate.app`：

```sh
swift test
./macos/Scripts/build.sh
open dist/Nigate.app
```

构建 Debug 版本：

```sh
./macos/Scripts/build.sh debug
open dist/Nigate.app
```

`build.sh` 会复制 `Info.plist`、应用图标和 Swift Package 资源，并执行本地 ad-hoc 签名。它不会自动完成 Developer ID 签名、公证或发布；正式发布需要自行配置 Apple Developer 证书和公证凭据。

如果已经配置好 `notarytool` 的钥匙串配置文件，可以使用以下变量启用正式签名和公证：

```sh
DEVELOPER_ID_APPLICATION="Developer ID Application: Example" \
NOTARY_PROFILE="your-notary-profile" \
NOTARIZE=1 \
./macos/Scripts/build.sh
```

### 打包 DMG

使用专用脚本构建 Release 应用并生成 DMG：

```sh
./macos/Scripts/package-dmg.sh
open dist/Nigate-1.6.0.dmg
```

构建 Debug 版本的 DMG：

```sh
./macos/Scripts/package-dmg.sh debug
```

脚本会先调用 `build.sh` 构建 `Nigate.app`，再将应用、`dmg-assets` 中的安装说明和辅助脚本，以及指向“应用程序”目录的快捷方式放入 DMG。输出文件名会根据 `macos/Info.plist` 中的版本号生成，例如 `dist/Nigate-1.6.0.dmg`。

默认生成的是本地开发用 DMG。正式分发时，应传入 Developer ID 签名和公证配置；这些环境变量会被打包脚本传递给应用构建流程：

```sh
DEVELOPER_ID_APPLICATION="Developer ID Application: Example" \
NOTARY_PROFILE="your-notary-profile" \
NOTARIZE=1 \
./macos/Scripts/package-dmg.sh
```

DMG 布局资源位于 `dmg-assets`，可以直接修改其中的安装说明或辅助文件；脚本每次打包时都会将该目录内容复制到 DMG 根目录。

### 项目结构

```text
Package.swift                         Swift Package Manager 入口
macos/Sources/Nigate/Domain            数据模型与磁盘安全策略
macos/Sources/Nigate/Infra             Shell、提权、路径、Keychain 和设置适配
macos/Sources/Nigate/NTFS              扫描、监控、挂载、修复和依赖服务
macos/Sources/Nigate/App               应用状态、生命周期和菜单栏协调
macos/Sources/Nigate/UI                SwiftUI 页面、弹窗和交互
macos/Sources/Nigate/Resources         帮助文档、语言资源和应用图标
Tests/NigateTests                      磁盘安全与自动挂载决策测试
docs/README.md                         工程结构与安全边界说明
```

提交修改前建议至少执行 `swift test` 和 `swift build`。涉及真实磁盘的功能应在测试设备和已备份数据上验证；格式化是不可逆操作，`ntfsfix` 也不能替代 Windows 的 `chkdsk`。

## 致谢

感谢所有为本项目贡献代码、测试和反馈的开发者与用户！详情请参阅 [致谢名单](ACKNOWLEDGMENTS.md)。
