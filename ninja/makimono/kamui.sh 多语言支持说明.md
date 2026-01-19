# kamui.sh 多语言支持说明

## 概述

`kamui.sh` 现在支持多语言，翻译内容已分离到独立的 `kamui-lang.sh` 文件中，使代码更清晰易维护。

## 文件结构

- `kamui.sh` - 主脚本文件
- `kamui-lang.sh` - 多语言翻译文件

## 使用方法

### 设置语言

可以通过环境变量 `LANG` 设置语言：

```bash
# 中文（默认）
bash kamui.sh

# 日文
LANG=ja bash kamui.sh

# 英文
LANG=en bash kamui.sh
```

### 语言检测顺序

1. 环境变量 `LANG`
2. 环境变量 `LC_ALL`
3. 系统默认语言设置（macOS）

## 翻译键值列表

所有翻译键值定义在 `kamui-lang.sh` 中，主要分类：

### 脚本信息
- `script_title` - 脚本标题
- `script_description` - 脚本描述

### 文件系统类型
- `fs_linux` - Linux 文件系统
- `fs_microsoft` - Microsoft 文件系统
- `fs_encrypted` - 加密卷
- `fs_lvm` - 逻辑卷
- `fs_raid` - RAID
- `fs_multidisk` - 多磁盘 btrfs

### 工作流程
- `workflow_step1` 到 `workflow_step6` - 工作流程步骤

### 检查消息
- `checking_homebrew` - 检查 Homebrew
- `checking_macfuse` - 检查 MacFUSE
- `checking_ntfs3g` - 检查 ntfs-3g-mac
- `checking_anylinuxfs` - 检查 anylinuxfs

### 安装消息
- `installing_homebrew` - 正在安装 Homebrew
- `installing_macfuse` - 正在安装 MacFUSE
- `installing_ntfs3g` - 正在安装 ntfs-3g-mac
- `installing_anylinuxfs` - 正在安装 anylinuxfs

### 成功消息
- `homebrew_installed` - Homebrew 已安装
- `macfuse_installed` - MacFUSE 已安装
- `ntfs3g_installed` - ntfs-3g 已安装
- `anylinuxfs_installed` - anylinuxfs 已安装

### 错误消息
- `error_homebrew_failed` - Homebrew 安装失败
- `error_macfuse_failed` - MacFUSE 安装失败
- `error_ntfs3g_failed` - ntfs-3g-mac 安装失败
- `error_anylinuxfs_failed` - anylinuxfs 安装失败
- `error_mount_failed` - 挂载失败
- 等等...

### 警告消息
- `warning_anylinuxfs_running` - anylinuxfs 正在运行
- `warning_device_mounted` - 设备已挂载
- `warning_macos_readonly` - macOS 只读挂载

### 提示消息
- `tip_port_stop` - 端口占用提示
- `tip_list_devices` - 列出设备提示
- `tip_anylinuxfs_log` - 查看日志提示

## 在脚本中使用翻译

### 基本用法

```bash
# 替换硬编码文本
echo "检查 Homebrew..."
# 改为
echo "$(t checking_homebrew)"

# 带颜色的输出
echo -e "${RED}❌ 错误: 挂载失败${NC}"
# 改为
echo -e "${RED}$(t error_mount_failed)${NC}"
```

### 带参数的翻译

某些翻译键支持参数（通过 `$2`, `$3` 等传递）：

```bash
# 设备名称参数
echo ">>> 发现设备: /dev/$DEVICE_ID (设备名称: $DEVICE_NAME)"
# 改为
echo ">>> $(t device_found) $DEVICE_ID $DEVICE_NAME"

# 端口和进程名参数
echo -e "${RED}❌ 错误: 端口 $port 已被 $process_name 占用${NC}"
# 改为
echo -e "${RED}$(t error_port_in_use) $port $process_name${NC}"
```

## 完成多语言迁移

目前已完成：
- ✅ 脚本开头加载语言文件
- ✅ `show_script_info()` 函数
- ✅ 语言文件创建（包含所有翻译键）

待完成：
- ⏳ 更新所有检查函数中的硬编码文本
- ⏳ 更新所有错误和警告消息
- ⏳ 更新所有提示信息

## 添加新语言

要添加新语言（如法语、德语等），编辑 `kamui-lang.sh`：

1. 在 `detect_language()` 函数中添加语言检测
2. 在 `t()` 函数中添加新的 `case` 分支
3. 为所有翻译键添加对应语言的翻译

## 注意事项

- 翻译键名使用下划线分隔的小写字母（如 `checking_homebrew`）
- 参数通过 `$2`, `$3` 等传递，在翻译函数中使用 `${2:-}` 获取
- 如果找不到翻译键，函数会返回键名本身（作为回退）
