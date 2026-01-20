**Language / 言語 / 语言**: [English](README.en.md) | [日本語](README.ja.md) | [中文](README.md)

## 中文

这是 Nigate 的 Electron 图形界面版本，在保留原有极客终端版本的同时，提供了现代化、直观的操作界面，让 NTFS 设备管理更加简单便捷。[^1]

## 功能特性

- 🎨 **现代化界面** - 采用深色主题，界面简洁美观
- 📱 **实时监控** - 自动检测 NTFS 设备接入
- ✅ **依赖检查** - 自动检查并安装所需系统依赖
- 🔄 **一键挂载** - 轻松将只读 NTFS 设备挂载为读写模式
- ⚡ **自动读写** - 启用后，新插入的 NTFS 设备会自动挂载为读写模式，无需手动操作。智能跳过您手动设置为只读的设备，尊重您的选择
- 📊 **状态显示** - 清晰显示设备状态和操作日志
- 🛡️ **安全可靠** - 使用 Electron 安全最佳实践
- ☕ **禁止休眠** - 一键开启/关闭系统休眠防止功能，确保长时间操作时系统保持唤醒状态
- 🍃 **状态保护** - 长按3s可切换保护状态，保护后自动读写、托盘模式和防止休眠功能将被禁用，防止误操作

## 注意事项

- **管理员权限**：挂载操作需要管理员权限，系统会提示输入密码
- **Windows 快速启动**：如果设备在 Windows 中使用了快速启动功能，可能导致挂载失败。建议在 Windows 中完全关闭（而非休眠），或禁用快速启动功能
- **设备名称**：U盘名称不支持空格与非法字符
- **Gatekeeper（允许任何来源）**：首次使用可能需要禁用 Gatekeeper 以允许运行未签名的应用。在终端运行：`sudo spctl --master-disable`。禁用后可在「系统设置」>「隐私与安全性」中看到「任何来源」选项
- **系统完整性保护（SIP）**：如需禁用 SIP，需要在恢复模式下操作：
  1. 重启 Mac，按住电源键直到屏幕上出现苹果的标志和进度条，进入 Recovery 模式
  2. 在屏幕上方的工具栏找到并打开终端，输入命令：`csrutil disable`
  3. 关掉终端，重启 Mac
  4. 重启以后可以在终端中运行 `csrutil status` 查看状态确认

## 快速开始（Shell - 忍者工具集）

以下脚本来自 `ninja/` 文件夹的忍者工具集，提供命令行方式的 NTFS 和 Linux 文件系统读写支持。

**🌍 所有脚本都支持多语言！** 使用 `LANG=ja` 或 `LANG=en` 设置语言。

### 在线体验

#### NTFS 读写支持

复制粘贴到 ***完全管理权限的终端*** 回车，一键起飞：

```shell
# 中文（默认）
/bin/bash -c "$(curl -fsSL https://cdn.statically.io/gh/hoochanlon/Free-NTFS-for-Mac/main/ninja/nigate.sh)"

# 日文
LANG=ja /bin/bash -c "$(curl -fsSL https://cdn.statically.io/gh/hoochanlon/Free-NTFS-for-Mac/main/ninja/nigate.sh)"

# 英文
LANG=en /bin/bash -c "$(curl -fsSL https://cdn.statically.io/gh/hoochanlon/Free-NTFS-for-Mac/main/ninja/nigate.sh)"
```

#### Linux ext4 等文件系统读写支持

支持 ext2/3/4、btrfs、xfs、zfs、NTFS、exFAT、LUKS 加密、LVM、RAID 等多种文件系统：

```shell
# 中文（默认）
/bin/bash -c "$(curl -fsSL https://cdn.statically.io/gh/hoochanlon/Free-NTFS-for-Mac/main/ninja/kamui.sh)"

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
- `dev.sh` / `ninja/izanaki.sh` - 一键运行脚本
- `ninja/kamui.sh` - Linux 文件系统挂载
- `ninja/nigate.sh` - NTFS 自动挂载
- `ninja/build.sh` - 应用打包
- `ninja/shuriken.sh` - 系统权限设置
- 以及其他所有 ninja 工具集脚本

### 项目初始化脚本

如果遇到 `pnpm run dev` 报错，运行初始化脚本一键修复：

```bash
pnpm run setup
```

或直接运行：

```bash
./ninja/izanaki.sh
```

这个脚本会自动：
- ✅ 检查必要文件是否存在
- ✅ 设置脚本执行权限
- ✅ 创建必要的目录结构
- ✅ 同步版本号
- ✅ 编译 TypeScript 和 Stylus
- ✅ 验证关键文件

构建完成后，可在 `dist` 目录找到打包好的应用。

## Mac 打包说明

打包完成后，会在 `dist` 目录生成：
- **DMG 文件**：用于分发的安装包
- **ZIP 文件**：压缩的应用包

其他说明：
- 使用 `./ninja/build.sh` 可进行更灵活的打包
- 首次运行可能需要右键点击应用选择"打开"（macOS 安全限制）

## 故障排除

### 挂载失败

1. 检查是否已安装所有依赖
2. 确认设备未被其他程序占用
3. 如果是 Windows 快速启动问题，请在 Windows 中完全关闭设备

### 依赖安装失败

1. 确保网络连接正常
2. 检查 Homebrew 是否正确安装
3. 可能需要手动在终端运行安装命令

### 应用无法启动

1. 检查 Node.js 版本是否符合要求
2. 删除 `node_modules` 并重新运行 `pnpm install`
3. 查看控制台错误信息

## 致谢

感谢所有为这个项目做出贡献的开发者、测试者和用户！查看 [致谢名单](ACKNOWLEDGMENTS.md) 了解详情。

[^1]: 注：使用本工具挂载或修改 NTFS 设备存在数据丢失风险。强烈建议操作前备份重要数据。本工具按"现状"提供，不提供任何担保。因使用本工具造成的数据损失，开发者不承担责任。

