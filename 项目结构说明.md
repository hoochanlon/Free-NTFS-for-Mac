# 项目结构说明

## 新的项目结构

项目已完全重构为使用 TypeScript 和 Stylus，所有源代码都在 `src/` 目录下：

```
Free-NTFS-for-Mac/
├── src/                    # 源代码目录（所有源文件）
│   ├── scripts/           # TypeScript 脚本
│   │   ├── main.ts        # Electron 主进程
│   │   ├── preload.ts     # 预加载脚本
│   │   ├── renderer.ts    # 渲染进程脚本
│   │   └── ntfs-manager.ts # NTFS 管理逻辑
│   ├── styles/            # Stylus 样式
│   │   └── main.styl      # 主样式文件
│   └── types/             # TypeScript 类型定义
│       └── electron.d.ts  # Electron API 类型定义
├── scripts/                # 编译后的 JS 文件（自动生成，已加入 .gitignore）
│   ├── main.js
│   ├── preload.js
│   ├── renderer.js
│   └── ntfs-manager.js
├── index.html              # 主 HTML 文件
├── styles.css              # 编译后的 CSS（自动生成，已加入 .gitignore）
├── tsconfig.json           # TypeScript 配置
└── package.json            # 项目配置
```

## 构建流程

### 开发模式

```bash
# 构建所有文件
npm run build:all

# 启动应用
npm start

# 或开发模式（自动打开 DevTools）
npm run dev
```

### 监听模式

```bash
# 监听 TypeScript 和 Stylus 变化
npm run watch:all

# 或分别监听
npm run watch:ts      # 只监听 TypeScript
npm run watch:stylus  # 只监听 Stylus
```

## 文件说明

### 源代码文件（在 src/ 目录下）

- **src/scripts/main.ts** - Electron 主进程的 TypeScript 源代码
- **src/scripts/preload.ts** - 预加载脚本的 TypeScript 源代码
- **src/scripts/renderer.ts** - 渲染进程的 TypeScript 源代码
- **src/scripts/ntfs-manager.ts** - NTFS 管理逻辑的 TypeScript 源代码
- **src/styles/main.styl** - Stylus 样式源代码
- **src/types/electron.d.ts** - Electron API 类型定义

### 编译输出（自动生成，不要手动编辑）

- **scripts/** - 由 TypeScript 编译生成的 JS 文件目录
- **styles.css** - 由 Stylus 编译生成的 CSS 文件

## 技术栈

- **TypeScript** - 类型安全的 JavaScript，所有 JS 文件已转换为 TS
- **Stylus** - CSS 预处理器，所有 CSS 文件已转换为 Styl
- **Electron** - 跨平台桌面应用框架

## 重要说明

1. **只编辑源代码**：只编辑 `src/` 目录下的 `.ts` 和 `.styl` 文件
2. **编译后的文件**：`scripts/` 目录和 `styles.css` 是自动生成的，已加入 `.gitignore`，不要手动编辑
3. **构建命令**：在运行应用前，确保先运行 `npm run build:all`
4. **文件删除**：所有旧的 `.js` 和 `.css` 源文件已删除，只保留 TypeScript 和 Stylus 源文件

## 迁移完成

✅ 所有 JS 文件已转换为 TypeScript
✅ 所有 CSS 文件已转换为 Stylus
✅ 旧的源文件已删除
✅ 构建配置已更新
✅ .gitignore 已更新
