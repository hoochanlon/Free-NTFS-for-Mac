# Free-Mac-NTFS

Mac自由读写NTFS小攻略及通用小工具

## 1. 充分准备前提（已安装及已配置SIP可跳至第二大步）

### 1.1. 安装homebrew

复制以下代码粘贴至终端，安装完成重启终端

```shell
/bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"
```

快速通道来自[ineo6](https://github.com/ineo6/homebrew-install)提供

### 1.2. 关闭安全性设置

1. “通用”中“隐私与安全性”，允许任何来源，可直接终端 `sudo spctl --master-disable`
2. 关闭SIP，输入后 `csrutil disable`重启
3. [关机后长按开机键，进入“恢复”环境，在“实用工具”->“启动安全性实用工具”降低安全性的选项全都都勾上](https://www.pcbiji.com/212402.html)（出现不能更改安全性设置，关机盒盖，30秒后再操作一遍即可）


### 1.3. 安装Xcode工具（可选）

⌘+space输入`终端`，打开“终端”，将此命令行复制进去安装 `xcode-select --install` 


## 2. 安装NTFS环境依赖包

### 2.1. 安装fuse

homebrew-fuse

```shell
brew tap gromgit/homebrew-fuse
```
macfuse

```shell
brew install --cask macfuse
```

### 2.2. 安装ntfs-3g-mac

```shell
brew install ntfs-3g-mac
```

## 3. 使用 

### 3.1. 查看移动硬盘及U盘的挂载信息

`diskutil list` 复制进终端

![](https://fastly.jsdelivr.net/gh/hoochanlon/free-mac-ntfs/shashin/diskutil-list.png)

我们看到：Windows_NTFS KIOXIA（每个U盘的厂家名不一样）记住它旁边的`disk4s1`（每台电脑的显示略有不同，原理一致）

### 3.2. 挂载硬盘

```shell
sudo /System/Volumes/Data/opt/homebrew/bin/ntfs-3g /dev/disk4s1 /Volumes/NTFS -olocal -oallow_other -o auto_xattr
```

### 3.3. 失败再重来（卸载再挂载）

```shell

```








