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


## 2. 构建NTFS生态环境

### 2.1 安装fuse 

[整体是一个系统扩展的容器、插件；macFUSE允许您通过第三方文件系统扩展macOS的原生文件处理功能，详情看官网](https://osxfuse.github.io)

homebrew-fuse

```shell
brew tap gromgit/homebrew-fuse
```
安装macfuse

```shell
brew install --cask macfuse
```

### 2.2. 安装ntfs-3g-mac

安装这个就是让Mac支持上ntfs

```shell
brew install ntfs-3g-mac
```

## 3. 使用 

### 3.1. 查看移动硬盘及U盘的挂载信息

`diskutil list` 复制进终端

![](https://fastly.jsdelivr.net/gh/hoochanlon/free-mac-ntfs/shashin/diskutil-list.png)

我们看到：Windows_NTFS KIOXIA（每个U盘的厂家名不一样）记住它旁边的`disk4s1`（每台电脑的显示略有不同，原理一致）

### 3.2. 挂载硬盘

直接挂载容易出现“busy”等无法写入的错误提示。

```shell
# 1. 保险起见，先卸载掉U盘
sudo umount /dev/disk4s1
# 2. 然后再挂载，也就是卸掉后，再来装上去
sudo /System/Volumes/Data/opt/homebrew/bin/ntfs-3g /dev/disk4s1 /Volumes/NTFS -olocal -oallow_other -o auto_xattr
```

![](https://fastly.jsdelivr.net/gh/hoochanlon/free-mac-ntfs/shashin/umount-3g.png)

此时，Mac已经可以正常读写NTFS格式的U盘了（U盘名称拔出及再接上会重新恢复原有的名称的，不用担心），将U盘拔出的话，就需要重新再输入如上命令行才能读写。


## 参考资料

* [iCheer-xu-Macbook pro M1使用免费的方法读写NTFS的折腾之路](https://blog.csdn.net/qq_36071963/article/details/126052367)
* [99度的水K06-解决Mac下NTFS格式移动硬盘无法写入的问题（ntfs-3g安装方法）](https://www.bilibili.com/read/cv18512586/)
* [电脑笔记网-Mac提示要在“恢复”环境中修改安全性设置解决教程](https://www.pcbiji.com/212402.html)



