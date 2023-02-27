# Nigate

Nigate，にがて，中译为“苦手”。这是一款支持苹果芯片的Free NTFS for Mac小工具软件，主要是为了方便想要免费使用NTFS格式移动存储的文件拷贝与共享的苹果电脑用户。<a href="https://www.bilibili.com/video/BV1XG4y1f79N">视频演示</a>。

特别感谢：

* [APPERK](https://fastly.jsdelivr.net/gh/hoochanlon/free-mac-ntfs/shashin/friend's_wx.jpg)，投入了大量时间与精力，梳理的代码逻辑，并对英特尔芯片兼容的特别工作，与图文并茂分解式说明，更易理解，也降低初期使用的前提知识储备 👉 [Mac NTFS 读写的白嫖方案](https://mp.weixin.qq.com/s/kHOsdXLXlFBardoSAsaXiA)。
* [琛少君](https://space.bilibili.com/32713000)和[配主机网](https://www.peizhuji.com)，在有着众多不错界面的NTFS软件，还能对款脚本终端小工具热情支持。
* [lezgomatt](https://github.com/lezgomatt)，虽然交流语言不通，但还是热心回答我的问题。

## 快速开始，三种方式，任选其一

一、在线体验，复制粘贴到 ***完全管理权限的终端*** 回车，一键起飞。

 ```shell
 /bin/bash -c "$(curl -fsSL https://cdn.statically.io/gh/hoochanlon/Free-NTFS-for-Mac/main/nigate.sh)"
 ```

二、下载到本地，往后开启可直接输入`nigate`

```shell
curl https://fastly.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac/nigate.sh > ~/Public/nigate.sh && sudo -S mkdir -p /usr/local/bin && cd /usr/local/bin && sudo ln -s ~/Public/nigate.sh nigate.shortcut && echo "alias nigate='bash nigate.shortcut'" >> ~/.zshrc && osascript -e 'tell application "Terminal" to do script "nigate"'
```

三、下载使用 

https://github.com/hoochanlon/Free-NTFS-for-Mac/releases/tag/v1.1 （更新 2023.2.24）

![ ](https://fastly.jsdelivr.net/gh/hoochanlon/free-mac-ntfs/shashin/example.png)

### 其他补充

打开软件[弹窗“文件已损坏，扔入废纸篓”，需解除苹果对软件的门禁限制](https://github.com/hoochanlon/Free-NTFS-for-Mac/issues/9#issue-1527116834)。拷贝几十百来G的资料，需注意让Mac处于激活的常亮状态，可在终端输入指令`caffeinate`。

关于读写之后的个性化操作，[点击翻阅：MOCHIAJI.md](MOCHIAJI.md)；以及实现原理，[点击详情：SEMMEISHO.md](helpdesk/SEMMEISHO.md)；软件收集与逆向学习研究，[点击我的收录单：软件分享及网页备份](https://github.com/hoochanlon/w3-goto-world/blob/master/软件分享及网页备份/README.md)![](https://img.shields.io/github/stars/hoochanlon/w3-goto-world?color=green&style=social)。


## 感谢


* [吾爱破解论坛的网友们](https://www.52pojie.cn/forum.php?mod=viewthread&tid=1735607&page=1#pid45353784)
* [对破解论坛及资源站点收集的百度知道网友们](https://zhidao.baidu.com/question/1988486592586723387.html)
* [APPERK](https://mp.weixin.qq.com/s/ByEBBCXFUmfBqF506F-Cvg)、[琛少君](https://space.bilibili.com/32713000)、[配主机网](https://www.peizhuji.com)、[ezntfs](https://github.com/lezgomatt/ezntfs/issues/8#issuecomment-1374428139)、[kevintao0417](https://github.com/hoochanlon/Free-NTFS-for-Mac/issues/3)、[itfanr](https://www.52pojie.cn/forum.php?mod=redirect&goto=findpost&ptid=1735607&pid=45507166)、[佛系软件](https://foxirj.com)


<div align="center">
<i>
<b>Power by Homebrew、Macfuse、NTFS-3G</b>
</i>
</div>


<!-- ![](https://fastly.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac/shashin/ln-s-to-nigate.png) -->
