# Nigate

**Language / 言語 / 语言**: [English](README.md) | [日本語](README.ja.md) | [中文](README.cn.md)

## 中文

这是 Nigate 的 Electron 图形界面版本，在保留原有极客终端版本的同时，提供了现代化、直观的操作界面，让 NTFS 设备管理更加简单便捷。[^1]

## 功能特性

- 🎨 **现代化界面** - 采用深色主题，界面简洁美观
- 📱 **实时监控** - 自动检测 NTFS 设备接入
- ✅ **依赖检查** - 自动检查并安装所需系统依赖
- 🔄 **一键挂载** - 轻松将只读 NTFS 设备挂载为读写模式
- ⚡ **自动读写** - 启用后，新插入的 NTFS 设备会自动挂载为读写模式，无需手动操作。智能跳过您手动设置为只读的设备，尊重您的选择
- 📊 **状态显示** - 清晰显示设备状态和操作日志
- 🛡️ **安全可靠** - 使用 Electron 安全最佳实践，并提供非格式化的磁盘修复“重置”按钮
- ☕ **禁止休眠** - 一键开启/关闭系统休眠防止功能，确保长时间操作时系统保持唤醒状态
- 🍃 **状态保护** - 长按3s可切换保护状态，保护后自动读写、托盘模式和防止休眠功能将被禁用，防止误操作
- 🥷 **忍者工具集** - 提供跨文件系统挂载、覆盖开发到发布的全流程脚本支持，并通过一键权限修复与多语言输出，简化复杂操作、降低使用门槛
- 💻 **Arm & Intel Mac 支持** - 完整支持 Apple 芯片（arm64）与 Intel 芯片的 Mac（x64 架构）

## 注意事项

> [!important]
> **读写说明**：
>  - 基础操作：支持文件的复制、剪切、删除、重命名（元数据级操作）
>  - 写入限制：图形化软件（Electron GUI 版本）由于缺乏内核写权限，不支持直接在原文件上"涂改"数据
>  - 编辑建议：请使用支持原子写入 (Atomic Write) 的编辑器（如 VS Code / Kate）。这类工具保存时会"新建并替换"旧文件，从而绕过原位擦写限制。另外，推荐将文件拷贝到本机进行数据编辑，编辑完成后再拷贝回去
>  - 补充说明：忍者工具集 `/ninja/kamui.sh` 支持在原文件上"涂改"数据，适用于直接修改文件的场景 [^2]

- **管理员权限**：挂载操作需要管理员权限，系统会提示输入密码
- **Windows 快速启动**：如果设备在 Windows 中使用了快速启动功能，可能导致挂载失败。建议在 Windows 中完全关闭（而非休眠），或禁用快速启动功能
- **设备名称**：U盘名称不支持空格与非法字符
- **Gatekeeper（允许任何来源）**：首次使用可能需要禁用 Gatekeeper 以允许运行未签名的应用。在终端运行：`sudo spctl --master-disable`。禁用后可在「系统设置」>「隐私与安全性」中看到「任何来源」选项
- **系统完整性保护（SIP）**（可选）：如需禁用 SIP，需要在恢复模式下操作：
  1. 重启 Mac，按住电源键直到屏幕上出现苹果的标志和进度条，进入 Recovery 模式
  2. 在屏幕上方的工具栏找到并打开终端，输入命令：`csrutil disable`
  3. 关掉终端，重启 Mac
  4. 重启以后可以在终端中运行 `csrutil status` 查看状态确认
- **启动盘设备**：如果 U 盘曾制作过 Ventoy、微PE 等启动盘，在挂载为读写模式时可能需要等待一段时间

## 快速开始（Shell - 忍者工具集）

以下脚本来自 `ninja/` 文件夹的忍者工具集，提供命令行方式的 NTFS 和 Linux 文件系统读写支持。

**🌍 所有脚本都支持多语言！** 使用 `LANG=ja` 或 `LANG=en` 设置语言。

### 在线体验

#### NTFS 读写支持

复制粘贴到 ***完全管理权限的终端*** 回车，一键起飞：

```shell
# 中文（默认）
/bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@refs/heads/main/ninja/nigate.sh)"

# 日文
LANG=ja /bin/bash -c "$(curl -fsSL https://cdn.statically.io/gh/hoochanlon/Free-NTFS-for-Mac/main/ninja/nigate.sh)"

# 英文
LANG=en /bin/bash -c "$(curl -fsSL https://cdn.statically.io/gh/hoochanlon/Free-NTFS-for-Mac/main/ninja/nigate.sh)"
```

#### Linux ext4 等文件系统读写支持

支持 ext2/3/4、btrfs、xfs、zfs、NTFS、exFAT、LUKS 加密、LVM、RAID 等多种文件系统：

```shell
# 中文（默认）
/bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@refs/heads/main/ninja/kamui.sh)"

# 日文
LANG=ja /bin/bash -c "$(curl -fsSL https://cdn.statically.io/gh/hoochanlon/Free-NTFS-for-Mac/main/ninja/kamui.sh)"

# 英文
LANG=en /bin/bash -c "$(curl -fsSL https://cdn.statically.io/gh/hoochanlon/Free-NTFS-for-Mac/main/ninja/kamui.sh)"
```

### 下载到本地，之后直接输入 `nigate`

```shell
curl https://fastly.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac/ninja/nigate.sh > ~/Public/nigate.sh && sudo -S mkdir -p /usr/local/bin && cd /usr/local/bin && sudo ln -s ~/Public/nigate.sh nigate.shortcut && echo "alias nigate='bash nigate.shortcut'" >> ~/.zshrc && osascript -e 'tell application "Terminal" to do script "nigate"'
```

## 软件版（Electron - 图形化）

- 下载地址见 [tags](https://github.com/hoochanlon/Free-NTFS-for-Mac/tags)
- **🌍 应用界面支持多语言**：中文（简体/繁体）、日文、英文、德文等

主界面：

![ ](src/imgs/example/2026-01-18-01.08.15.png)

托盘：

![ ](src/imgs/example/2026-01-16_10-41-58.png)

## 依赖管理

### 一键安装依赖

```shell
# 中文（默认）
/bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/ninja/kunai.sh)"

# 日文
LANG=ja /bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/ninja/kunai.sh)"

# 英文
LANG=en /bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/ninja/kunai.sh)"
```

### 一键卸载依赖

```shell
# 中文（默认）
/bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/ninja/ninpo.sh)"

# 日文
LANG=ja /bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/ninja/ninpo.sh)"

# 英文
LANG=en /bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/ninja/ninpo.sh)"
```

### 系统权限设置

配置系统权限和安全设置（Gatekeeper、SIP 等）：

```shell
# 中文（默认）
/bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/ninja/shuriken.sh)"

# 日文
LANG=ja /bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/ninja/shuriken.sh)"

# 英文
LANG=en /bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/ninja/shuriken.sh)"
```

> 更多信息请参考：[忍者工具集测试 #39](https://github.com/hoochanlon/Free-NTFS-for-Mac/issues/39) 和 [忍者工具集内容说明](docs/07-忍者工具集内容说明.md)

## 运维 & 开发

### 🚀 一键运行（推荐新手）

**完全没有开发环境的用户也能一步到位部署！**

项目提供了智能的一键运行脚本，会自动检测并安装所有必要的工具（Node.js、pnpm、依赖等），然后自动编译并启动应用。

#### 方式一：使用项目根目录的一键脚本（推荐）

```bash
# 克隆项目
git clone <repository-url>
cd Free-NTFS-for-Mac

# 一键运行（自动安装环境、编译、启动）
./dev.sh
```

或使用 ninja 目录下的脚本：

```bash
./ninja/izanaki.sh
```

**脚本会自动完成：**
- ✅ 检测并安装 Node.js（如果没有）
- ✅ 检测并安装 pnpm（如果没有）
- ✅ 同步版本号
- ✅ 安装项目依赖
- ✅ 编译 TypeScript 代码
- ✅ 编译 Stylus 样式
- ✅ 启动应用（开发模式）

#### 方式二：手动安装（适合有经验的开发者）

1. **克隆项目并初始化**

```bash
git clone <repository-url>
cd Free-NTFS-for-Mac
pnpm install
```

2. **运行应用**

```bash
# 生产模式
pnpm start

# 开发模式（自动打开 DevTools）
pnpm run dev
```

3. **构建应用**

```bash
pnpm run build
```

### 🌍 多语言支持

所有脚本和工具都支持多语言，可通过 `LANG` 环境变量设置：

```bash
# 中文（默认）
./dev.sh

# 日文
LANG=ja ./dev.sh

# 英文
LANG=en ./dev.sh
```

支持的脚本包括：

