# Free-Mac-NTFS

Mac自由读写NTFS小攻略及通用小工具

## 充分准备前提（已安装及已配置SIP可跳过）

### 1.安装homebrew

复制以下代码粘贴至终端，安装完成重启终端

```shell
/bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"
```

快速通道来自[ineo6](https://github.com/ineo6/homebrew-install)提供

### 2.安装Xcode工具（可选）

⌘+space输入`终端`，打开“终端”，将此命令行复制进去安装 `xcode-select --install' 

### 3. 关闭SIP






## 安装NTFS环境依赖包

### 3. 安装fuse

homebrew-fuse

```shell
brew tap gromgit/homebrew-fuse
```
macfuse

```shell
brew install --cask macfuse
```

### 4. 安装ntfs-3g-mac

```shell
brew install ntfs-3g-mac
```

## 使用 

### 5. 查看移动硬盘及U盘的挂载信息

`diskutil list` 复制进终端, Windows_NTFS KIOXIA（每个U盘的厂家名不一样）记住它旁边的`diskAs1`（每台电脑的显示略有不同）

![](https://fastly.jsdelivr.net/gh/hoochanlon/free-mac-ntfs/shashin/diskutil-list.png)

### 6. 挂载硬盘

```shell
sudo /System/Volumes/Data/opt/homebrew/bin/ntfs-3g /dev/disk4s1 /Volumes/NTFS -olocal -oallow_other -o auto_xattr
```










