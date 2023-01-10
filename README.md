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

关闭SIP与“允许任何来源”，[Mac新手请看下载之家操作指引](http://www.downza.cn/mac/10419030.html)；以及用以下命令[解除苹果门禁对软件主机迁移的安装限制](https://developer.apple.com/cn/developer-id/)。

```shell
sudo xattr -d com.apple.quarantine /Applications/nigate.app
```


## 报错解答

出现“busy”等无法写入的错误提示，先卸载掉U盘，disk4s1为当前的U盘设备序列名，[官网如是，此类同理](https://github.com/osxfuse/osxfuse/wiki/NTFS-3G)。

![](https://fastly.jsdelivr.net/gh/hoochanlon/free-mac-ntfs/shashin/umount-3g.png)

复制下面两行命令，如上图操作即可。

```shell
sudo umount /dev/disk4s1
```

```shell
sudo /System/Volumes/Data/opt/homebrew/bin/ntfs-3g /dev/disk4s1 /Volumes/NTFS -olocal -oallow_other -o auto_xattr
```

其他现象:

* 移动盘的文件存在非法字符。由用户kevintao0417反馈支持。参考：[issues#3](https://github.com/hoochanlon/Free-NTFS-for-Mac/issues/3#issuecomment-1375314466)
* 由于国内特殊网络环境原因导致homebrew、oxfuse、ntfs-3g其中某项没安装好。参考：[ezntfs/issues/8](https://github.com/lezgomatt/ezntfs/issues/8#issuecomment-1374428139)


<!---
“文件损坏扔入废纸篓”，[是苹果的门禁系统对软件迁移主机进行了限制，详情官网](https://developer.apple.com/cn/developer-id/)，将命令复制到终端回车

```shell
sudo xattr -d com.apple.quarantine /Applications/nigate.app
```

![](https://fastly.jsdelivr.net/gh/hoochanlon/free-mac-ntfs/shashin/fileberak.png)

Error loading Python lib目前版本已解决；pyinstaller制作的程序受限于所在主机环境环境的问题，网上有说配置虚拟环境，但我还是在app程序内嵌入python源文件才搞定。

[关闭SIP](https://www.pcbiji.com/212402.html)与[“允许任何来源”](https://jingyan.baidu.com/article/49ad8bce2f5cee1834d8faaa.html)

-->


 ## 感谢

[osxfuse](https://osxfuse.github.io)、[ezntfs](https://github.com/lezgomatt/ezntfs)、[HomebrewCN](https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh)、[homebrew-install](https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)提供的支持与帮助。
