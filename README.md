# Nigate

一款支持苹果芯片的Free NTFS for Mac小工具软件。[oxfuse](https://osxfuse.github.io)、[ntfs-3g](https://github.com/osxfuse/osxfuse/wiki/NTFS-3G#installation)方案集成整合，与[ezntfs CLI](https://github.com/lezgomatt/ezntfs)异曲同工。

## 实机演示

使用软件时，小窗口应保持在后台，请看视频：https://www.bilibili.com/video/BV1XG4y1f79N

![Watch the video](https://fastly.jsdelivr.net/gh/hoochanlon/free-mac-ntfs/shashin/example.png)

## 先决条件

安装homebrew

```shell
/bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"
```

安装python

```shell
brew install python
```

关闭SIP与“允许任何来源”，[请看由“下载之家”提供的操作指引](http://www.downza.cn/mac/10419030.html)；以及用以下命令解除[苹果对软件迁移安装的门禁](https://developer.apple.com/cn/developer-id/)。

```shell
sudo xattr -d com.apple.quarantine /Applications/nigate.app
```

## 进阶技巧

重命名U盘

![](https://fastly.jsdelivr.net/gh/hoochanlon/free-mac-ntfs/shashin/rename.png)

```shell
diskutil list
```

```shell
sudo umount /dev/disk4s2 && ntfslabel /dev/disk4s2 carsh
```

 ## 感谢

[osxfuse](https://osxfuse.github.io)、[ezntfs](https://github.com/lezgomatt/ezntfs)、[HomebrewCN](https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh)、[homebrew-install](https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)、[downza](http://www.downza.cn/mac/10419030.html)提供的支持与帮助。
