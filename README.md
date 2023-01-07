# Nigate

Free NTFS for Mac

## 实机演示

视频：https://www.bilibili.com/video/BV1XG4y1f79N

![Watch the video](https://fastly.jsdelivr.net/gh/hoochanlon/free-mac-ntfs/shashin/example.png)

## 先决条件

homebrew

```shell
/bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"
```

python

```shell
brew install python
```

最后调整Mac系统设置：[关闭SIP](https://www.pcbiji.com/212402.html)、[“允许任何来源”](https://jingyan.baidu.com/article/49ad8bce2f5cee1834d8faaa.html)。


## 报错解决

**出现“busy”等错误提示**

出现“busy”等无法写入的错误提示，先卸载掉U盘。报错也是这样解决，[官网如是说](https://github.com/osxfuse/osxfuse/wiki/NTFS-3G)。disk4s1为当前的U盘设备序列名，其他同理。

```shell
sudo umount /dev/disk4s1
```

```shell
sudo /System/Volumes/Data/opt/homebrew/bin/ntfs-3g /dev/disk4s1 /Volumes/NTFS -olocal -oallow_other -o auto_xattr
```

![](https://fastly.jsdelivr.net/gh/hoochanlon/free-mac-ntfs/shashin/umount-3g.png)

**文件损坏扔入废纸篓**

![](https://fastly.jsdelivr.net/gh/hoochanlon/free-mac-ntfs/shashin/fileberak.png)

这是苹果签名问题，在终端输入 `sudo xattr -d com.apple.quarantine`，加空格，手动拖入程序到该命令行回车。

## 感谢

* [osxfuse](https://osxfuse.github.io)
* [lezgomatt/ezntfs](https://github.com/lezgomatt/ezntfs)
* [cunkai/HomebrewCN](https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh)
* [ineo6/homebrew-install](https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)
