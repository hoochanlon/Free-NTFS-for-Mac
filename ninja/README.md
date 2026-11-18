# 🥷Ninja

以下脚本提供命令行方式的 NTFS 和 Linux 文件系统读写支持。

## 读写支持

### NTFS 读写支持

复制粘贴到 ***完全管理权限的终端*** 回车，一键起飞：

```shell
# 中文（默认）
/bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@refs/heads/main/ninja/nigate.sh)"

# 日文
LANG=ja /bin/bash -c "$(curl -fsSL https://cdn.statically.io/gh/hoochanlon/Free-NTFS-for-Mac/main/ninja/nigate.sh)"

# 英文
LANG=en /bin/bash -c "$(curl -fsSL https://cdn.statically.io/gh/hoochanlon/Free-NTFS-for-Mac/main/ninja/nigate.sh)"
```

### Linux ext4 等文件系统读写支持

支持 ext2/3/4、btrfs、xfs、zfs、NTFS、exFAT、LUKS 加密、LVM、RAID 等多种文件系统：

```shell
# 中文（默认）
/bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@refs/heads/main/ninja/kamui.sh)"

# 日文
LANG=ja /bin/bash -c "$(curl -fsSL https://cdn.statically.io/gh/hoochanlon/Free-NTFS-for-Mac/main/ninja/kamui.sh)"

# 英文
LANG=en /bin/bash -c "$(curl -fsSL https://cdn.statically.io/gh/hoochanlon/Free-NTFS-for-Mac/main/ninja/kamui.sh)"
```

### 下载到本地，之后直接输入 `nigate`

```shell
curl https://fastly.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac/ninja/nigate.sh > ~/Public/nigate.sh && sudo -S mkdir -p /usr/local/bin && cd /usr/local/bin && sudo ln -s ~/Public/nigate.sh nigate.shortcut && echo "alias nigate='bash nigate.shortcut'" >> ~/.zshrc && osascript -e 'tell application "Terminal" to do script "nigate"'
```

## 依赖管理

### 一键安装依赖

```shell
# 中文（默认）
/bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/ninja/kunai.sh)"

# 日文
LANG=ja /bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/ninja/kunai.sh)"

# 英文
LANG=en /bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/ninja/kunai.sh)"
```

### 一键卸载依赖

```shell
# 中文（默认）
/bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/ninja/ninpo.sh)"

# 日文
LANG=ja /bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/ninja/ninpo.sh)"

# 英文
LANG=en /bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/ninja/ninpo.sh)"
```

### 系统权限设置

配置系统权限和安全设置（Gatekeeper、SIP 等）：

```shell
# 中文（默认）
/bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/ninja/shuriken.sh)"

# 日文
LANG=ja /bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/ninja/shuriken.sh)"

# 英文
LANG=en /bin/bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac@main/ninja/shuriken.sh)"
```

更多信息请参考：[忍者工具集测试 #39](https://github.com/hoochanlon/Free-NTFS-for-Mac/issues/39) 和 [忍者工具集内容说明](docs/07-忍者工具集内容说明.md)
