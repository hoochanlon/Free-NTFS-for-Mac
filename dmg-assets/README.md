### Nigate 安装说明

#### 一、安装

1. 将 `Nigate.app` 拖到右侧的「应用程序」文件夹。
2. 若首次打开提示「已损坏」或「无法验证开发者」，按下面方法处理。

#### 二、解除限制

##### 方法一（推荐）

1. 双击本 DMG 中的 `提示损坏？点我.command`。
2. 安装后也可与 `Nigate.app` 放在同一目录后运行。
3. 完成后重新打开 Nigate。

##### 方法二（终端）

打开「终端」，执行：

```bash
xattr -cr /Applications/Nigate.app
```

若安装在其他位置，请改路径。例如桌面：

```bash
xattr -cr ~/Desktop/Nigate.app
```

##### 方法三（方法一、二无效时，请谨慎）

在终端执行：

```bash
sudo spctl --master-disable
```

然后打开「系统设置」→「隐私与安全性」，选择「任何来源」。

#### 三、帮助

https://github.com/hoochanlon/Free-NTFS-for-Mac

---

###  Nigate · Installation Guide

#### 1. Install

1. Drag `Nigate.app` to the Applications folder on the right.
2. If macOS says the app is damaged or the developer cannot be verified, use one of the methods below.

#### 2. Unlock the app

##### Method 1 (recommended)

1. Double-click `提示损坏？点我.command` in this DMG.
2. After install, you can also run it next to `Nigate.app`.
3. Then open Nigate again.

##### Method 2 (Terminal)

Open Terminal and run:

```bash
xattr -cr /Applications/Nigate.app
```

If installed elsewhere, change the path. Example (Desktop):

```bash
xattr -cr ~/Desktop/Nigate.app
```

##### Method 3 (last resort; use with care)

In Terminal run:

```bash
sudo spctl --master-disable
```

Then go to **System Settings → Privacy & Security** and choose **Anywhere**.

#### 3. Help

https://github.com/hoochanlon/Free-NTFS-for-Mac
