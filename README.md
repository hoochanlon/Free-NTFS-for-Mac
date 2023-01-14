# Nigate

Nigate，にがて，中译为“苦手”。这是一款支持苹果芯片的Free NTFS for Mac小工具软件，虽然自己购买了[Paragon NTFS For Mac](https://www.paragon-software.com/home/ntfs-mac/)、[TUXERA](https://www.tuxera.com)。可我还是因“兴趣”来折腾一番，主要是为了方便想要免费使用NTFS格式移动存储的文件拷贝与共享的苹果电脑用户。

## 前言

由于[苹果开发者ID太贵](https://blog.csdn.net/Alexander_Wei/article/details/111149103)和[苹果对软件迁移有安装门禁的原因](https://developer.apple.com/cn/developer-id/)，所以[nigate软件版](https://github.com/hoochanlon/Free-NTFS-for-Mac/releases/download/v1.1/nigate.dmg)在使用时，会有“此软件已损坏，扔入废纸篓”的提示弹窗，点击取消，并使用以下指令解除

```shell
sudo xattr -d com.apple.quarantine /Applications/nigate.app
```
 
并且[NTFS不受苹果支持的特殊性](https://zh.wikipedia.org/wiki/NTFS)，需要[关闭SIP与“允许任何来源”](http://www.downza.cn/mac/10419030.html)，以及需放开终端与该软件的[完全磁盘访问权限](https://github.com/MacPaw/PermissionsKit)。软件会自动检测依赖环境安装homebrew，若需手动安装请复制以下指令。

```shell
 /bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"
``` 
  
## [实机视频演示](https://www.bilibili.com/video/BV1XG4y1f79N)

![Watch the video](https://fastly.jsdelivr.net/gh/hoochanlon/free-mac-ntfs/shashin/example.png)

## 快速开始

Mac老鸟或IT人士可使用以下任意指令一键起飞。

在线体验

 ```shell
 /bin/bash -c "$(curl -fsSL https://cdn.statically.io/gh/hoochanlon/Free-NTFS-for-Mac/main/nigate.sh)"
 ```
 
下载到本地目录并本地执行

```shell
curl https://fastly.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac/nigate.sh > ~/Public/nigate.sh && cd /usr/local/bin && sudo ln -s ~/Public/nigate.sh nigate.shortcut && echo "alias nigate='bash nigate.shortcut'" >> ~/.zshrc
```
 
![](https://fastly.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac/shashin/ln-s-to-nigate.png)

后续可直接在终端输入`nigate`开启NTFS读写。[关于读写之后的个性化操作请看](MOCHIAJI.md)


 ## 感谢支持

* [ezntfs](https://github.com/lezgomatt/ezntfs/issues/8#issuecomment-1374428139)
* [kevintao0417](https://github.com/hoochanlon/Free-NTFS-for-Mac/issues/3)
* [吾爱破解论坛的网友们](https://www.52pojie.cn/forum.php?mod=viewthread&tid=1735607&page=1#pid45353784)
* [Nigate issue支持与反馈的所有人](https://github.com/hoochanlon/Free-NTFS-for-Mac/issues/9)


<div align="center">
<i>
<b>Power by Homebrew、Macfuse、NTFS-3G</b>
</i>
</div>


