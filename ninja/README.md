# Ninja 工具集

本文件夹包含项目开发、构建和测试所需的各种脚本和工具文件。

## 📁 文件分类

### 🔧 Shell 脚本 (.sh)

#### 1. `build.sh` - 应用打包脚本

**功能：** 将 Electron 应用打包成 macOS 安装包（DMG 或 ZIP 格式）

**使用方法：**
```bash
# 从项目根目录运行
./ninja/build.sh              # 基本打包
./ninja/build.sh --clean      # 清理后打包
./ninja/build.sh --dmg        # 仅打包 DMG
./ninja/build.sh --zip        # 仅打包 ZIP
./ninja/build.sh --arm64      # 明确指定 ARM64（默认）

# 或使用 npm 脚本
pnpm run build
pnpm run build:clean
pnpm run build:dmg
pnpm run build:zip
pnpm run build:arm64
```

**打包流程：**
1. 同步版本号
2. 编译 TypeScript 代码
3. 编译 Stylus 样式文件
4. 使用 electron-builder 打包

**输出位置：** `dist/` 目录

---

#### 2. `setup.sh` - 项目初始化脚本

**功能：** 修复 `pnpm install` 后运行 `pnpm run dev` 时的常见问题

**使用方法：**
```bash
# 从项目根目录运行
./ninja/setup.sh

# 或使用 npm 脚本
pnpm run setup
```

**自动完成：**
- ✅ 检查必要文件是否存在
- ✅ 设置脚本执行权限
- ✅ 创建必要的目录结构
- ✅ 同步版本号
- ✅ 编译 TypeScript 和 Stylus
- ✅ 检查依赖安装状态
- ✅ 验证关键文件

**适用场景：**
- 首次克隆项目后
- `pnpm run dev` 报错时
- 切换分支后需要重新初始化
- 清理 `node_modules` 后重新安装依赖

---

#### 3. `install-dependencies.sh` - 依赖安装脚本

**功能：** 一次性安装所有必要的系统依赖

**使用方法：**
```bash
# 从项目根目录运行
./ninja/install-dependencies.sh

# 或指定语言
LANG=zh_CN ./ninja/install-dependencies.sh  # 中文
LANG=en_US ./ninja/install-dependencies.sh  # 英文
LANG=ja_JP ./ninja/install-dependencies.sh  # 日文
```

**安装内容：**
1. 检查 macOS 版本（要求 macOS 14+）
2. 禁用 macOS 安全检查（Gatekeeper）
3. 安装 Xcode Command Line Tools (Swift)
4. 安装 Homebrew（可选择官方源或国内镜像源）
5. 安装 MacFUSE
6. 安装 ntfs-3g-mac
7. 安装 fswatch（可选，用于事件驱动检测）

**Homebrew 安装源选择：**
- 选项 1: 官方源（推荐，但可能需要 VPN）
- 选项 2: 国内镜像源（Gitee，适合国内用户，默认）

---

#### 4. `nigate.sh` - NTFS 设备自动挂载脚本

**功能：** 持续监控系统，自动将 NTFS 设备从只读模式切换为读写模式

**使用方法：**
```bash
# 从项目根目录运行
./ninja/nigate.sh

# 或指定语言
LANG=zh_CN ./ninja/nigate.sh  # 中文
LANG=en_US ./ninja/nigate.sh  # 英文
LANG=ja_JP ./ninja/nigate.sh  # 日文
```

**工作原理：**
1. 检查并安装必要的系统依赖
2. 每 5 秒检查一次是否有新的 NTFS 设备接入
3. 如果发现只读的 NTFS 设备，自动卸载并重新挂载为读写模式

**注意事项：**
- 需要管理员权限（会提示输入密码）
- 首次运行会安装必要的依赖
- 如果设备在 Windows 中使用了快速启动，可能导致挂载失败

**在线使用：**
```bash
/bin/bash -c "$(curl -fsSL https://cdn.statically.io/gh/hoochanlon/Free-NTFS-for-Mac/main/ninja/nigate.sh)"
```

---

#### 5. `download-electron.sh` - Electron 手动下载脚本

**功能：** 手动下载 Electron 二进制文件到缓存目录

**使用方法：**
```bash
./ninja/download-electron.sh
```

**使用场景：**
- electron-builder 自动下载失败（网络问题）
- 网络很慢，想提前下载好
- 需要使用国内镜像源加速下载

**注意事项：**
- 脚本会自动检测 Mac 架构（Intel 或 Apple Silicon）
- 下载的文件保存到 `~/.cache/electron/` 目录
- 下载完成后，electron-builder 会自动使用缓存的文件

---

#### 6. `restart-watch.sh` - 重启 TypeScript Watch 进程

**功能：** 重启 TypeScript watch 进程的脚本

**使用方法：**
```bash
./ninja/restart-watch.sh
```

**功能说明：**
- 停止现有的 `tsc --watch` 进程
- 停止 `filter-tsc-output.js` 进程
- 验证 `filter-tsc-output.js` 文件是否存在
- 提示重新运行 `pnpm run watch:ts`

**适用场景：**
- TypeScript watch 进程卡住时
- 需要重启 watch 模式时

---

#### 7. `kunai.sh` - 依赖安装脚本（别名）

**说明：** 这是 `install-dependencies.sh` 的副本，功能相同。

---

#### 8. `nigate.sh.backup` - 备份文件

**说明：** `nigate.sh` 的备份文件，保留原始版本。

---

### 📜 JavaScript 工具 (.js)

#### 1. `sync-version.js` - 版本号同步工具

**功能：** 从 `package.json` 读取版本号，自动更新所有相关文件

**使用方法：**
```bash
# 从项目根目录运行
node ninja/sync-version.js

# 或使用 npm 脚本
pnpm run sync-version
```

**自动更新的文件：**
- `src/scripts/utils/ui.ts` - 关于窗口显示的版本号
- `src/scripts/app-config.ts` - 应用配置中的版本号
- `src/html/about.html` - 关于页面显示的版本号

**工作流程：**
1. 读取 `package.json` 中的 `version` 字段
2. 自动更新所有相关文件中的版本号
3. 显示更新结果和当前版本

**提示：** 只需在 `package.json` 中修改版本号，运行此脚本即可同步到所有文件。

---

#### 2. `filter-tsc-output.js` - TypeScript 输出过滤器

**功能：** 过滤和格式化 `tsc --watch` 的输出

**使用方法：**
```bash
# 通常通过 package.json 脚本使用
pnpm run watch:ts

# 手动使用
tsc --watch 2>&1 | node ninja/filter-tsc-output.js
```

**功能说明：**
- 过滤无关的编译信息
- 保留重要的错误和警告信息
- 格式化输出，提高可读性

**过滤规则：**
- 保留：错误信息、警告信息、编译完成信息、文件路径
- 过滤：空行、重复信息、无关输出

---

#### 3. `test-modules-cli.js` - 模块测试脚本（命令行）

**功能：** 检查设备模块文件是否存在和基本语法

**使用方法：**
```bash
# 从项目根目录运行
node ninja/test-modules-cli.js
```

**检查内容：**
- 源文件存在性（`.ts` 文件）
- 编译文件存在性（`.js` 文件）
- 文件大小和内容检查
- 模块导出检查

**输出：**
- ✅ 通过的项目
- ❌ 失败的项目
- ⚠️ 警告信息
- 详细的测试报告

---

### 🌐 HTML 测试页面 (.html)

#### 1. `test-modules-enhanced.html` - 增强模块测试页面

**功能：** 在浏览器中测试设备模块的加载和功能

**使用方法：**
1. 在浏览器中打开 `ninja/test-modules-enhanced.html`
2. 页面会自动加载并测试模块
3. 查看测试结果和详细信息

**测试内容：**
- AppModules 命名空间检查
- Devices 模块检查
- Utils、Renderer、Operations、Events 子模块检查
- 各个函数的可用性检查

**注意事项：**
- 需要先编译 TypeScript（`pnpm run build:ts`）
- 确保 `scripts/` 目录中有编译后的 `.js` 文件
- 在浏览器中打开，不是通过 Electron 运行

---

## 🚀 快速开始

### 首次使用项目

```bash
# 1. 安装依赖
pnpm install

# 2. 初始化项目（修复常见问题）
pnpm run setup

# 3. 安装系统依赖（如果需要）
./ninja/install-dependencies.sh

# 4. 开始开发
pnpm run dev
```

### 更新版本号

```bash
# 1. 修改 package.json 中的 version 字段
# 2. 运行同步脚本
pnpm run sync-version
```

### 构建应用

```bash
# 基本构建
pnpm run build

# 清理后构建
pnpm run build:clean

# 仅构建 DMG
pnpm run build:dmg
```

### 使用 NTFS 读写功能

```bash
# 运行自动挂载脚本
./ninja/nigate.sh
```

---

## 📝 注意事项

1. **路径引用：** 所有脚本都假设从项目根目录运行，使用相对路径访问项目文件
2. **权限要求：** 某些脚本（如 `nigate.sh`、`install-dependencies.sh`）需要管理员权限
3. **语言支持：** 支持多语言的脚本可以通过 `LANG` 环境变量设置语言
4. **依赖顺序：** 建议先运行 `setup.sh` 初始化项目，再运行其他脚本

---

## 🔗 相关文档

- 主项目 README: [../README.md](../README.md)
- 项目文档: [../docs/](../docs/)

---

## 📄 文件列表

| 文件名 | 类型 | 功能 | 使用频率 |
|--------|------|------|----------|
| `build.sh` | Shell | 应用打包 | 发布时 |
| `setup.sh` | Shell | 项目初始化 | 首次/问题修复时 |
| `install-dependencies.sh` | Shell | 依赖安装 | 首次/依赖更新时 |
| `nigate.sh` | Shell | NTFS 自动挂载 | 日常使用 |
| `download-electron.sh` | Shell | Electron 下载 | 网络问题时 |
| `restart-watch.sh` | Shell | 重启 watch | 开发时 |
| `sync-version.js` | JavaScript | 版本同步 | 发布前 |
| `filter-tsc-output.js` | JavaScript | 输出过滤 | 开发时（自动） |
| `test-modules-cli.js` | JavaScript | 模块测试 | 测试时 |
| `test-modules-enhanced.html` | HTML | 模块测试页面 | 测试时 |

---

**最后更新：** 2024-01-12
