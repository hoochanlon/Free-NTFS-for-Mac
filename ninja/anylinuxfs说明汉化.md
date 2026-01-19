# anylinuxfs

在 Mac 上挂载 ext4、btrfs 或任何 Linux 支持的文件系统的简单方法。
基于 libkrun microVM 管理程序和 NFS，提供完整的写入支持。不需要安装任何内核扩展或降低系统安全性。

<a href='https://ko-fi.com/Q5Q41EHAGK' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://storage.ko-fi.com/cdn/kofi1.png?v=6' border='0' alt='Buy Me a Coffee at ko-fi.com' /></a>

> [!IMPORTANT]
> **低内存导致的 VM 冻结问题现已修复！** 请确保您运行的是 libkrun 1.17 或更新版本（`brew update && brew upgrade libkrun`）。
> 然后您应该可以再次运行内存少于 1 GB 的 VM（参见 `anylinuxfs config -r`）。

## 功能特性

- 挂载 Linux 支持的任何文件系统（**ext4**、**btrfs**、**xfs** 等，也包括 **NTFS** 和 **exFAT**）
- 支持 **LUKS** 加密驱动器
- 支持 **BitLocker** 加密驱动器 - **NTFS** 或 **FAT32**（使用恢复密钥作为密码）
- 支持 **LVM**（甚至跨多个驱动器的卷组）
- 支持 **LUKS 上的 LVM**（即加密的 LVM）
- 支持 **Linux RAID**（mdadm）和**多磁盘 btrfs**
- 支持 **ZFS**（包括原生 ZFS 加密）
- 适用于外部和内部驱动器
- 适用于磁盘映像
- 支持带有 **GPT**、**MBR** 或无分区表的磁盘（单个文件系统或 LVM/LUKS 容器）
- NFS 共享默认只能从 localhost 访问，但也可以通过网络共享
- 定义您自己的[自定义操作](#custom-actions)（例如，挂载位于 Linux 驱动器上的 **borg 备份**）

## 限制

- 一次只能挂载一个驱动器（未来可能会改进）
- 仅支持 Apple Silicon Mac（libkrun 限制）

> [!CAUTION]
> 在使用 anylinuxfs 处理 **NTFS** 之前，请阅读[注意事项](#ntfs)

## 安装

```bash
brew tap nohajc/anylinuxfs
brew install anylinuxfs
```

## 演示

https://github.com/user-attachments/assets/6ec6ce46-ce08-45b9-9fa4-e3d6d078d811

## 简介

在 macOS 上挂载第三方文件系统一直很棘手。官方支持读取 NTFS，但除此之外，我们主要使用基于 macFUSE 的解决方案。
我们有 NTFS-3g，这是一个相当成熟的驱动程序，但对于 Linux 文件系统，只有一些实验性解决方案，如 [fuse-ext2](https://github.com/alperakcan/fuse-ext2) 或 [ext4fuse](https://github.com/gerard/ext4fuse)。

如果您想要一个具有写入访问权限的可靠解决方案，您需要运行一个具有物理磁盘访问权限的 Linux 虚拟机，并负责将挂载的文件系统暴露给主机。
这正是 `anylinuxfs` 所做的，它简化了这个过程，就像在终端中运行一个命令一样简单。

您选择一个驱动器，使用 `anylinuxfs` 挂载它，它就会作为 localhost 上的 NFS 共享出现。这会在后台启动一个 microVM，它使用真正的 Linux 驱动程序，因此您可以访问从 `ext*` 到 `btrfs` 的任何内容。命令行上的任何挂载选项都会转发到 Linux mount 命令，因此您可以只读挂载、读写挂载、选择 btrfs 子卷等。然后，您只需在 Finder 中弹出驱动器或在终端中使用 `anylinuxfs unmount`，虚拟机就会关闭。

这听起来像是很多工作，但实际上非常快。不像传统的虚拟机需要一段时间才能启动。
这只是一个精简版的 Linux，甚至没有 UEFI 固件。实际上，驱动器挂载并准备使用只需要几秒钟。

## 基本用法

最常用的命令如下：
* `anylinuxfs mount` - 挂载文件系统；这是默认命令，因此可以省略 `mount` 关键字
* `anylinuxfs unmount` - 安全卸载，在需要按特定顺序弹出的多个挂载（通常是 ZFS 数据集）的情况下很有用
* `anylinuxfs list` - 显示可用的 Linux 文件系统（或者，`anylinuxfs list -m` 显示 Microsoft 文件系统）
* `anylinuxfs status` - 显示当前挂载的内容
* `anylinuxfs log` - 显示当前（或最后一次）运行的详细信息，对故障排除很有用

### 挂载文件系统

从 `anylinuxfs mount --help`：

```
用法: anylinuxfs [mount] [选项] <磁盘标识> [挂载点]

参数:
  <磁盘标识>   文件路径、LVM 标识符或 RAID 标识符，例如：
               /dev/diskXsY[:/dev/diskYsZ:...]
               lvm:<卷组名>:diskXsY[:diskYsZ:...]:<逻辑卷名>
               raid:diskXsY[:diskYsZ:...]
               （参见 `list` 命令输出以获取可用卷）
  [挂载点]    自定义挂载路径，覆盖 /Volumes 下的默认路径
```

* 唯一必需的参数是磁盘标识符。
* 它必须始终引用一个或多个分区或逻辑卷（不是整个磁盘）。
* 标识符的基本语法是 `/dev/diskXsY` - 基于 `anylinuxfs list` 或 `diskutil list` 如何识别您的驱动器。
* 如果您的文件系统位于逻辑卷上，您通常需要一个以 `lvm` 或 `raid` 开头的特殊前缀标识符（用于 mdadm Linux RAID）。
  这些可以从 `anylinuxfs list` 输出中推断出来，其中任何逻辑卷都会显示为合成磁盘（类似于 `diskutil` 对 APFS 容器的处理方式）
* 对于跨多个磁盘的 btrfs 文件系统（如 RAID1 或 JBOD），这些不会在 `anylinuxfs list` 输出中分组。
* 为了挂载这样的文件系统，您使用 `/dev/diskXsY:/dev/diskYsZ` 语法。基本上，您必须指定需要附加到我们的 microVM 的所有分区，以便可以扫描任何多磁盘 btrfs 文件系统。

## 示例

**列出具有 Linux 文件系统的可用驱动器**

```bash
sudo anylinuxfs list
```

```
/dev/disk0 (internal, physical):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:      GUID_partition_scheme                        *500.3 GB   disk0
   5:                       ext4 BOOT                    1.0 GB     disk0s5
   6:                      btrfs fedora                  144.2 GB   disk0s6

/dev/disk7 (external, physical):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:     FDisk_partition_scheme                        *30.8 GB    disk7
   1:                LVM2_member                         30.8 GB    disk7s1

/dev/disk8 (external, physical):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:      GUID_partition_scheme                        *4.2 GB     disk8
   1:                LVM2_member                         4.2 GB     disk8s1

/dev/disk9 (external, physical):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:                crypto_LUKS                        *8.1 GB     disk9

/dev/disk10 (disk image):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:     FDisk_partition_scheme                        +268.4 MB   disk10
   1:          linux_raid_member debian:0                267.4 MB   disk10s1

/dev/disk11 (disk image):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:      GUID_partition_scheme                        +268.4 MB   disk11
   1:          linux_raid_member debian:0                266.3 MB   disk11s1

raid:disk10s1:disk11s1 (volume):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:                       ext4 raid-test               265.3 MB   disk10s1:disk11s1

lvm:vg1 (volume group):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:                LVM2_scheme                        +35.0 GB    vg1
                                 Physical Store disk7s1
                                                disk8s1
   1:                       ext4 lvol0                   15.4 GB    vg1:disk7s1:lvol0
   2:                        xfs lvol1                   7.7 GB     vg1:disk7s1:lvol1
   3:                      btrfs lvol2                   11.9 GB    vg1:disk7s1:disk8s1:lvol2
```

**列出具有 Microsoft 文件系统的可用驱动器（NTFS、exFAT、FAT32）**

```bash
sudo anylinuxfs list -m
```

**读写挂载分区**

```bash
sudo anylinuxfs /dev/disk0s6
```

**只读挂载分区**

```bash
sudo anylinuxfs /dev/disk0s6 -o ro
```

**挂载来自卷组 vg1 的逻辑卷，由 disk7s1 支持**

```bash
sudo anylinuxfs lvm:vg1:disk7s1:lvol0
```

**挂载来自卷组 vg1 的逻辑卷，由 disk7s1 和 disk8s1 支持**

```bash
sudo anylinuxfs lvm:vg1:disk7s1:disk8s1:lvol2
```

**挂载由 disk10s1 和 disk11s1 支持的 RAID 卷**

```bash
sudo anylinuxfs raid:disk10s1:disk11s1
```

**列出可用驱动器并解密 disk9 的 LUKS 或 BitLocker 元数据**

```bash
sudo anylinuxfs list -d /dev/disk9
```

输出将显示加密分区的文件系统和标签

```
...
/dev/disk9 (external, physical):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:          crypto_LUKS: ext4 enc-ext4               *8.1 GB     disk9
...
```

**列出可用驱动器并解密所有 LUKS 或 BitLocker 元数据**

可能会显示加密的 LVM 卷组或其他文件系统信息

```bash
sudo anylinuxfs list -d all
```

[更多信息请参见此处](docs/luks-lvm.md)

**挂载 LUKS 加密或 BitLocker 加密分区**

```bash
# anylinuxfs 将显示交互式密码提示
sudo anylinuxfs /dev/disk9

# 或者可以从环境变量中获取密码
export ALFS_PASSPHRASE="my_strong_password"
sudo -E anylinuxfs /dev/disk9
```

> [!NOTE]
> 如果您有多个使用不同密码的磁盘，可以定义名为 `ALFS_PASSPHRASE1`、`ALFS_PASSPHRASE2`、`ALFS_PASSPHRASE3` 等的变量。

**挂载分区并通过 NFS 将其共享到任何子网中的其他设备**

```bash
sudo anylinuxfs /dev/disk0s6 -b 0.0.0.0
```

**挂载分区并通过 NFS 将其共享到子网内的设备（更安全）**

```bash
# 服务器是指共享挂载文件系统的设备
sudo anylinuxfs /dev/disk0s6 -b <您的服务器IP>
```

**显示当前挂载状态**

```bash
anylinuxfs status
```

**尝试停止 anylinuxfs，以防卸载或弹出没有完全终止 VM**

```bash
anylinuxfs stop
```

## 自定义操作

使用自定义操作，您可以定义在虚拟机的特定点运行的脚本集。
当前支持的操作：`before_mount`、`after_mount`、`before_unmount`（通常用于清理）。
您还可以覆盖虚拟机内通过 NFS 与 macOS 共享的路径。这对于挂载嵌套文件系统（来自磁盘映像等）很有用。

您的自定义操作还可以依赖于默认情况下不包含在基础 Linux 安装中的其他包。`anylinuxfs` 为此目的公开了 Alpine 包管理器。这意味着它可以维护用户安装的额外包列表，并在您重新初始化 Linux 映像时（或当 `anylinuxfs` 升级强制重新初始化时）重新安装它们。

### 预定义操作

有一些随 `anylinuxfs` 预安装的自定义操作。您可以检查 `/opt/homebrew/etc/anylinuxfs.toml` 配置文件。对于您定义的任何其他操作，请使用 `~/.anylinuxfs/config.toml`。

### 列出可用操作

要快速检查哪些操作可用，请运行 `anylinuxfs actions`，它将为您提供它们的名称和描述。任何修改都直接在配置文件中完成。

### 示例

#### 挂载位于 Linux 驱动器上的 borg 备份

为此，我们首先需要安装额外的 alpine 包：

```bash
anylinuxfs apk add borgbackup fuse py3-llfuse
```

然后我们通过编辑（或创建）`~/.anylinuxfs/config.toml` 来定义自定义操作：

```toml
[custom_actions.borg]
after_mount = "mkdir -p /mnt/borg && borg mount $ALFS_VM_MOUNT_POINT/$BORG_REPO /mnt/borg"
before_unmount = "borg umount /mnt/borg && rmdir /mnt/borg"
override_nfs_export = "/mnt/borg"
```

您可以从自定义操作中引用环境变量。以 `$ALFS_` 开头的变量由 anylinuxfs 设置。任何其他变量必须由用户设置。
如果您希望自定义操作使用脚本中未明确使用的任何其他环境变量（例如 borg 可能使用 `$BORG_PASSPHRASE`），您可以像这样列出它们：

```toml
[custom_actions.borg]
after_mount = "..."
before_unmount = "..."
capture_environment = ["BORG_PASSPHRASE"]
override_nfs_export = "/mnt/borg"
```

在挂载驱动器时调用您的操作，使用 `-a` 标志（并确保 sudo 保留您的环境）：

```bash
export BORG_REPO=<相对于挂载点的 borg 仓库路径>
sudo -E anylinuxfs mount /dev/disk4s2 -a borg
```

系统会要求您输入密码（如果您没有设置 `capture_environment` 并导出 `BORG_PASSPHRASE`），您的 borg 备份将被挂载，而不是整个 Linux 驱动器。

## 注意事项

### VM 初始化

- 当您首次运行 `anylinuxfs` 挂载驱动器时，它将从 Docker hub 下载 alpine Linux 映像并将其解压到您的用户配置文件（`~/.anylinuxfs/alpine`）。
然后它将启动一个 VM，以便可以安装依赖项并执行初始环境设置。之后，Linux 根文件系统将在每次挂载操作中重复使用。
您也可以随时运行 `anylinuxfs init` 下载 `alpine:latest` 的新副本并重新初始化环境。

### 自定义 CA 证书

- 如果您需要为 alpine VM 添加自定义 CA 证书以下载包，可以通过将它们添加到用户配置文件中的文件（`~/.anylinuxfs/ca-certificates.crt`）来实现。CA 证书必须是换行符分隔的 PEM 块。这些将在首次运行 `anylinuxfs` 时或调用 `anylinuxfs init` 时附加到 alpine 映像默认值。

### 权限

- 需要使用 `sudo` 运行挂载命令，否则我们不允许直接访问 `/dev/disk*` 文件。但是，虚拟机本身实际上将在最初调用 `sudo` 的普通用户下运行（即，在打开磁盘后，所有不必要的权限都会被丢弃）

### LUKS 的内存要求

- 当您挂载 LUKS 加密驱动器时，microVM 需要至少 2.5 GiB RAM 才能使 cryptsetup 正常工作。如果您的 VM 配置的内存较少，您会收到警告，RAM 配置将自动调整。如果您不想看到警告，请将默认 RAM 设置为满足此要求（`anylinuxfs config -r <大小（MiB）>`）
- 配置的 RAM 量是可以分配的最大值。VM 实际消耗的内存量可能更低。

### NTFS

* anylinuxfs 提供两种不同的 NTFS 驱动程序
  - 基于用户空间 FUSE 的 **ntfs-3g**（更好的兼容性）
  - 更新的内核空间 **ntfs3**（显著更好的性能）
* **ntfs-3g** 默认使用
* **ntfs3** 可以通过在挂载时指定 `-t ntfs3` 选项来使用
* 需要记住的重要事项
  - **ntfs3** 无法挂载来自已休眠或启用了快速启动的 Windows 系统的 NTFS 驱动器
  - **ntfs-3g** 在这种情况下会回退到只读挂载并发出警告
  - **ntfs3** 通常会在驱动器有任何文件系统错误时拒绝挂载
  - 使用任何非官方工具（如 `ntfsfix`）清除脏标志实际上不会修复这些错误，并可能导致进一步的数据损坏！
  - Windows 上的 `chkdsk` 是修复 NTFS 错误的推荐方法
  - 一些用户在使用 Paragon 的 [`chkntfs`](https://gist.github.com/nohajc/51fdecb2dda75dd8c600173ea42b3700)（专有）方面也有良好的体验
  - 使用 **ntfs3** 处理 Windows 系统驱动器时报告了权限问题
  - 具体来说，`/Program Files` 和 `/Users` 中的某些文件夹是只读的（详细信息请参见此 [reddit](https://www.reddit.com/r/archlinux/comments/r325t3/permissions_problems_with_the_new_ntfs3_driver/) 帖子）

**总结**
* 网上有关于 **ntfs3** 驱动程序导致数据损坏（或系统冻结）的报道。
* 它们可能或可能不是由 `ntfsfix` 的不当使用引起的。
* **ntfs3** 包含在主流 Linux 内核中，因此被认为是稳定的。它由 Paragon Software 在 [2021](https://www.paragon-software.com/paragon-software-announces-the-inclusion-of-its-ntfs3-driver-into-linux-kernel-5-15/) 年贡献。
* 如果您信任它，想要最佳性能，并且可以接受 Windows 系统驱动器上的不一致权限，请使用 **ntfs3**
* 否则，您最好使用默认且更成熟的 **ntfs-3g**

## 故障排除

- 确保端口 2049、32765 和 32767 上没有运行任何程序。如果已经有另一个 NFS 服务器在运行，`anylinuxfs` 将无法工作。
- 检查您的挂载标志（例如，演示中的 `subvol` 标志特定于 btrfs，确保不要在其他文件系统上使用它）
- 使用 `ls -l` 检查文件所有者和权限，并相应调整。通常，您的 macOS 用户在开箱即用时不会对驱动器具有写入访问权限，因此您需要以 root 身份写入文件或首先准备一个所有人都可写的目标目录（`chmod 777`）。
- 如果您收到 `fcopyfile failed: Operation not permitted`，实际上可能意味着您尝试复制的文件设置了隔离属性（可以使用 `xattr -d com.apple.quarantine <文件名>` 删除）
- 访问磁盘可能需要"完全磁盘访问"权限（尽管您应该会收到允许您逐案允许访问的弹出窗口）

## 从源代码构建

```bash
# 构建依赖
brew install go rustup   # 如果不相关则跳过。您需要 Go 和 Rust 工具链，但不一定通过 homebrew 安装
brew install lld pkgconf # 这些用于交叉编译在 VM 中运行的 Linux 助手

# 如果您刚刚从 homebrew 安装了 rustup
rustup default stable
export PATH="$PATH:/opt/homebrew/opt/rustup/bin"

# 运行时依赖
brew install util-linux slp/krun/libkrun # Libblkid 库和管理程序 - 如果您从 homebrew 安装了 anylinuxfs，您应该已经有了这些

# 构建 anylinuxfs
git clone https://github.com/nohajc/anylinuxfs.git
cd anylinuxfs
rustup target add aarch64-unknown-linux-musl
./download-dependencies.sh
./build-app.sh             # 调试构建
./build-app.sh --release   # 发布构建

# 编译的可执行文件将在 ./bin 下可用
bin/anylinuxfs list
```

## 致谢

这个项目得益于以下项目：
- [libkrun](https://github.com/containers/libkrun) - 适用于 Linux 和 Mac 的 microVM 管理程序
- [libkrunfw](https://github.com/containers/libkrunfw) - 为 libkrun 打包为动态库的 Linux 内核
- [gvproxy](https://github.com/containers/gvisor-tap-vsock) - 虚拟机的用户空间网络（也由 podman 使用）
- [docker-nfs-server](https://github.com/ehough/docker-nfs-server) - 容器中 NFS 服务器的启动器

感谢大家的出色工作！
