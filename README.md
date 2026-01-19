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

## 使用说明

### 首次使用

1. **检查系统依赖**
   - 打开应用后，点击"检查依赖"按钮
   - 系统会自动检查所需的依赖（Xcode Command Line Tools、Homebrew、MacFUSE、ntfs-3g）
   - 如果有缺失的依赖，点击"安装缺失依赖"按钮进行安装

2. **挂载 NTFS 设备**
   - 插入 NTFS 格式的移动存储设备
   - 应用会自动检测设备（每 5 秒刷新一次）
   - 对于只读设备，点击"挂载为读写"按钮
   - 输入管理员密码完成挂载

3. **自动读写功能**
   - 在标题栏点击自动读写图标（<img src="src/imgs/svg/devices/flash-auto.svg" alt="自动读写" style="height: 14px; width: 14px; vertical-align: middle; margin-right: 4px; display: inline-block;">）启用自动读写功能
   - 启用后，新插入的 NTFS 设备会自动挂载为读写模式，无需手动操作
   - 如果您手动将某个设备设置为只读，自动读写功能会尊重您的选择，不会再次将其挂载为读写模式
   - 当您启用自动读写功能时，应用会自动检查当前已连接的只读设备（不包括您手动设置为只读的设备），并尝试将它们挂载为读写模式

4. **禁止休眠功能**
   - 在标题栏、主界面操作区域或托盘窗口中点击"禁止休眠"按钮
   - 启用后，系统将保持唤醒状态，防止进入休眠模式
   - 适用于长时间文件传输或批量操作场景
   - 操作完成后可随时关闭，节省系统资源

5. **状态保护功能**
   - 在标题栏或托盘窗口中长按"状态保护"图标3s可切换保护状态
   - 保护后，自动读写、托盘模式和防止休眠功能将被禁用，防止误操作
   - 图标保护后显示为绿色并带有脉冲动画
   - 再次长按3s可解除保护状态

### 注意事项

- **管理员权限**：挂载操作需要管理员权限，系统会提示输入密码
- **Windows 快速启动**：如果设备在 Windows 中使用了快速启动功能，可能导致挂载失败。建议在 Windows 中完全关闭（而非休眠），或禁用快速启动功能
- **设备名称**：U盘名称不支持空格与非法字符
- **Gatekeeper（允许任何来源）**：首次使用可能需要禁用 Gatekeeper 以允许运行未签名的应用。在终端运行：`sudo spctl --master-disable`。禁用后可在「系统设置」>「隐私与安全性」中看到「任何来源」选项
- **系统完整性保护（SIP）**：如需禁用 SIP，需要在恢复模式下操作：
  1. 重启 Mac，按住电源键直到屏幕上出现苹果的标志和进度条，进入 Recovery 模式
  2. 在屏幕上方的工具栏找到并打开终端，输入命令：`csrutil disable`
  3. 关掉终端，重启 Mac
  4. 重启以后可以在终端中运行 `csrutil status` 查看状态确认

## 快速开始（Shell）

### 在线体验

复制粘贴到 ***完全管理权限的终端*** 回车，一键起飞：

```shell
/bin/bash -c "$(curl -fsSL https://cdn.statically.io/gh/hoochanlon/Free-NTFS-for-Mac/main/ninja/nigate.sh)"
```

### 下载到本地，之后直接输入 `nigate`

```shell
curl https://fastly.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac/ninja/nigate.sh > ~/Public/nigate.sh && sudo -S mkdir -p /usr/local/bin && cd /usr/local/bin && sudo ln -s ~/Public/nigate.sh nigate.shortcut && echo "alias nigate='bash nigate.shortcut'" >> ~/.zshrc && osascript -e 'tell application "Terminal" to do script "nigate"'
```

## 图形化软件版（Electron）

- 下载地址见 [tags](https://github.com/hoochanlon/Free-NTFS-for-Mac/tags)
- 主界面预览与托盘示例请参见仓库中的截图

## 依赖管理

### 一键安装依赖

```shell
/bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/ninja/kunai.sh)"
```

### 一键卸载依赖

```shell
/bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/ninja/ninpo.sh)"
```

> 更多信息请参考：[忍者工具集测试 #39](https://github.com/hoochanlon/Free-NTFS-for-Mac/issues/39)

## 运维 & 开发

### 安装步骤

1. **克隆项目并初始化**

```bash
git clone <repository-url>
cd Free-NTFS-for-Mac
pnpm install
pnpm run setup  # 一键修复常见问题，初始化项目
```

2. **运行应用**

```bash
pnpm start
```

或开发模式（自动打开 DevTools）：

```bash
pnpm run dev
```

3. **构建应用**

```bash
pnpm run build
```

### 项目初始化脚本

如果遇到 `pnpm run dev` 报错，运行初始化脚本一键修复：

```bash
pnpm run setup
```

或直接运行：

```bash
./ninja/setup.sh
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

