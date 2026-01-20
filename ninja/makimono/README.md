# 🥷 忍者ツールセット

![1.png](https://img.remit.ee/api/file/BQACAgUAAyEGAASHRsPbAAEQFgRpb1kaCniY6FLy4S5EFKjwYp9logACZzQAAoxVeFdArRlmbLmJBDgE.png)

このフォルダには、プロジェクトの開発、ビルド、テストに必要な各種スクリプトとツールファイルが含まれています。

## 📁 ファイル一覧

| ファイル名 | タイプ | 機能 | 使用頻度 |
|--------|------|------|----------|
| `build.sh` | Shell | アプリケーションのパッケージング | リリース時 |
| `build-clean.sh` | Shell | ビルドキャッシュのクリーンアップ | ビルド問題発生時 |
| `izanaki.sh` | Shell | ワンクリック実行スクリプト（環境自動インストール） | 初回使用/環境問題発生時 |
| `kunai.sh` | Shell | 依存関係のインストール | 初回/依存関係更新時 |
| `ninpo.sh` | Shell | 依存関係のアンインストール | アンインストール時 |
| `nigate.sh` | Shell | NTFS 自動マウント | 日常使用 |
| `kamui.sh` | Shell | Linux ファイルシステムのマウント | Linux パーティションにアクセスする必要がある時 |
| `kamui-lang.sh` | Shell | kamui.sh 多言語サポート | 自動読み込み |
| `shuriken.sh` | Shell | システム権限の設定 | 権限問題発生時 |
| `restart-watch.sh` | Shell | TypeScript Watch の再起動 | 開発時 |
| `okugi.sh` | Shell | Git 履歴のクリーンアップ | リポジトリサイズが大きすぎる時 |
| `sync-version.js` | JavaScript | バージョン番号の同期 | リリース前 |
| `filter-tsc-output.js` | JavaScript | TypeScript 出力のフィルタリング | 開発時（自動） |
| `test-modules-cli.js` | JavaScript | モジュールテスト（コマンドライン） | テスト時 |
| `test-modules-enhanced.html` | HTML | モジュールテストページ | テスト時 |
| `makimono/` | ディレクトリ | ツールセットドキュメント（多言語） | 参照時 |

## 🚀 クイックスタート

### 初回プロジェクト使用

**方法1：ワンクリック実行（初心者におすすめ）**

```bash
# 必要なツール（Node.js、pnpm、依存関係など）を自動検出してインストール
./ninja/izanaki.sh
```

**方法2：手動インストール**

```bash
# 1. 依存関係のインストール
pnpm install

# 2. システム依存関係のインストール（オプション）
./ninja/kunai.sh

# 3. 開発を開始
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

# 環境のワンクリックインストール（Electron 修復機能を含む）
./ninja/izanaki.sh

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
4. **ワンクリックスクリプト：** `izanaki.sh` は Node.js、pnpm、プロジェクト依存関係などを自動検出してインストールします。環境が全くないユーザーに適しています
5. **ドキュメントディレクトリ：** `makimono/` ディレクトリにはツールセットの多言語ドキュメント（日本語版など）が含まれています

---

**最終更新：** 2026-01-20


