═══════════════════════════════════════════════════════════
          Nigate - Installation Instructions
          インストール手順 / 使用说明
═══════════════════════════════════════════════════════════

📦 Installation Steps / インストール手順 / 安装步骤：

1. Drag Nigate.app to the "Applications" folder on the right
   Nigate.app を右側の「アプリケーション」フォルダにドラッグしてください
   将 Nigate.app 拖拽到右侧的「应用程序」文件夹

2. If you see "Nigate.app cannot be opened because the
   developer cannot be verified" when first launching,
   please follow these steps to unlock the app:

   初回起動時に「開発元を確認できないため、Nigate.app を開けません」
   と表示される場合は、以下の手順でアプリを解除してください：

   如果首次运行时提示"无法打开，因为无法验证开发者"，
   请按照以下步骤解锁应用：

   【Method 1: Recommended / 方法1：推奨 / 方法一：推荐】
   Open "Terminal" app (in Applications > Utilities),
   copy and run the following command:

   「ターミナル」アプリ（「アプリケーション」>「ユーティリティ」内）
   を開き、以下のコマンドをコピーして実行してください：

   打开「终端」应用（在「应用程序」>「实用工具」中），
   复制并运行以下命令：

   xattr -cr /Applications/Nigate.app

   Then try opening the app again.
   その後、再度アプリを開いてみてください。
   然后再次尝试打开应用。

   【Method 2: If Method 1 doesn't work / 方法2：方法1が効かない場合 / 方法二：如果方法一无效】
   Run the following command in Terminal to disable Gatekeeper:

   ターミナルで以下のコマンドを実行して Gatekeeper を無効化します：

   在终端运行以下命令禁用 Gatekeeper：

   sudo spctl --master-disable

   Then go to "System Settings" > "Privacy & Security"
   and select "Anywhere" option.

   その後、「システム設定」>「プライバシーとセキュリティ」で
   「すべてのソース」オプションを選択してください。

   然后在「系统设置」>「隐私与安全性」中选择「任何来源」选项。

═══════════════════════════════════════════════════════════

💡 Important Notes / 重要な注意事項 / 重要提示：

• Adjust the path in the unlock command based on your
  actual installation location
  解除コマンドのパスは、実際のインストール場所に応じて調整してください
  解锁命令中的路径请根据实际安装位置调整

• If the app is installed elsewhere, modify the path in
  the command accordingly
  アプリが他の場所にインストールされている場合は、
  コマンド内のパスを変更してください
  如果应用安装在其他位置，请修改命令中的路径

• Example: If installed on Desktop, the command would be:
  例：デスクトップにインストールした場合、コマンドは：
  例如：如果安装在桌面，命令为：
  xattr -cr ~/Desktop/Nigate.app

• For more help and issue reports:
  詳細なヘルプと問題報告：
  更多帮助和问题反馈：
  https://github.com/hoochanlon/Free-NTFS-for-Mac

═══════════════════════════════════════════════════════════
