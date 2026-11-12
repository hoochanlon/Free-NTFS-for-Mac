# Nigate

**言語 / Language / 语言**: [日本語](README.ja.md) | [English](README.md) | [简体中文](README.zh-CN.md)

Nigate は、NTFS ボリュームを読み書き可能な状態でマウントするための、macOS ネイティブアプリケーションです。

最新版は [リリースタグ](https://github.com/hoochanlon/Free-NTFS-for-Mac/tags) からダウンロードできます。

![](https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/src/imgs/example/demo.gif)

このデモは 1.6.0 より前のバージョンのものです。

## 機能

- SwiftUI：NTFS デバイスの自動検出、依存関係チェック、ワンクリックマウント、自動読み書き、状態ログ、スリープ防止、保護ロック
- 多言語 UI：簡体字/繁体字中国語、日本語、英語、ドイツ語など
- **デュアルマウントバックエンド**
  - **ntfs-3g（デフォルト / 互換）**：MacFUSE + `ntfs-3g`。一般利用および未署名ビルドの主経路
  - **FSKit（オプション / ネイティブ）**：NTFS エンジンを内包した Nigate FSKit 拡張。**設定 → マウントバックエンド** で切替

## マウントバックエンド

| バックエンド | 必要条件 | 説明 |
| --- | --- | --- |
| ntfs-3g | MacFUSE、`ntfs-3g` | デフォルト。ad-hoc / ローカルビルドで利用可。 |
| FSKit | macOS 15.4+、拡張のインストールと有効化 | オプション。失敗時に ntfs-3g へ**黙って降格しない**。 |

FSKit を有効にする手順：

1. `Nigate.app` をビルド/インストール（`./macos/Scripts/build.sh`）。拡張は `Contents/PlugIns`
2. **システム設定 → 一般 → ログイン項目と拡張機能 → ファイルシステム拡張機能** で **Nigate NTFS** を有効化
3. アプリで **マウントバックエンド** を **FSKit（ネイティブ）** に設定

プログラム経由の `FSClient.mountSingleVolume` には `com.apple.developer.fskit.mount` 付きの信頼できる署名が必要です。Apple Developer ID がない場合は **ntfs-3g** を主経路にしてください。拡張が読み込める環境では、FSKit をローカル/実験オプションとして使えます。

## 注意事項

> [!CAUTION]
> 安定性はストレージ性能に依存します。信頼性の高い USB メディアを使用してください。

- マウントには管理者権限が必要です。
- Windows の高速スタートアップはマウント失敗の原因になります。完全シャットダウンしてください。
- 未署名ビルドは Gatekeeper にブロックされる場合があります。**プライバシーとセキュリティ**で個別に許可し、Gatekeeper を全体無効にしないでください。
- フォーマットは不可逆です。`ntfsfix` は Windows の `chkdsk` の代替ではありません。

## 実行とビルド

**リリース版**：[タグ](https://github.com/hoochanlon/Free-NTFS-for-Mac/tags) から取得し、`Nigate.app` を「アプリケーション」へ移動。

**ソースから**（macOS 14+、Swift 6 ツールチェーン）：

```sh
git clone https://github.com/hoochanlon/Free-NTFS-for-Mac.git
cd Free-NTFS-for-Mac
swift test
./dev.sh
```

**アプリバンドル / DMG**：

```sh
./macos/Scripts/build.sh          # → dist/Nigate.app（ad-hoc 署名）
./macos/Scripts/package-dmg.sh    # → dist/Nigate-1.6.0.dmg
```

任意の Developer ID + 公証：

```sh
DEVELOPER_ID_APPLICATION="Developer ID Application: Example" \
NOTARY_PROFILE="your-notary-profile" \
NOTARIZE=1 \
./macos/Scripts/build.sh
```

## 構成

```text
Package.swift
macos/Sources/Nigate/              メインアプリ（Domain / Infra / NTFS / App / UI）
macos/Sources/NigateFSKitCore/     FSKit 識別子とマウントバックエンド方針
macos/Sources/NigateFSKitExtension/ FSKit データプレーン（appex）
macos/Sources/NigateNTFSEngine/    拡張向け静的リンク NTFS エンジン
Tests/NigateTests/
docs/README.md
```

## 謝辞

貢献者の皆さまに感謝します。詳細は [ACKNOWLEDGMENTS.md](ACKNOWLEDGMENTS.md)。
