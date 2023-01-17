# Nigate

Nigate，にがて，中译为“苦手”。这是一款支持苹果芯片的Free NTFS for Mac小工具软件，主要是为了方便想要免费使用NTFS格式移动存储的文件拷贝与共享的苹果电脑用户。

## 前言

由于[苹果对软件迁移有安装门禁的原因](https://developer.apple.com/cn/developer-id/)，所以[nigate软件版](https://github.com/hoochanlon/Free-NTFS-for-Mac/releases/download/v1.1/nigate.dmg)在使用时，会有“此软件已损坏，扔入废纸篓”的提示弹窗，点击取消，并使用以下指令解除。

```shell
sudo xattr -d com.apple.quarantine /Applications/nigate.app
```
 
并且NTFS不受苹果支持的特殊性，需要关闭SIP与“允许任何来源”，以及需放开终端的完全文件夹磁盘访问权限。

## [实机视频演示](https://www.bilibili.com/video/BV1XG4y1f79N)

![Watch the video](https://fastly.jsdelivr.net/gh/hoochanlon/free-mac-ntfs/shashin/example.png)

## 快速开始

在线体验，Mac老鸟或IT人士可使用以下任意指令一键起飞。

 ```shell
 /bin/bash -c "$(curl -fsSL https://cdn.statically.io/gh/hoochanlon/Free-NTFS-for-Mac/main/nigate.sh)"
 ```
 
下载到本地并运行，往后可直接使用`nigate`开启NTFS读写。

```shell
curl https://fastly.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac/nigate.sh > ~/Public/nigate.sh && sudo -S mkdir -p /usr/local/bin && cd /usr/local/bin && sudo ln -s ~/Public/nigate.sh nigate.shortcut && echo "alias nigate='bash nigate.shortcut'" >> ~/.zshrc && osascript -e 'tell application "Terminal" to do script "nigate"'
```
 
![](https://fastly.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac/shashin/ln-s-to-nigate.png)

[关于读写之后的个性化操作，点击翻阅 MOCHIAJI.md](MOCHIAJI.md)。



## 感谢支持与鼓励

* [ezntfs](https://github.com/lezgomatt/ezntfs/issues/8#issuecomment-1374428139)
* [kevintao0417](https://github.com/hoochanlon/Free-NTFS-for-Mac/issues/3)
* [吾爱破解论坛的网友们](https://www.52pojie.cn/forum.php?mod=viewthread&tid=1735607&page=1#pid45353784)
* [B站软件体验者：琛少君](https://space.bilibili.com/32713000)
* [Nigate issue支持与反馈的所有人](https://github.com/hoochanlon/Free-NTFS-for-Mac/issues/9)


<div align="center">
<i>
<b>Power by Homebrew、Macfuse、NTFS-3G</b>
</i>
</div>


