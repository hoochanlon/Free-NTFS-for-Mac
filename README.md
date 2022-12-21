# Free-Mac-NTFS

Mac自由读写NTFS小攻略及通用小工具

## 充分准备前提（已安装可跳过）

### 1.安装homebrew

复制以下代码粘贴至终端，安装完成重启终端

```shell
/bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"
```

快速通道来自[ineo6](https://github.com/ineo6/homebrew-install)提供

### 2.安装Xcode工具（可选）

⌘+space输入`终端`，打开“终端”，将此命令行复制进去安装 `xcode-select --install' 

## 安装NTFS环境依赖包

### 3. 安装homebrew-fuse

```shell
brew tap gromgit/homebrew-fuse
```

```shell
brew install --cask macfuse
```

### 4. 安装ntfs-3g-mac

```shell
brew install ntfs-3g-mac
```

## 使用 

### 5. 查看移动硬盘及U盘的挂载信息

diskutil list

















