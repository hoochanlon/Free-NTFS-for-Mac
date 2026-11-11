# Nigate

**言語 / Language / 语言**: [日本語](README.ja.md) | [English](README.md) | [简体中文](README.zh-CN.md)

Nigate は、NTFS ボリュームを読み書き可能な状態でマウントするための、macOS ネイティブアプリケーションです。

最新版は [リリースタグ](https://github.com/hoochanlon/Free-NTFS-for-Mac/tags) からダウンロードできます。

![](https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/src/imgs/example/demo.gif)

このデモは 1.5.4 より前のバージョンのものです。機能追加に伴い、画面が変更される場合があります。

## 機能

- **モダンなインターフェース**：ダークモードに対応した、シンプルな SwiftUI インターフェース
- **リアルタイム監視**：接続された NTFS デバイスを自動検出
- **依存関係の確認**：必要なシステム依存関係を確認し、インストールを支援
- **ワンクリックマウント**：対応する NTFS ボリュームを読み書き可能な状態でマウント
- **自動読み書きマウント**：新しく接続された NTFS デバイスを自動マウントできます。明示的に読み取り専用に設定されたデバイスはその選択を尊重します
- **状態表示**：デバイスの状態と操作ログをわかりやすく表示
- **スリープ防止**：長時間の処理中に Mac がスリープしないように維持
- **保護機能**：保護操作を 3 秒間長押しすると、自動マウント、メニューバーモード、スリープ防止を無効にし、誤操作を防止
- **多言語インターフェース**：簡体字中国語、繁体字中国語、日本語、英語、ドイツ語などに対応

## 重要な注意事項

> [!CAUTION]
> 安定性とデータの完全性はストレージデバイスの性能に左右されます。I/O エラー、転送の中断、デバイス検出の失敗を減らすため、高品質なフラッシュメモリと安定した読み書き性能を持つ USB ストレージを使用してください。

> [!IMPORTANT]
> **読み書きの動作：**
> - **基本操作**：ファイルのコピー、移動、削除、名前変更など、メタデータレベルの操作に対応します。
> - **編集と保存**：GUI は NTFS ボリュームを読み書きモードでマウントし、ファイル所有者を現在の macOS ユーザーの `uid` / `gid` にマッピングします。テスト済みの構成ではテキストや画像を編集・保存できますが、互換性はエディタと保存方法によって異なります。
> - **保存に失敗する場合**：重要なデータを先にバックアップしてください。必要に応じて Mac 上にファイルをコピーして編集し、その後デバイスへ戻してください。一時ファイルを作成してから名前を変更して置き換えるエディタで改善する場合がありますが、すべての制限を回避できる保証はありません。

- **管理者権限**：マウントには管理者権限が必要で、macOS がパスワードを要求します。
- **Windows の高速スタートアップ**：高速スタートアップが有効な Windows で使用したデバイスは、マウントに失敗する場合があります。再接続する前に Windows を完全にシャットダウンするか、高速スタートアップを無効にしてください。
- **デバイス名**：USB ストレージの名前には、スペースやサポートされない文字を使用しないでください。
- **Gatekeeper**：初回起動時に macOS が未署名アプリケーションをブロックする場合があります。システム設定 > プライバシーとセキュリティで、対象アプリケーションだけを許可してください。セキュリティ上の影響を理解していない限り、Gatekeeper をシステム全体で無効にしないでください。
- **起動用 USB デバイス**：Ventoy、WinPE などの起動メディア作成に使用したデバイスは、読み書きモードでのマウントに時間がかかる場合があります。

## 実行と開発

### リリース版を実行する

[リリースタグ](https://github.com/hoochanlon/Free-NTFS-for-Mac/tags) から最新版をダウンロードし、`Nigate.app` を「アプリケーション」フォルダへ移動して起動します。

未署名または ad-hoc 署名のビルドでは、macOS の「システム設定」>「プライバシーとセキュリティ」で起動を許可する必要がある場合があります。マウントには管理者権限が必要です。読み書きマウントには MacFUSE と `ntfs-3g` も必要で、依存関係画面から状態と利用可能なインストール手順を確認できます。

### ソースから実行する

必要な環境：

- macOS 14 以降
- Swift 6 対応の Swift Package Manager ツールチェーン
- 実機テストには MacFUSE、`ntfs-3g`、テスト用の NTFS ストレージデバイス

リポジトリのルートで次のコマンドを実行します。

```sh
git clone https://github.com/hoochanlon/Free-NTFS-for-Mac.git
cd Free-NTFS-for-Mac
swift test
./dev.sh
```

`./dev.sh` と `./macos/Scripts/dev.sh` は、どちらも Swift Package Manager 経由で Nigate を起動します。初回ビルド時に `.build` ディレクトリが作成されます。

### アプリケーションバンドルをビルドする

通常のビルドでは Release 版を作成し、ローカルの ad-hoc 署名を適用して `dist/Nigate.app` に出力します。

```sh
swift test
./macos/Scripts/build.sh
open dist/Nigate.app
```

Debug 版をビルドする場合：

```sh
./macos/Scripts/build.sh debug
open dist/Nigate.app
```

`build.sh` は `Info.plist`、アプリケーションアイコン、Swift Package のリソースをバンドルへコピーしてから署名します。Developer ID 署名、公証、リリース公開の処理は自動では行いません。正式リリースには Apple Developer の証明書と公証用の認証情報が必要です。

`notarytool` のキーチェーンプロファイルを設定済みの場合は、次の環境変数で署名と公証を有効にできます。

```sh
DEVELOPER_ID_APPLICATION="Developer ID Application: Example" \
NOTARY_PROFILE="your-notary-profile" \
NOTARIZE=1 \
./macos/Scripts/build.sh
```

### DMG を作成する

専用のパッケージスクリプトで Release 版アプリケーションをビルドし、DMG を作成します。

```sh
./macos/Scripts/package-dmg.sh
open dist/Nigate-1.6.0.dmg
```

Debug 版の DMG を作成する場合：

```sh
./macos/Scripts/package-dmg.sh debug
```

スクリプトは最初に `build.sh` を呼び出して `Nigate.app` を作成し、その後アプリケーション、`dmg-assets` にあるインストールガイドと補助スクリプト、「アプリケーション」フォルダへのショートカットを DMG に配置します。出力ファイル名は `macos/Info.plist` のバージョンから生成され、例として `dist/Nigate-1.6.0.dmg` になります。

デフォルトの出力はローカル署名の開発用 DMG です。正式配布では Developer ID 署名と公証の設定を指定してください。パッケージスクリプトは、これらの環境変数をアプリケーションのビルド処理へ引き継ぎます。

```sh
DEVELOPER_ID_APPLICATION="Developer ID Application: Example" \
NOTARY_PROFILE="your-notary-profile" \
NOTARIZE=1 \
./macos/Scripts/package-dmg.sh
```

DMG のレイアウト用リソースは `dmg-assets` にあります。インストールガイドや補助ファイルを変更すると、次回のビルド時に DMG のルートへコピーされます。

### プロジェクト構成

```text
Package.swift                         Swift Package Manager のエントリポイント
macos/Sources/Nigate/Domain            データモデルとディスク安全ポリシー
macos/Sources/Nigate/Infra             Shell、権限、パス、Keychain、設定のアダプター
macos/Sources/Nigate/NTFS              スキャン、監視、マウント、修復、依存関係
macos/Sources/Nigate/App               アプリ状態、ライフサイクル、メニューバー連携
macos/Sources/Nigate/UI                SwiftUI 画面、シート、インタラクション
macos/Sources/Nigate/Resources         ヘルプ、ローカライズ、アプリケーションアイコン
Tests/NigateTests                      ディスク安全性と自動マウントのテスト
docs/README.md                         エンジニアリング構成と安全境界
```

変更を提出する前に、少なくとも `swift test` と `swift build` を実行してください。ディスク関連機能は、バックアップ済みのデータと専用のテストデバイスだけで検証してください。フォーマットは不可逆操作であり、`ntfsfix` は Windows の `chkdsk` の代わりにはなりません。

## 謝辞

コード、テスト、フィードバックを提供してくださった皆さまに感謝します。詳細は [謝辞](ACKNOWLEDGMENTS.md) を参照してください。
