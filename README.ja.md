## 日本語

これは Nigate の Electron グラフィカルインターフェース版で、元の極客ターミナル版を保持しながら、NTFS デバイス管理をより簡単で便利にする、現代的で直感的な操作インターフェースを提供します。[^3]

### 機能特性

- 🎨 **現代的インターフェース** - ダークテーマを採用し、シンプルで美しいデザイン
- 📱 **リアルタイム監視** - NTFS デバイスの接続を自動検出
- ✅ **依存関係チェック** - 必要なシステム依存関係を自動チェック・インストール
- 🔄 **ワンクリックマウント** - 読み取り専用 NTFS デバイスを読み書きモードで簡単にマウント
- ⚡ **自動読み書き** - 有効にすると、新しく挿入された NTFS デバイスが自動的に読み書きモードでマウントされ、手動操作は不要です。手動で読み取り専用に設定したデバイスをインテリジェントにスキップし、ユーザーの選択を尊重します
- 📊 **ステータス表示** - デバイスの状態と操作ログを明確に表示
- 🛡️ **安全で信頼性が高い** - Electron のセキュリティベストプラクティスを使用
- ☕ **スリープ防止** - ワンクリックでシステムスリープを防止し、長時間の操作中もシステムを起動状態に保つ
- 🍃 **状態保護** - 3s長押しで保護状態を切り替えます。保護後、自動読み書き、トレイモード、スリープ防止機能が無効になり、誤操作を防ぎます

### 注意事項

- **管理者権限**: マウント操作には管理者権限が必要で、システムがパスワードの入力を求めます
- **Windows 高速スタートアップ**: デバイスが Windows で高速スタートアップ機能を使用している場合、マウントが失敗する可能性があります。Windows で完全にシャットダウン（スリープではなく）するか、高速スタートアップ機能を無効にすることをお勧めします
- **デバイス名**: USB ドライブ名はスペースと不正な文字をサポートしていません
- **Gatekeeper（すべてのソースを許可）**: 初回使用時は、未署名アプリケーションを実行できるように Gatekeeper を無効にする必要がある場合があります。ターミナルで実行: `sudo spctl --master-disable`。無効にした後、「システム設定」>「プライバシーとセキュリティ」で「すべてのソース」オプションが表示されます
- **システム整合性保護（SIP）**: SIP を無効にするには、リカバリモードで操作する必要があります：
  1. Mac を再起動し、電源ボタンを押し続けて、画面に Apple ロゴとプログレスバーが表示されるまで待ち、リカバリモードに入る
  2. 画面上部のツールバーからターミナルを見つけて開き、コマンドを入力: `csrutil disable`
  3. ターミナルを閉じて、Mac を再起動する
  4. 再起動後、ターミナルで `csrutil status` を実行して状態を確認できます
- **ブート可能なUSBドライブ**: USBドライブが Ventoy や WePE などのブートメディアを作成するために使用された場合、読み書きモードでマウントする際に時間がかかる場合があります

### クイックスタート - Shell（忍者ツールセット）

以下のスクリプトは `ninja/` フォルダの忍者ツールセットから提供され、NTFS および Linux ファイルシステムの読み書きをコマンドラインでサポートします。

**🌍 すべてのスクリプトが多言語対応！** `LANG=en` または `LANG=zh` で言語を設定できます。

#### 方法1: オンライン体験

##### NTFS 読み書きサポート

***完全な管理権限を持つターミナル***にコピー＆ペーストして Enter キーを押してください：

```shell
# 日本語（デフォルト）
/bin/bash -c "$(curl -fsSL https://cdn.statically.io/gh/hoochanlon/Free-NTFS-for-Mac/main/ninja/nigate.sh)"

# 英語
LANG=en /bin/bash -c "$(curl -fsSL https://cdn.statically.io/gh/hoochanlon/Free-NTFS-for-Mac/main/ninja/nigate.sh)"

# 中国語
LANG=zh /bin/bash -c "$(curl -fsSL https://cdn.statically.io/gh/hoochanlon/Free-NTFS-for-Mac/main/ninja/nigate.sh)"
```

##### Linux ext4 などのファイルシステム読み書きサポート

ext2/3/4、btrfs、xfs、zfs、NTFS、exFAT、LUKS 暗号化、LVM、RAID など、さまざまなファイルシステムをサポート：

```shell
# 日本語（デフォルト）
/bin/bash -c "$(curl -fsSL https://cdn.statically.io/gh/hoochanlon/Free-NTFS-for-Mac/main/ninja/kamui.sh)"

# 英語
LANG=en /bin/bash -c "$(curl -fsSL https://cdn.statically.io/gh/hoochanlon/Free-NTFS-for-Mac/main/ninja/kamui.sh)"

# 中国語
LANG=zh /bin/bash -c "$(curl -fsSL https://cdn.statically.io/gh/hoochanlon/Free-NTFS-for-Mac/main/ninja/kamui.sh)"
```

#### 方法2: ローカルにダウンロード

ダウンロード後、`nigate` と直接入力して起動できます：

```shell
curl https://fastly.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac/ninja/nigate.sh > ~/Public/nigate.sh && sudo -S mkdir -p /usr/local/bin && cd /usr/local/bin && sudo ln -s ~/Public/nigate.sh nigate.shortcut && echo "alias nigate='bash nigate.shortcut'" >> ~/.zshrc && osascript -e 'tell application "Terminal" to do script "nigate"'
```

### クイックスタート - グラフィカルソフトウェア版（Electron）

[tags](https://github.com/hoochanlon/Free-NTFS-for-Mac/tags) からダウンロードして使用。
- **🌍 アプリケーションインターフェースが多言語対応**：中国語（簡体字/繁体字）、日本語、英語、ドイツ語など

**メインインターフェース**

![ ](src/imgs/example/2026-01-18-01.08.15.png)

**トレイ**

![ ](src/imgs/example/2026-01-16_10-41-58.png)

### 依存関係管理

#### ワンクリック依存関係インストール

```shell
# 日本語（デフォルト）
/bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/ninja/kunai.sh)"

# 英語
LANG=en /bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/ninja/kunai.sh)"

# 中国語
LANG=zh /bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/ninja/kunai.sh)"
```

#### ワンクリック依存関係アンインストール

```shell
# 日本語（デフォルト）
/bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/ninja/ninpo.sh)"

# 英語
LANG=en /bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/ninja/ninpo.sh)"

# 中国語
LANG=zh /bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/ninja/ninpo.sh)"
```

> 詳細情報については、[忍者ツールセットテスト #39](https://github.com/hoochanlon/Free-NTFS-for-Mac/issues/39) と [忍者ツールセット内容説明](docs/07-忍者工具集内容说明.md) を参照してください。

### 運用 & 開発

### 🚀 ワンクリック実行（初心者におすすめ）

**開発環境が全くないユーザーでも、ワンステップでデプロイできます！**

プロジェクトは、すべての必要なツール（Node.js、pnpm、依存関係など）を自動検出してインストールし、その後自動的にコンパイルしてアプリケーションを起動する、インテリジェントなワンクリック実行スクリプトを提供します。

#### 方法1: プロジェクトルートのワンクリックスクリプトを使用（推奨）

```bash
# プロジェクトをクローン
git clone <repository-url>
cd Free-NTFS-for-Mac

# ワンクリック実行（環境の自動インストール、コンパイル、起動）
./dev.sh
```

または ninja ディレクトリのスクリプトを使用：

```bash
./ninja/izanaki.sh
```

**スクリプトは自動的に完了します：**
- ✅ Node.js を検出してインストール（存在しない場合）
- ✅ pnpm を検出してインストール（存在しない場合）
- ✅ バージョン番号を同期
- ✅ プロジェクト依存関係をインストール
- ✅ TypeScript コードをコンパイル
- ✅ Stylus スタイルをコンパイル
- ✅ アプリケーションを起動（開発モード）

#### 方法2: 手動インストール（経験豊富な開発者向け）

1. **プロジェクトのクローンと初期化**

```bash
git clone <repository-url>
cd Free-NTFS-for-Mac
pnpm install
```

2. **アプリケーションの実行**

```bash
# 本番モード
pnpm start

# 開発モード（DevTools を自動的に開く）
pnpm run dev
```

3. **アプリケーションのビルド**

```bash
pnpm run build
```

### 🌍 多言語サポート

すべてのスクリプトとツールが多言語対応で、`LANG` 環境変数で設定できます：

```bash
# 日本語（デフォルト）
./dev.sh

# 英語
LANG=en ./dev.sh

# 中国語
LANG=zh ./dev.sh
```

対応スクリプト：
- `dev.sh` / `ninja/izanaki.sh` - ワンクリック実行スクリプト
- `ninja/kamui.sh` - Linux ファイルシステムマウント
- `ninja/nigate.sh` - NTFS 自動マウント
- `ninja/build.sh` - アプリケーションパッケージング
- `ninja/shuriken.sh` - システム権限設定
- その他のすべての忍者ツールセットスクリプト

#### プロジェクトセットアップスクリプト

`pnpm run dev` でエラーが発生した場合、セットアップスクリプトを実行して修正：

```bash
pnpm run setup
```

または直接実行：

```bash
./ninja/izanaki.sh
```

このスクリプトは自動的に：
- ✅ 必要なファイルが存在するか確認
- ✅ スクリプトの実行権限を設定
- ✅ 必要なディレクトリ構造を作成
- ✅ バージョン番号を同期
- ✅ TypeScript と Stylus をコンパイル
- ✅ 重要なファイルを検証

ビルド完了後、`dist` ディレクトリにパッケージ化されたアプリケーションが見つかります。

### Mac パッケージング説明

パッケージング完了後、`dist` ディレクトリに以下が生成されます：
- **DMG ファイル**: 配布用のインストールパッケージ
- **ZIP ファイル**: 圧縮されたアプリケーションパッケージ

その他のパッケージングオプション:
- `./ninja/build.sh` スクリプトを使用してより柔軟なパッケージングを行う
- 初回実行時は、アプリケーションを右クリックして「開く」を選択する必要がある場合があります（macOS セキュリティ制限）

### トラブルシューティング

#### マウント失敗

1. すべての依存関係がインストールされているか確認
2. デバイスが他のプログラムによって占有されていないことを確認
3. Windows 高速スタートアップの問題の場合、Windows でデバイスを完全にシャットダウンしてください

#### 依存関係のインストール失敗

1. ネットワーク接続が正常であることを確認
2. Homebrew が正しくインストールされているか確認
3. ターミナルで手動にインストールコマンドを実行する必要がある場合があります

#### アプリケーションが起動しない

1. Node.js のバージョンが要件を満たしているか確認
2. `node_modules` を削除し、`pnpm install` を再実行
3. コンソールのエラーメッセージを確認

## 謝辞

このプロジェクトに貢献してくださったすべての開発者、テスター、ユーザーの皆様に感謝いたします！詳細は [謝辞リスト](ACKNOWLEDGMENTS.md) をご覧ください。

[^3]: **注**: このツールを使用して NTFS デバイスをマウントまたは変更することは、データ損失のリスクがあります。操作前に重要なデータをバックアップすることを強く推奨します。このツールは「現状のまま」提供され、いかなる保証もありません。このツールの使用によって引き起こされたデータ損失について、開発者は責任を負いません。

