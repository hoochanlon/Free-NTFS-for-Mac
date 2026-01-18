## 免责声明

使用本工具挂载和修改 NTFS 设备存在数据丢失的风险。建议在使用前备份重要数据。本工具按"现状"提供，不提供任何明示或暗示的担保。使用本工具造成的任何数据损失，开发者不承担责任。

## 系统要求

使用本工具需要以下系统依赖：

1. **Xcode Command Line Tools** - Apple 的开发工具
2. **Homebrew** - macOS 的包管理器
3. **MacFUSE** - 文件系统用户空间框架
4. **ntfs-3g** - NTFS 文件系统驱动

### 安装系统依赖

首次使用前，请先检查系统依赖是否已安装。在"系统依赖"标签页中点击"检查依赖"按钮，系统会自动检测所需依赖的安装状态。

如果检测到缺失的依赖，请按照以下步骤手动安装：

#### 1. 安装 Xcode Command Line Tools

在终端运行以下命令：

```bash
xcode-select --install
```

运行后会弹出安装窗口，按照提示完成安装。安装过程可能需要几分钟到几十分钟，请耐心等待。

#### 2. 安装 Homebrew

在终端运行以下命令：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

按照提示完成安装。如果网络较慢，可以使用国内镜像源：

```bash
/bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"
```

#### 3. 安装 MacFUSE

在终端运行以下命令：

```bash
brew install --cask macfuse
```

#### 4. 安装 ntfs-3g

在终端运行以下命令：

```bash
brew tap gromgit/homebrew-fuse
brew install ntfs-3g-mac
```

**注意**：安装顺序很重要，请按照 1 → 2 → 3 → 4 的顺序依次安装。

![1768637904211](image/help/1768637904211.png)## 界面图标说明

应用主界面提供了多个功能图标，帮助您快速访问常用功能：

### 标题栏图标

- <img src="../imgs/svg/devices/flash-auto.svg" alt="自动读写" style="height: 14px; width: 14px; vertical-align: middle; margin-right: 4px; display: inline-block;"> **自动读写图标** - 启用后，新插入的 NTFS 设备会自动挂载为读写模式。图标激活时显示为蓝色。
- <img src="../imgs/svg/devices/tray.svg" alt="托盘模式" style="height: 14px; width: 14px; vertical-align: middle; margin-right: 4px; display: inline-block;"> **托盘模式图标** - 启用后，关闭窗口时应用会最小化到系统托盘而不是退出。图标激活时显示为紫色。
- <img src="../imgs/svg/system/caffe.svg" alt="防止休眠" style="height: 14px; width: 14px; vertical-align: middle; margin-right: 4px; display: inline-block;"> **防止休眠图标** - 启用后，系统将禁止进入休眠状态，确保设备持续可用。图标激活时显示为咖啡色。
- <img src="../imgs/svg/ui/info.svg" alt="关于" style="height: 14px; width: 14px; vertical-align: middle; margin-right: 4px; display: inline-block;"> **关于图标** - 打开关于窗口，查看应用信息和项目链接。
- <img src="../imgs/svg/actions/exit-red.svg" alt="退出" style="height: 14px; width: 14px; vertical-align: middle; margin-right: 4px; display: inline-block;"> **退出图标** - 退出应用程序。

### 标签页图标

- <img src="../imgs/svg/ui/log.svg" alt="日志" style="height: 14px; width: 14px; vertical-align: middle; margin-right: 4px; display: inline-block;"> **日志图标** - 切换到"操作日志"标签页，查看所有操作的记录。

### 设备管理图标

- <img src="../imgs/svg/actions/refresh.svg" alt="刷新" style="height: 14px; width: 14px; vertical-align: middle; margin-right: 4px; display: inline-block;"> **刷新图标** - 刷新设备列表，重新检测已连接的 NTFS 设备。

## 使用步骤

### 检查系统依赖

在"系统依赖"标签页中点击"检查依赖"按钮，系统会自动检测所需依赖的安装状态。如果检测到缺失的依赖，会显示详细的安装指引，包括安装命令和说明。

### 管理 NTFS 设备

插入 NTFS 格式的移动存储设备后，在"NTFS 设备"标签页中可以查看所有已连接的设备。

设备状态分为两种：

- **只读** - 设备只能读取，无法写入。这是 macOS 对 NTFS 设备的默认处理方式。
- **读写** - 设备已挂载为读写模式，可以正常读写文件。

### 挂载设备为读写模式

对于只读状态的设备，可以点击"挂载为读写"按钮将其挂载为读写模式。此操作需要管理员权限，系统会弹出密码输入对话框。

**注意事项：**

- 挂载操作需要管理员权限，请准备好您的系统密码
- 如果设备在 Windows 中使用了快速启动功能，可能需要先在 Windows 中完全关闭设备
- 挂载后请安全弹出设备，避免数据丢失

### 自动读写功能

自动读写功能可以让您无需手动操作，自动将新插入的 NTFS 设备挂载为读写模式。

**启用方式：**

- 在标题栏点击自动读写图标（<img src="../imgs/svg/devices/flash-auto.svg" alt="自动读写" style="height: 14px; width: 14px; vertical-align: middle; margin-right: 4px; display: inline-block;">），图标变为蓝色表示已启用
- 在托盘菜单中勾选"自动读写"选项
- 在主界面标题栏的自动读写按钮中切换

**功能特点：**

- **自动检测新设备**：当您插入新的 NTFS 设备时，应用会自动检测并挂载为读写模式
- **智能跳过手动只读设备**：如果您手动将某个设备设置为只读，自动读写功能会尊重您的选择，不会再次将其挂载为读写模式
- **开启时自动处理现有设备**：当您启用自动读写功能时，应用会自动检查当前已连接的只读设备（不包括您手动设置为只读的设备），并尝试将它们挂载为读写模式

**使用场景：**

- 频繁使用多个 NTFS 设备，希望自动挂载而不需要每次手动操作
- 需要批量处理多个设备时，可以一次性启用自动读写功能
- 临时需要自动挂载功能时，可以随时开启或关闭

**注意事项：**

- 自动读写功能需要管理员权限，首次挂载时会提示输入密码
- 如果您手动将设备设置为只读，该设备会被添加到"手动只读设备"列表中，自动读写功能不会再次挂载它
- 如果您手动将设备挂载为读写模式，该设备会从"手动只读设备"列表中移除，之后可以正常使用自动读写功能
- 自动读写功能不会影响您手动操作的设备，您可以随时手动挂载或卸载设备

### 卸载设备

对于已挂载的设备，可以点击"卸载"按钮将其卸载。卸载操作需要管理员权限。

**卸载的特点：**
- 从文件系统中移除设备
- 设备仍然物理连接在电脑上
- 系统可能会自动重新挂载设备（例如重新插入或系统自动挂载）
- 设备会保留在列表中，标记为"已卸载"状态
- 可以重新挂载使用

**适用场景：**
- 临时断开设备访问，但设备仍连接在电脑上
- 需要重新配置设备挂载方式
- 设备出现问题时，先卸载再重新挂载

### 推出设备

对于已挂载的设备，可以点击"推出"按钮将其完全断开。推出操作不需要管理员权限。

**推出的特点：**
- 完全断开设备，从系统中移除
- 设备会从列表中消失
- 系统不会自动重新挂载设备
- 需要重新插入设备才能再次使用
- 提示可以安全拔出设备

**适用场景：**
- 准备拔出设备前，确保数据已完全写入
- 需要完全断开设备连接
- 设备不再需要使用时
- 类似 macOS Finder 中的"推出"功能

**卸载 vs 推出的区别：**

| 特性 | 卸载 | 推出 |
|------|------|------|
| 需要管理员权限 | ✅ 是 | ❌ 否 |
| 设备物理连接 | ✅ 保持连接 | ✅ 保持连接 |
| 系统自动重新挂载 | ⚠️ 可能会 | ❌ 不会 |
| 设备在列表中 | ✅ 保留（标记为已卸载） | ❌ 移除 |
| 可以重新挂载 | ✅ 可以 | ❌ 需要重新插入 |
| 适用场景 | 临时断开、重新配置 | 准备拔出、完全断开 |

## 常见问题

### 为什么我的设备显示为只读？

这是 macOS 的默认行为。macOS 默认以只读模式挂载 NTFS 设备。使用本工具可以将设备挂载为读写模式。

### 挂载失败怎么办？

请检查以下几点：

- 确保已安装所有系统依赖
- 确保输入的管理员密码正确
- 如果设备在 Windows 中使用过，请先在 Windows 中完全关闭设备
- 检查设备是否有其他程序正在使用

### 安装依赖失败怎么办？

如果安装过程中遇到问题，请检查以下几点：

- **网络连接**：确保网络连接正常，安装过程需要下载文件
- **磁盘空间**：确保有足够的磁盘空间（Xcode Command Line Tools 需要几个 GB 的空间）
- **系统权限**：确保有管理员权限，某些安装需要输入密码
- **安装顺序**：请按照正确的顺序安装依赖（Xcode → Homebrew → MacFUSE → ntfs-3g）

**常见问题：**

1. **Xcode Command Line Tools 安装失败**
   - 检查网络连接
   - 尝试从 Apple 开发者网站手动下载安装包

2. **Homebrew 安装慢或失败**
   - 使用国内镜像源（见上方安装步骤）
   - 检查网络代理设置

3. **MacFUSE 或 ntfs-3g 安装失败**
   - 确保已先安装 Homebrew
   - 运行 `brew update` 更新 Homebrew
   - 检查是否有权限问题

如果仍然无法解决，请参考各依赖的官方文档或寻求技术支持。

### 卸载设备后无法访问？

卸载后设备会从系统中移除。如果需要重新访问，请重新插入设备或使用系统自带的挂载功能。

## 操作日志

在"操作日志"标签页中可以查看所有操作的记录，包括：

- 依赖检查结果
- 设备检测状态
- 挂载/卸载操作结果
- 错误信息和警告

日志可以帮助您排查问题和跟踪操作历史。可以随时点击"清空"按钮清除所有日志记录。

## 更多疑难解答

如果您遇到其他问题（如"文件损坏"提示、设备 busy 错误、驱动冲突等），请参考我们的 [疑难解答中心](https://github.com/hoochanlon/Free-NTFS-for-Mac/issues/9)，其中包含了详细的故障排除步骤和解决方案。
