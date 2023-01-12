# Nigate

Nigate，にがて，中译为“苦手”。这是一款支持苹果芯片的Free NTFS for Mac小工具软件，虽然自己购买了[Paragon NTFS For Mac](https://www.paragon-software.com/home/ntfs-mac/)、[TUXERA](https://www.tuxera.com)。可我还是因“兴趣”来折腾一番，主要是为了方便想要免费使用NTFS格式移动存储的文件拷贝与共享的苹果电脑用户。

## 前言
 
由于NTFS不受苹果支持的特殊性，需要[关闭SIP与“允许任何来源”](http://www.downza.cn/mac/10419030.html)，以及需放开[终端的完全磁盘访问权限](https://github.com/MacPaw/PermissionsKit)。软件会自动检测依赖环境安装homebrew，若需手动安装请复制以下指令。

```shell
 /bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"
``` 

本人买不起[苹果开发者ID](https://blog.csdn.net/Alexander_Wei/article/details/111149103)，所以[nigate软件](https://github.com/hoochanlon/Free-NTFS-for-Mac/releases/download/v1.1/nigate.dmg)在使用时，需以下指令解除[苹果对软件迁移安装的门禁](https://developer.apple.com/cn/developer-id/)。

```shell
sudo xattr -d com.apple.quarantine /Applications/nigate.app
```
  
## [实机视频演示](https://www.bilibili.com/video/BV1XG4y1f79N)

![Watch the video](https://fastly.jsdelivr.net/gh/hoochanlon/free-mac-ntfs/shashin/example.png)

## 快速开始

Mac老鸟或IT人士可使用以下任意指令一键起飞。

在线体验

 ```shell
 /bin/bash -c "$(curl -fsSL https://cdn.statically.io/gh/hoochanlon/Free-NTFS-for-Mac/main/nigate.sh)"
 ```
 
本地执行

```shell
cd /usr/local/bin && sudo ln -s ~/Public/nigate.sh nigate.shortcut && echo "alias nigate='bash nigate.shortcut'" >> ~/.zshrc
```
 
![](https://fastly.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac/shashin/ln-s-to-nigate.png)


## 个性化
 
**重命名及格式化U盘，需用 `diskutil list` 查看挂载盘ID方可对应操作。**

### 重命名
 
![](https://fastly.jsdelivr.net/gh/hoochanlon/free-mac-ntfs/shashin/rename.png)
 
 
 ```shell
 sudo umount /dev/disk4s2
 ```
 
 ```shell
 sudo ntfslabel /dev/disk4s2 carsh
 ```
 
### 格式化为NTFS

![](https://fastly.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac/shashin/formatntfs.png)
 
```shell
 sudo diskutil unmount /dev/disk4s1
```
 
```shell
 sudo mkntfs -f /dev/disk4s1
```
</details>



 ## 感谢支持

* [ezntfs](https://github.com/lezgomatt/ezntfs/issues/8#issuecomment-1374428139)
* [kevintao0417](https://github.com/hoochanlon/Free-NTFS-for-Mac/issues/3)
* [Nigate issue支持与反馈的所有人](https://github.com/hoochanlon/Free-NTFS-for-Mac/issues/9)


<div align="center">
## ***Power by Homebrew、Macfuse、NTFS-3G***
</div>


