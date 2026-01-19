# 🥷 忍者ツールセット

このフォルダには、プロジェクトの開発、ビルド、テストに必要な各種スクリプトとツールファイルが含まれています。

## 📁 ファイル一覧

| ファイル名 | タイプ | 機能 | 使用頻度 |
|--------|------|------|----------|
| `build.sh` | Shell | アプリケーションのパッケージング | リリース時 |
| `build-clean.sh` | Shell | ビルドキャッシュのクリーンアップ | ビルド問題発生時 |
| `setup.sh` | Shell | プロジェクトの初期化 | 初回/問題修正時 |
| `kunai.sh` | Shell | 依存関係のインストール | 初回/依存関係更新時 |
| `ninpo.sh` | Shell | 依存関係のアンインストール | アンインストール時 |
| `nigate.sh` | Shell | NTFS 自動マウント | 日常使用 |
| `kamui.sh` | Shell | Linux ファイルシステムのマウント | Linux パーティションにアクセスする必要がある時 |
| `kamui-lang.sh` | Shell | kamui.sh 多言語サポート | 自動読み込み |
| `fix-electron.sh` | Shell | Electron の修復 | Electron 問題発生時 |
| `shuriken.sh` | Shell | システム権限の設定 | 権限問題発生時 |
| `download-electron.sh` | Shell | Electron のダウンロード | ネットワーク問題発生時 |
| `restart-watch.sh` | Shell | TypeScript Watch の再起動 | 開発時 |
| `cleanup-git-history.sh` | Shell | Git 履歴のクリーンアップ | リポジトリサイズが大きすぎる時 |
| `sync-version.js` | JavaScript | バージョン番号の同期 | リリース前 |
| `filter-tsc-output.js` | JavaScript | TypeScript 出力のフィルタリング | 開発時（自動） |
| `test-modules-cli.js` | JavaScript | モジュールテスト（コマンドライン） | テスト時 |
| `test-modules-enhanced.html` | HTML | モジュールテストページ | テスト時 |
| `anylinuxfs-readme.md` | Markdown | anylinuxfs ツールのドキュメント | 参考資料 |
| `kamui.sh 多语言支持说明.md` | Markdown | kamui.sh 多言語使用説明 | 参考資料 |

## 🚀 クイックスタート

### 初回プロジェクト使用

```bash
# 1. 依存関係のインストール
pnpm install

# 2. プロジェクトの初期化
pnpm run setup

# 3. システム依存関係のインストール（オプション）
./ninja/kunai.sh

# 4. 開発を開始
pnpm run dev
```

### アプリケーションのビルド

```bash
# 基本ビルド
pnpm run build

# クリーン後にビルド
pnpm run build:clean

# DMG のみビルド
pnpm run build:dmg
```

### NTFS 読み書き機能の使用

```bash
# 自動マウントスクリプトを実行
./ninja/nigate.sh

# 言語を設定
LANG=zh_CN ./ninja/nigate.sh  # 中国語
LANG=en_US ./ninja/nigate.sh  # 英語
LANG=ja_JP ./ninja/nigate.sh  # 日本語
```

### Linux ファイルシステムのマウント

```bash
# 自動検出してマウント
./ninja/kamui.sh

# デバイスを指定
./ninja/kamui.sh /dev/disk4s1

# ntfs3 ドライバを使用（パフォーマンス向上）
./ninja/kamui.sh /dev/disk4s1 -t ntfs3

# 利用可能なデバイスを一覧表示
./ninja/kamui.sh --list

# デバイスをアンマウント
./ninja/kamui.sh --unmount

# 言語を設定
LANG=zh_CN ./ninja/kamui.sh  # 中国語
LANG=en_US ./ninja/kamui.sh  # 英語
LANG=ja_JP ./ninja/kamui.sh  # 日本語
```

### よく使う操作

```bash
# バージョン番号を更新
pnpm run sync-version

# Electron インストール問題の修復
./ninja/fix-electron.sh

# システム権限の設定
./ninja/shuriken.sh

# ビルドキャッシュのクリーンアップ
./ninja/build-clean.sh

# 依存関係のアンインストール
./ninja/ninpo.sh
```

## 📝 注意事項

1. **パス参照：** すべてのスクリプトはプロジェクトルートディレクトリから実行することを想定しています
2. **権限要件：** 一部のスクリプト（`nigate.sh`、`kunai.sh` など）には管理者権限が必要です
3. **言語サポート：** 多言語対応のスクリプトは `LANG` 環境変数で言語を設定できます

---

**最終更新：** 2026-01-20


<!--

# 🥷 忍者工具集

本文件夹包含项目开发、构建和测试所需的各种脚本和工具文件。

## 📁 文件列表

| 文件名 | 类型 | 功能 | 使用频率 |
|--------|------|------|----------|
| `build.sh` | Shell | 应用打包 | 发布时 |
| `build-clean.sh` | Shell | 清理构建缓存 | 构建问题时 |
| `setup.sh` | Shell | 项目初始化 | 首次/问题修复时 |
| `kunai.sh` | Shell | 依赖安装 | 首次/依赖更新时 |
| `ninpo.sh` | Shell | 依赖卸载 | 卸载时 |
| `nigate.sh` | Shell | NTFS 自动挂载 | 日常使用 |
| `kamui.sh` | Shell | Linux 文件系统挂载 | 需要访问 Linux 分区时 |
| `kamui-lang.sh` | Shell | kamui.sh 多语言支持 | 自动加载 |
| `fix-electron.sh` | Shell | Electron 修复 | Electron 问题时 |
| `shuriken.sh` | Shell | 系统权限设置 | 权限问题时 |
| `download-electron.sh` | Shell | Electron 下载 | 网络问题时 |
| `restart-watch.sh` | Shell | 重启 TypeScript Watch | 开发时 |
| `cleanup-git-history.sh` | Shell | Git 历史清理 | 仓库体积过大时 |
| `sync-version.js` | JavaScript | 版本号同步 | 发布前 |
| `filter-tsc-output.js` | JavaScript | TypeScript 输出过滤 | 开发时（自动） |
| `test-modules-cli.js` | JavaScript | 模块测试（命令行） | 测试时 |
| `test-modules-enhanced.html` | HTML | 模块测试页面 | 测试时 |
| `anylinuxfs-readme.md` | Markdown | anylinuxfs 工具文档 | 参考文档 |
| `kamui.sh 多语言支持说明.md` | Markdown | kamui.sh 多语言使用说明 | 参考文档 |

## 🚀 快速开始

### 首次使用项目

```bash
# 1. 安装依赖
pnpm install

# 2. 初始化项目
pnpm run setup

# 3. 安装系统依赖（可选）
./ninja/kunai.sh

# 4. 开始开发
pnpm run dev
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

# 设置语言
LANG=zh_CN ./ninja/nigate.sh  # 中文
LANG=en_US ./ninja/nigate.sh  # 英文
LANG=ja_JP ./ninja/nigate.sh  # 日文
```

### 挂载 Linux 文件系统

```bash
# 自动检测并挂载
./ninja/kamui.sh

# 指定设备
./ninja/kamui.sh /dev/disk4s1

# 使用 ntfs3 驱动（性能更好）
./ninja/kamui.sh /dev/disk4s1 -t ntfs3

# 列出可用设备
./ninja/kamui.sh --list

# 卸载设备
./ninja/kamui.sh --unmount

# 设置语言
LANG=zh_CN ./ninja/kamui.sh  # 中文
LANG=en_US ./ninja/kamui.sh  # 英文
LANG=ja_JP ./ninja/kamui.sh  # 日文
```

### 常用操作

```bash
# 更新版本号
pnpm run sync-version

# 修复 Electron 安装问题
./ninja/fix-electron.sh

# 配置系统权限
./ninja/shuriken.sh

# 清理构建缓存
./ninja/build-clean.sh

# 卸载依赖
./ninja/ninpo.sh
```

## 📝 注意事项

1. **路径引用：** 所有脚本都假设从项目根目录运行
2. **权限要求：** 某些脚本（如 `nigate.sh`、`kunai.sh`）需要管理员权限
3. **语言支持：** 支持多语言的脚本可以通过 `LANG` 环境变量设置语言

---

**最后更新：** 2026-01-20


-->
