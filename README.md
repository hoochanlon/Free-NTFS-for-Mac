# Nigate

Nigate，苦手，一款macOS平台免费开源的NTFS小程序应用app。

小工具制作原由：Mac平台下支持的NTFS软件，普遍收费。免费的难找，就算找到了又不支持最新的macOS，又或是arm架构芯片...macfuse，对于一个普通用户来说，上手门槛又实在有些高了...整体的体验上不太让人舒服。尤其是对于我们做计算机维护的人来说，更是如此了。

实机演示：

[![Watch the video](https://fastly.jsdelivr.net/gh/hoochanlon/free-mac-ntfs/shashin/example.png)](hhttps://www.bilibili.com/video/BV1XG4y1f79N/)


## 安装使用前提，需要关闭安全性设置

[关机后长按开机键，进入“恢复”环境，在“实用工具”->“启动安全性实用工具”降低安全性的选项全都都勾上](https://www.pcbiji.com/212402.html)（出现不能更改安全性设置，关机盒盖，30秒后再操作一遍即可），这是安装使用学习版软件和系统扩展插件的常规操作，基本上懂点也方便些。

## ⏬ Mac app下载

* 首次运行软件，程序会检测所需要的集成环境，并自动下载安装（之后不用了）。
* 运行软件保持在后台，插入U盘即可。

由 fastgit 加速下载支持：

https://download.fastgit.org/hoochanlon/free-mac-ntfs/releases/download/0.1/nigate.dmg

## 桌维技术人员版(脚本)

1. 在“shell_for_helpdesk”文件夹，找到 “自动化支持NTFS读写.sh” 下载
2. 在终端授权脚本文件，如：`chmod 777 自动化支持NTFS读写.sh`。
3. 在终端下直接 `自动化支持NTFS读写.sh` 回车输入密码即可（只需输入一遍）。

## 感谢

* [osxfuse](https://osxfuse.github.io)
* [cunkai/HomebrewCN](https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh)
* [ineo6/homebrew-install](https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)
* [icons8图标网](https://icons8.com)