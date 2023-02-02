# Nigate

Nigate，にがて，中译为“苦手”。这是一款支持苹果芯片的Free NTFS for Mac小工具软件，主要是为了方便想要免费使用NTFS格式移动存储的文件拷贝与共享的苹果电脑用户。<a href="https://www.bilibili.com/video/BV1XG4y1f79N">视频演示</a>。

## 快速开始，三种方式，任选其一

一、在线体验，复制粘贴到 ***完全管理权限的终端*** 回车，一键起飞。

 ```shell
 /bin/bash -c "$(curl -fsSL https://cdn.statically.io/gh/hoochanlon/Free-NTFS-for-Mac/main/nigate.sh)"
 ```

二、下载到本地，往后开启可直接输入`nigate`

```shell
curl https://fastly.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac/nigate.sh > ~/Public/nigate.sh && sudo -S mkdir -p /usr/local/bin && cd /usr/local/bin && sudo ln -s ~/Public/nigate.sh nigate.shortcut && echo "alias nigate='bash nigate.shortcut'" >> ~/.zshrc && osascript -e 'tell application "Terminal" to do script "nigate"'
```

三、下载使用 <a href="https://github.com/hoochanlon/Free-NTFS-for-Mac/releases/download/v1.1/nigate.dmg">Nigate 软件版</a>，打开软件[弹窗“文件已损坏，扔入废纸篓”，需解除苹果对软件的门禁限制](https://github.com/hoochanlon/Free-NTFS-for-Mac/issues/9#issue-1527116834)。

![ ](https://fastly.jsdelivr.net/gh/hoochanlon/free-mac-ntfs/shashin/example.png)


关于读写之后的个性化操作，[点击翻阅 MOCHIAJI.md](MOCHIAJI.md)；以及实现原理，[点击详情 SEMMEISHO.md](helpdesk/SEMMEISHO.md)。拷贝50-60G的文件，注意不能休眠，使用`caffeinate`，让电脑处于常亮状态。


## 感谢支持与鼓励


* [吾爱破解论坛的网友们](https://www.52pojie.cn/forum.php?mod=viewthread&tid=1735607&page=1#pid45353784)
* [百度知道网友：瓜子吧3（类似的破解论坛）](http://zhidao.baidu.com/question/1988486592586723387/answer/1824407923)
* [微信公众号：APPERK](https://mp.weixin.qq.com/s/ByEBBCXFUmfBqF506F-Cvg)
* [B站软件体验者：琛少君](https://space.bilibili.com/32713000)
* [佛系软件](https://foxirj.com)
* [ezntfs](https://github.com/lezgomatt/ezntfs/issues/8#issuecomment-1374428139)
* [kevintao0417](https://github.com/hoochanlon/Free-NTFS-for-Mac/issues/3)
* [Nigate issue支持与反馈的所有人](https://github.com/hoochanlon/Free-NTFS-for-Mac/issues/9)


<div align="center">
<i>
<b>Power by Homebrew、Macfuse、NTFS-3G</b>
</i>
</div>


<!-- ![](https://fastly.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac/shashin/ln-s-to-nigate.png) -->
