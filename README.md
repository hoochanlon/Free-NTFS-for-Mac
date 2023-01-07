# Nigate

## 💻 实机演示

视频：https://www.bilibili.com/video/BV1XG4y1f79N

![Watch the video](https://fastly.jsdelivr.net/gh/hoochanlon/free-mac-ntfs/shashin/example.png)

## ⚠️ 注意事项及使用前提

* [关闭SIP](https://www.pcbiji.com/212402.html)
* [安装python]()

### 第二，注意安装依赖项

2. homebrew-fuse && macfuse && ntfs-3g-mac


### 第三，出现“busy”等错误提示，先用umount卸载优盘。

出现“busy”等无法写入的错误提示，先卸载掉U盘。报错也是这样解决，[官网如是说](https://github.com/osxfuse/osxfuse/wiki/NTFS-3G)。disk4s1为当前的U盘设备序列名，其他同理。

```shell
sudo umount /dev/disk4s1
```

## ✅ Mac app使用

如出现文件损坏（苹果签名问题），在终端输入 `sudo xattr -d com.apple.quarantine`，加空格，手动拖入程序到该命令行回车。

1. 把软件拖入到“应用程序”文件夹
2. 首次双击运行软件，程序会检测所需要的集成环境，并自动下载安装（之后不用了）。
3. 运行软件保持在后台，插入U盘即可。

## ⏬ Mac app下载

由 ghproxy 加速下载支持：

https://ghproxy.com/https://github.com/hoochanlon/Free-NTFS-for-Mac/releases/download/0.1/nigate.dmg

## 🧑‍🔧 桌维技术员版

1. 在“shell_for_helpdesk”文件夹。
2. “手动配置NTFS支持环境指导说明.md”即实现方案。
3. 找到 “自动化支持NTFS读写.sh” 下载。
4. 在终端授权脚本文件，如：`chmod 777 自动化支持NTFS读写.sh`，接下来回车这个文件即可。
5. 在“okidoki”文件夹里的python程序用pyinstaller打包成小软件，可做为小程序使用。

## ❤️ 感谢

提供集成应用支持与图标设计样例。

* [osxfuse](https://osxfuse.github.io)
* [sveinbjorn.org](https://sveinbjorn.org/platypus) 
* [langui.net](https://langui.net/new-file-menu/)
* [cunkai/HomebrewCN](https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh)
* [ineo6/homebrew-install](https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)
* [qastack](https://qastack.cn) | [icons8](https://icons8.com) | [gofans](https://gofans.cn)
