# Nigate

**语言 / Language / 言語**: [简体中文](README.md) | [English](README.en.md) | [日本語](README.ja.md)

快速开始：从 [发布标签](https://github.com/hoochanlon/Free-NTFS-for-Mac/tags) 下载并使用。

![](./demo.gif)

演示界面为 1.6.1 以下版本，界面随功能增强可能略有变化。

## 功能

- SwiftUI：实时检测 NTFS 设备、依赖检查、一键挂载、自动读写、状态日志、防止休眠、安全保护锁
- 多语言界面：简体/繁体中文、日语、英语、德语等
- **双挂载后端**
  - **ntfs-3g（默认 / 兼容）**：MacFUSE + `ntfs-3g`，面向大多数用户与未签名构建的主路径
  - **FSKit（可选 / 原生）**：内嵌 NTFS 引擎的 Nigate FSKit 扩展；在 **设置 → 挂载后端** 中切换

## 挂载后端

| 后端 | 条件 | 说明 |
| --- | --- | --- |
| ntfs-3g | MacFUSE、`ntfs-3g` | 默认。ad-hoc / 本地构建可用。 |
| FSKit | macOS 15.4+，扩展已安装并启用 | 可选。失败时**不会**静默降级到 ntfs-3g。 |

启用 FSKit：

1. 构建并安装 `Nigate.app` 到 `/Applications`（`./macos/Scripts/build.sh`），扩展位于 `Contents/Extensions`
2. **无 Apple 代码签名证书时**，「系统设置 → 文件系统扩展」**通常不会列出 Nigate**（ad-hoc 会被设置页过滤；`pluginkit` 仍可能已注册）
3. 确认注册：`pluginkit -m -v -p com.apple.fskit.fsmodule | grep -i nigate`
4. 具备 Developer ID / Development Team 正式签名后，设置页才可能出现并可启用；应用内再将 **挂载后端** 设为 **FSKit（原生）**

程序化 `FSClient.mountSingleVolume` 需要带 `com.apple.developer.fskit.mount` 的可信签名。无签名身份时，请继续以 **ntfs-3g** 为主路径。

## 其他基于 FSKit 的 NTFS 软件

同类软件会越来越多，差别主要在 UI 和体验。清单整理自 [#68](https://github.com/hoochanlon/Free-NTFS-for-Mac/issues/68)，后续不再逐一录入。

| 名称 | 价格 | 链接 |
| --- | --- | --- |
| xntfs | App Store 8 元 | https://github.com/HuanchuanTech/xntfs |
| NTFS Explorer Pro | App Store 68 元 | https://appagg.com/macos/utilities/ntfs-explorer-pro-43459914.html |
| ttntfs | 免费 | https://github.com/dr-kbadawi/ttntfs |
| LightNTFS Beta | 免费 | https://macadmin.hu/#apps |
| 盘屿 (volisle) | 免费 | https://github.com/qsw745/volisle |
| ntfskit | 需编译，免费开源 | https://github.com/whereteam/ntfskit |

另有一条虚拟机中转路径：[anylinuxfs](https://github.com/nohajc/anylinuxfs)，以及它的 GUI 封装 [anylinuxfs-gui](https://github.com/fenio/anylinuxfs-gui)、[ntfsmac](https://github.com/khr898/ntfsmac)。

## 技术对比

整理自 [#68](https://github.com/hoochanlon/Free-NTFS-for-Mac/issues/68)。Nigate 默认走第一代兼容路径，macOS 15.4+ 可选用第三代 FSKit。

| 对比维度 | 第一代（FUSE + NTFS-3G） | 第二代（商用内核驱动 kext） | 第三代（用户态 FSKit） |
| --- | --- | --- | --- |
| 性能速度 | 较低 | 极高 | 高（接近第二代，差距持续缩小） |
| 稳定性 | 较差 | 极高 | 高（未来兼容性更优） |
| 安全性 | 中等 | 中低（权限过高） | 极高 |
| 安装门槛 | 较高（需安装 FUSE） | 中等（需手动允许扩展） | 极低（即装即用） |
| macOS 兼容性 | 差 | 良好（需及时适配） | 优秀（苹果推荐架构） |
| 大文件传输 | 易中断 | 稳定 | 稳定 |
| 代表软件 / 技术 | NTFS-3G、部分免费软件 | Paragon、Tuxera、赤友 NTFS 助手 | xntfs、ttntfs、赤友 NTFS 助手 |

## 重要说明

> [!important]
> 稳定性取决于存储设备，请使用可靠的 USB 介质。

- 挂载需要管理员权限。
- Windows 快速启动或休眠会把 NTFS 留在未完成状态。`ntfs-3g` 检测到休眠标记后会**强制只读**，避免 Windows 恢复时用过时缓存覆盖写入、损坏分区。请先在 Windows 上**完全关机**（不要休眠 / 快速启动），再接入 Mac。说明见 [#68](https://github.com/hoochanlon/Free-NTFS-for-Mac/issues/68)。
- FUSE + `ntfs-3g` 走用户态，读写通常慢于内核方案，大文件也可能更容易中断；它被长期使用，主要是宁可只读、也不把卷写坏。默认后端走这条兼容路径；macOS 15.4+ 可在设置中改用 FSKit。
- 未签名应用可能被 Gatekeeper 拦截，请在 **隐私与安全性** 中按应用放行，勿全局关闭 Gatekeeper。
- 格式化不可逆；`ntfsfix` 不能替代 Windows `chkdsk`。

## 运行与构建

**发布版**：从 [标签](https://github.com/hoochanlon/Free-NTFS-for-Mac/tags) 下载，将 `Nigate.app` 移入「应用程序」。

**源码运行**（macOS 14+，Swift 6 工具链）：

```sh
git clone https://github.com/hoochanlon/Free-NTFS-for-Mac.git
cd Free-NTFS-for-Mac
swift test
swift run Nigate
./dev.sh
```

**应用包 / DMG**：

```sh
./macos/Scripts/build.sh          # → dist/Nigate.app（ad-hoc 签名）
./macos/Scripts/package-dmg.sh    # → dist/Nigate-1.6.3.dmg
```

可选 Developer ID + 公证：

```sh
DEVELOPER_ID_APPLICATION="Developer ID Application: Example" \
NOTARY_PROFILE="your-notary-profile" \
NOTARIZE=1 \
./macos/Scripts/build.sh
```

## 目录结构

```text
Package.swift
macos/Sources/Nigate/              主应用（Domain / Infra / NTFS / App / UI）
macos/Sources/NigateFSKitCore/     FSKit 身份与挂载后端策略
macos/Sources/NigateFSKitExtension/ FSKit 数据面（appex）
macos/Sources/NigateNTFSEngine/    扩展内静态链接的 NTFS 引擎
Tests/NigateTests/
docs/README.md
```

## 致谢

如果 Nigate 对你有帮助，欢迎扫码打赏：

<p align="center">
  <img src="buy%20coffee/zanshangma.jpg" alt="赞赏码" width="240">
</p>

感谢所有贡献者。详见 [ACKNOWLEDGMENTS.md](ACKNOWLEDGMENTS.md)。
