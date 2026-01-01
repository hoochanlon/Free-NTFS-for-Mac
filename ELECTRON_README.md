# Free NTFS for Mac - Electron 界面版

这是 Free NTFS for Mac 的 Electron 图形界面版本，提供了现代化、易用的操作界面来管理 NTFS 设备。

## 功能特性

- 🎨 **现代化界面** - 采用深色主题，界面简洁美观
- 📱 **实时监控** - 自动检测 NTFS 设备接入
- ✅ **依赖检查** - 自动检查并安装所需系统依赖
- 🔄 **一键挂载** - 轻松将只读 NTFS 设备挂载为读写模式
- 📊 **状态显示** - 清晰显示设备状态和操作日志
- 🛡️ **安全可靠** - 使用 Electron 安全最佳实践

## 安装与运行

### 前置要求

- macOS 10.13 或更高版本
- Node.js 16 或更高版本
- npm 或 yarn

### 安装步骤

1. **安装依赖**

```bash
npm install
```

2. **运行应用**

```bash
npm start
```

或开发模式（自动打开 DevTools）：

```bash
npm run dev
```

3. **构建应用**

```bash
npm run build
```

构建完成后，可在 `dist` 目录找到打包好的应用。

## 使用说明

### 首次使用

1. **检查系统依赖**
   - 打开应用后，点击"检查依赖"按钮
   - 系统会自动检查所需的依赖（Swift、Homebrew、MacFUSE、ntfs-3g）
   - 如果有缺失的依赖，点击"安装缺失依赖"按钮进行安装

2. **挂载 NTFS 设备**
   - 插入 NTFS 格式的移动存储设备
   - 应用会自动检测设备（每 5 秒刷新一次）
   - 对于只读设备，点击"挂载为读写"按钮
   - 输入管理员密码完成挂载

### 注意事项

- **管理员权限**：挂载操作需要管理员权限，系统会提示输入密码
- **Windows 快速启动**：如果设备在 Windows 中使用了快速启动功能，可能导致挂载失败。建议在 Windows 中完全关闭（而非休眠），或禁用快速启动功能
- **设备名称**：U盘名称不支持空格与非法字符
- **系统完整性保护**：首次使用可能需要禁用系统完整性保护（SIP），在终端运行：`sudo spctl --master-disable`

## 项目结构

```
.
├── main.js              # Electron 主进程
├── preload.js           # 预加载脚本（安全桥接）
├── renderer.js          # 渲染进程逻辑
├── ntfs-manager.js      # NTFS 管理核心逻辑
├── index.html           # 界面 HTML
├── styles.css           # 样式文件
├── package.json         # 项目配置
└── ELECTRON_README.md   # 本文件
```

## 技术栈

- **Electron** - 跨平台桌面应用框架
- **Node.js** - 后端逻辑
- **原生 HTML/CSS/JavaScript** - 前端界面

## 开发说明

### 代码结构

- `main.js`: Electron 主进程，负责窗口管理和 IPC 通信
- `preload.js`: 安全桥接层，暴露安全的 API 给渲染进程
- `renderer.js`: 渲染进程逻辑，处理 UI 交互
- `ntfs-manager.js`: NTFS 设备管理核心，将原 shell 脚本逻辑转换为 Node.js 代码

### IPC 通信

应用使用 Electron 的 IPC（进程间通信）机制：

- `check-dependencies`: 检查系统依赖
- `get-ntfs-devices`: 获取 NTFS 设备列表
- `mount-device`: 挂载设备为读写模式
- `unmount-device`: 卸载设备
- `install-dependencies`: 安装缺失依赖

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
2. 删除 `node_modules` 并重新运行 `npm install`
3. 查看控制台错误信息

## 许可证

MIT License

## 致谢

基于原项目 [Free-NTFS-for-Mac](https://github.com/hoochanlon/Free-NTFS-for-Mac) 的 shell 脚本版本开发。
