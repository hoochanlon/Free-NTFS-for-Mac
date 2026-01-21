#!/bin/bash

################################################################################
# Free NTFS for Mac - Linux 文件系统挂载脚本 (Multi-language Support)
#
# 设置语言: LANG=ja bash kamui.sh (日文) 或 LANG=en bash kamui.sh (英文)
################################################################################

# ============================================================
# 加载多语言支持
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/kamui-lang.sh" ]; then
	source "$SCRIPT_DIR/kamui-lang.sh"
else
	# 如果找不到语言文件，使用简单的回退函数
	t() { echo "$1"; }
fi

# ============================================================
# 颜色输出
# ============================================================
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================================
# 显示脚本信息
# ============================================================
show_script_info() {
	echo -e "${BLUE}==========================================${NC}"
	echo -e "${BLUE}$(t script_title)${NC}"
	echo -e "${BLUE}==========================================${NC}"
	echo ""
	echo -e "${CYAN}$(t script_description)${NC}"
	echo ""
	echo -e "${YELLOW}  $(t fs_linux)${NC}"
	echo -e "${YELLOW}  $(t fs_microsoft)${NC}"
	echo -e "${YELLOW}  $(t fs_encrypted)${NC}"
	echo -e "${YELLOW}  $(t fs_lvm)${NC}"
	echo -e "${YELLOW}  $(t fs_raid)${NC}"
	echo -e "${YELLOW}  $(t fs_multidisk)${NC}"
	echo ""
	echo -e "${CYAN}$(t workflow_step1)${NC}"
	echo -e "${CYAN}$(t workflow_step2)${NC}"
	echo -e "${CYAN}$(t workflow_step3)${NC}"
	echo -e "${CYAN}$(t workflow_step4)${NC}"
	echo -e "${CYAN}$(t workflow_step5)${NC}"
	echo -e "${CYAN}$(t workflow_step6)${NC}"
	echo ""
	echo -e "${CYAN}$(t usage_mount)${NC}"
	echo "    直接运行: $0"
	echo "    指定设备: $0 /dev/disk4s1"
	echo "    指定文件系统类型: $0 /dev/disk4s1 -t ntfs3"
	echo "    只读挂载: $0 /dev/disk4s1 -o ro"
	echo ""
	echo -e "${YELLOW}  $(t usage_list)${NC}"
	echo "    $0 --list"
	echo "    或: sudo anylinuxfs list"
	echo ""
	echo -e "${YELLOW}  $(t usage_status)${NC}"
	echo "    $0 --status"
	echo "    或: anylinuxfs status"
	echo ""
	echo -e "${YELLOW}  $(t usage_unmount)${NC}"
	echo "    $0 --unmount [设备路径]"
	echo "    或: sudo anylinuxfs unmount [设备路径]"
	echo "    卸载所有: sudo anylinuxfs unmount"
	echo ""
	echo -e "${CYAN}$(t note_admin_required)${NC}"
	echo -e "${CYAN}$(t note_first_run)${NC}"
	echo -e "${CYAN}$(t note_ports)${NC}"
	echo -e "${CYAN}$(t note_apple_silicon)${NC}"
	echo ""
	echo -e "${BLUE}==========================================${NC}"
	echo ""
}

# ============================================================
# 检查并安装 Homebrew
# ============================================================
check_and_install_homebrew() {
	echo "检查 Homebrew..."
	# 使用 command -v 检查命令是否存在且可执行
	if [ -x $(command -v brew) ]; then
		echo "✅ Homebrew 已安装"
		return 0
	fi

	echo "正在安装 Homebrew..."
	/bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)" || {
		echo -e "${RED}❌ 错误: Homebrew 安装失败${NC}"
		exit 1
	}

	# 验证安装
	if [ -x $(command -v brew) ]; then
		echo "✅ Homebrew 已安装"
		return 0
	else
		echo -e "${RED}❌ 错误: Homebrew 安装失败${NC}"
		exit 1
	fi
}

# ============================================================
# 检查并安装 MacFUSE
# ============================================================
check_and_install_macfuse() {
	echo "检查 MacFUSE..."
	# 检查 MacFUSE 是否已通过 Homebrew 安装
	if brew list --cask macfuse &>/dev/null 2>&1; then
		echo "✅ MacFUSE 已安装"
		return 0
	fi

	echo "正在安装 MacFUSE..."
	# 先添加 tap（如果需要）
	brew tap gromgit/homebrew-fuse &>/dev/null 2>&1 || true
	brew install --cask macfuse || {
		echo -e "${RED}❌ 错误: MacFUSE 安装失败${NC}"
		exit 1
	}

	# 验证安装
	if brew list --cask macfuse &>/dev/null 2>&1; then
		echo "✅ MacFUSE 已安装"
		return 0
	else
		echo -e "${RED}❌ 错误: MacFUSE 安装失败${NC}"
		exit 1
	fi
}

# ============================================================
# 检查并安装 ntfs-3g-mac
# ============================================================
check_and_install_ntfs3g() {
	echo "检查 ntfs-3g-mac..."

	# 查找 ntfs-3g 程序的路径
	# which ntfs-3g: 查找 ntfs-3g 命令在系统中的位置
	# 2>/dev/null: 隐藏错误信息
	# tr -d '\n': 删除换行符，确保路径是单行
	NTFS3G_PATH=$(which ntfs-3g 2>/dev/null | tr -d '\n')

	# 如果 which 命令找不到，尝试常见的安装路径
	# Apple Silicon Mac (M1/M2) 通常安装在 /opt/homebrew/bin/
	# Intel Mac 通常安装在 /usr/local/bin/
	if [ -z "$NTFS3G_PATH" ]; then
		if [ -f "/opt/homebrew/bin/ntfs-3g" ]; then
			NTFS3G_PATH="/opt/homebrew/bin/ntfs-3g"
		elif [ -f "/usr/local/bin/ntfs-3g" ]; then
			NTFS3G_PATH="/usr/local/bin/ntfs-3g"
		fi
	fi

	# 检查 ntfs-3g 是否可用
	# 使用 /System/Volumes/Data/$NTFS3G_PATH 检查文件是否存在（macOS 的特殊路径）
	if [ -n "$NTFS3G_PATH" ] && [ -f "/System/Volumes/Data/$NTFS3G_PATH" ]; then
		echo "✅ ntfs-3g 已安装"
		return 0
	fi

	# 如果 ntfs-3g 不存在，自动安装它
	echo "正在安装 ntfs-3g-mac..."
	# brew tap: 添加第三方软件源（仓库）
	# brew install --cask macfuse: 安装 MacFUSE（文件系统框架，ntfs-3g 需要它）
	# brew install ntfs-3g-mac: 安装 ntfs-3g（NTFS 读写工具）
	brew tap gromgit/homebrew-fuse &>/dev/null 2>&1 || true
	brew install ntfs-3g-mac || {
		echo -e "${RED}❌ 错误: ntfs-3g-mac 安装失败${NC}"
		exit 1
	}

	# 安装后重新查找路径（因为刚安装完，路径可能变了）
	NTFS3G_PATH=$(which ntfs-3g 2>/dev/null | tr -d '\n')
	if [ -z "$NTFS3G_PATH" ]; then
		if [ -f "/opt/homebrew/bin/ntfs-3g" ]; then
			NTFS3G_PATH="/opt/homebrew/bin/ntfs-3g"
		elif [ -f "/usr/local/bin/ntfs-3g" ]; then
			NTFS3G_PATH="/usr/local/bin/ntfs-3g"
		fi
	fi

	# 最终检查 ntfs-3g 是否可用
	if [ -n "$NTFS3G_PATH" ] && [ -f "/System/Volumes/Data/$NTFS3G_PATH" ]; then
		echo "✅ ntfs-3g-mac 已安装"
		return 0
	else
		echo -e "${RED}❌ 错误: 无法找到 ntfs-3g，请确保已正确安装${NC}"
		exit 1
	fi
}

# ============================================================
# 检查并安装 anylinuxfs
# ============================================================
check_and_install_anylinuxfs() {
	# 先检查 Homebrew
	check_and_install_homebrew

	# 检查并安装 MacFUSE（anylinuxfs 的运行时依赖）
	check_and_install_macfuse

	# 检查并安装 ntfs-3g-mac（anylinuxfs 的运行时依赖，用于 NTFS 支持）
	check_and_install_ntfs3g

	# 检查 anylinuxfs 是否已安装
	echo "检查 anylinuxfs..."
	# 使用 command -v 检查命令是否存在且可执行
	if [ -x $(command -v anylinuxfs) ]; then
		echo "✅ anylinuxfs 已安装"
		return 0
	fi

	# 安装 anylinuxfs
	echo "正在安装 anylinuxfs..."
	brew tap nohajc/anylinuxfs || {
		echo -e "${RED}❌ 错误: 无法添加 anylinuxfs 仓库${NC}"
		exit 1
	}
	brew install anylinuxfs || {
		echo -e "${RED}❌ 错误: anylinuxfs 安装失败${NC}"
		exit 1
	}

	# 验证安装
	if [ -x $(command -v anylinuxfs) ]; then
		echo "✅ anylinuxfs 已安装"
		return 0
	else
		echo -e "${RED}❌ 错误: 未找到 anylinuxfs${NC}"
		exit 1
	fi
}

# ============================================================
# 检测 Linux 文件系统分区
# ============================================================
detect_linux_partition() {
	local device_id="$1"

	if [ -n "$device_id" ]; then
		# 如果指定了设备，验证它是否存在
		if diskutil list | grep -q "$device_id"; then
			echo "$device_id"
			return 0
		else
			echo -e "${RED}❌ 错误: 设备 $device_id 未找到${NC}"
			return 1
		fi
	fi

	# 自动检测：使用 anylinuxfs list 查找支持的文件系统分区
	# anylinuxfs list 返回 diskutil 格式的输出，显示所有可用的 Linux 文件系统
	# 支持的文件系统类型：
	#   - Linux 文件系统：ext4, btrfs, xfs, zfs, ext2, ext3
	#   - Microsoft 文件系统：NTFS, exFAT (通过 anylinuxfs list -m)
	#   - 加密卷：crypto_LUKS (LUKS), BitLocker
	#   - 逻辑卷：LVM2_member (LVM)
	#   - RAID：linux_raid_member (mdadm RAID)

	# 同时检测 Linux 和 Microsoft 文件系统（包括 NTFS）
	local detected=""

	# 先检测 Linux 文件系统
	detected=$(sudo anylinuxfs list 2>/dev/null | grep -E "(ext[234]|btrfs|xfs|zfs|Linux|crypto_LUKS|LVM2_member|linux_raid_member)" | awk '{print $NF}' | head -n 1)

	# 如果没找到 Linux 文件系统，检测 Microsoft 文件系统（NTFS, exFAT）
	if [ -z "$detected" ]; then
		detected=$(sudo anylinuxfs list -m 2>/dev/null | grep -E "(ntfs|exfat|Microsoft|BitLocker)" | awk '{print $NF}' | head -n 1)
	fi

	# 如果还是没找到，尝试从 diskutil list 直接检测 NTFS 和其他 Microsoft 文件系统
	if [ -z "$detected" ]; then
		# 检测 NTFS 和 Microsoft Basic Data 分区
		detected=$(diskutil list | grep -iE "ntfs|Microsoft Basic Data|Windows_NTFS" | awk '{print $NF}' | head -n 1)
	fi

	# 如果还是没找到，尝试检测 exFAT
	if [ -z "$detected" ]; then
		detected=$(diskutil list | grep -iE "exfat|Microsoft ExFAT" | awk '{print $NF}' | head -n 1)
	fi

	if [ -z "$detected" ]; then
		echo -e "${RED}❌ 错误：未发现支持的文件系统分区。${NC}"
		echo ""
		echo "提示:"
		echo "  - 可以使用 'sudo anylinuxfs list' 查看 Linux 文件系统"
		echo "  - 可以使用 'sudo anylinuxfs list -m' 查看 Microsoft 文件系统（NTFS, exFAT）"
		echo "  - 可以使用 '$0 --list' 查看所有可用设备"
		echo ""
		echo -e "${YELLOW}注意：${NC}"
		echo "  - 确保设备已正确连接并已插入"
		echo "  - NTFS 设备：anylinuxfs 支持直接挂载 NTFS 为读写模式"
		echo "  - 如果 NTFS 设备已被 macOS 挂载为只读，anylinuxfs 会自动卸载并重新挂载为读写模式"
		return 1
	fi

	echo "$detected"
	return 0
}

# ============================================================
# 获取设备名称（从 anylinuxfs list 或 diskutil list 的 NAME 列）
# ============================================================
get_device_name() {
	local device_id="$1"
	local device_name=""

	# 优先使用环境变量
	if [ -n "$VOLUME_NAME" ]; then
		device_name="$VOLUME_NAME"
	else
		# 优先从 anylinuxfs list 获取（更准确）
		local list_line=$(sudo anylinuxfs list 2>/dev/null | grep "$device_id" | head -n 1)
		if [ -n "$list_line" ]; then
			# anylinuxfs list 输出格式: "   1:                       ext4 sandisk-ext             30.1 GB    disk4s1"
			# NAME 列在文件系统类型（ext4/btrfs/xfs等）之后，大小（30.1 GB）之前
			device_name=$(echo "$list_line" | awk -v dev="$device_id" '{
				dev_pos = 0
				for(i=1; i<=NF; i++) {
					if ($i == dev) {
						dev_pos = i
						break
					}
				}
				if (dev_pos > 0) {
					for(i=dev_pos-1; i>=1; i--) {
						if ($i ~ /^[0-9.]+$/ || $i ~ /^(GB|MB|TB|KB)$/) {
							continue
						}
						if ($i ~ /^(ext[234]|btrfs|xfs|zfs|ntfs|exfat|Linux|FDisk_partition_scheme|Apple_HFS|Microsoft|EFI|LVM2_member|crypto_LUKS|linux_raid_member|BitLocker|GUID_partition_scheme)$/) {
							continue
						}
						if ($i != "" && $i !~ /^[0-9]+:$/) {
							print $i
							exit
						}
					}
				}
			}')
		fi

		# 如果从 anylinuxfs list 没提取到，尝试从 diskutil list 获取
		if [ -z "$device_name" ]; then
			local diskutil_line=$(diskutil list | grep "$device_id" | head -n 1)
			if [ -n "$diskutil_line" ]; then
				device_name=$(echo "$diskutil_line" | awk -v dev="$device_id" '{
					dev_pos = 0
					for(i=1; i<=NF; i++) {
						if ($i == dev) {
							dev_pos = i
							break
						}
					}
					if (dev_pos > 0) {
						for(i=dev_pos-1; i>=1; i--) {
							if ($i ~ /^[0-9.]+$/ || $i ~ /^(GB|MB|TB|KB)$/) {
								continue
							}
							if ($i ~ /^(ext[234]|btrfs|xfs|zfs|ntfs|exfat|Linux|FDisk_partition_scheme|Apple_HFS|Microsoft|EFI|LVM2_member|crypto_LUKS|linux_raid_member|BitLocker|GUID_partition_scheme)$/) {
								continue
							}
							if ($i != "" && $i !~ /^[0-9]+:$/) {
								print $i
								exit
							}
						}
					}
				}')
			fi
		fi

		# 如果还是没提取到，尝试从 diskutil info 获取（作为后备）
		if [ -z "$device_name" ]; then
			device_name=$(diskutil info "$device_id" 2>/dev/null | grep "Volume Name" | awk -F': ' '{print $2}' | xargs)
			if [[ "$device_name" == "Not applicable (no file system)" ]]; then
				device_name=""
			fi
		fi
	fi

	echo "$device_name"
}

# ============================================================
# 检查端口占用
# ============================================================
check_ports() {
	local ports=(2049 32765 32767)
	local anylinuxfs_using_port=false

	for port in "${ports[@]}"; do
		if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
			# 检查是否是 anylinuxfs 在使用端口
			local process_name=$(lsof -Pi :$port -sTCP:LISTEN 2>/dev/null | tail -n +2 | awk '{print $1}' | head -1)
			if [[ "$process_name" == "anylinuxfs" ]] || [[ "$process_name" == "krun" ]] || [[ "$process_name" == "gvproxy" ]]; then
				anylinuxfs_using_port=true
				continue
			fi

			# 如果不是 anylinuxfs，说明是其他服务占用
			echo -e "${RED}❌ 错误: 端口 $port 已被 $process_name 占用${NC}"
			echo -e "${YELLOW}请停止占用该端口的服务后重试${NC}"
			return 1
		fi
	done

	# 如果 anylinuxfs 正在使用端口，说明已有设备挂载
	if [ "$anylinuxfs_using_port" = true ]; then
		echo -e "${YELLOW}⚠️  anylinuxfs 正在运行，检测到已有设备挂载${NC}"
		STATUS_OUTPUT=$(anylinuxfs status 2>/dev/null || echo "")
		if [ -n "$STATUS_OUTPUT" ]; then
			echo "$STATUS_OUTPUT"
		fi
		echo ""
		echo -e "${YELLOW}注意：anylinuxfs 限制${NC}"
		echo "  - anylinuxfs 同一时间只能挂载一个设备"
		echo "  - 如需挂载新设备，需要先卸载当前已挂载的设备"
		echo ""
		read -p "是否卸载当前设备并挂载新设备？(y/N): " continue_mount
		if [[ "$continue_mount" != "y" ]] && [[ "$continue_mount" != "Y" ]]; then
			echo "挂载已取消"
			exit 0
		fi

		# 卸载当前已挂载的设备
		echo ""
		echo "正在卸载当前设备..."
		sudo anylinuxfs unmount || {
			echo -e "${RED}❌ 错误: 卸载当前设备失败${NC}"
			exit 1
		}
		echo -e "${GREEN}✅ 当前设备已卸载${NC}"
		echo ""
		# 等待一下确保卸载完成
		sleep 2
	fi

	return 0
}

# ============================================================
# 列出可用设备
# ============================================================
list_available_devices() {
	echo -e "${BLUE}==========================================${NC}"
	echo -e "${BLUE}可用的 Linux 文件系统设备:${NC}"
	echo -e "${BLUE}==========================================${NC}"
	echo ""
	sudo anylinuxfs list

	# 同时显示 Microsoft 文件系统（NTFS, exFAT）
	echo ""
	echo -e "${BLUE}==========================================${NC}"
	echo -e "${BLUE}可用的 Microsoft 文件系统设备 (NTFS, exFAT):${NC}"
	echo -e "${BLUE}==========================================${NC}"
	echo ""
	MS_LIST=$(sudo anylinuxfs list -m 2>/dev/null)
	if [ -n "$MS_LIST" ]; then
		echo "$MS_LIST"
		echo ""
		echo -e "${CYAN}NTFS 挂载说明：${NC}"
		echo "  - anylinuxfs 默认使用 ntfs-3g 驱动（更好的兼容性）"
		echo "  - 如需更高性能，可使用 ntfs3 驱动：$0 /dev/diskXsY -t ntfs3"
		echo "  - 注意：ntfs3 不支持 Windows 休眠或快速启动的磁盘"
	else
		echo "  （无 Microsoft 文件系统设备）"
	fi
}

# ============================================================
# 查看挂载状态
# ============================================================
show_status() {
	echo -e "${BLUE}==========================================${NC}"
	echo -e "${BLUE}当前挂载状态:${NC}"
	echo -e "${BLUE}==========================================${NC}"
	echo ""
	anylinuxfs status
}

# ============================================================
# 卸载设备
# ============================================================
unmount_device() {
	local device_path="$1"

	echo -e "${BLUE}==========================================${NC}"
	echo -e "${BLUE}Free NTFS for Mac - Linux 文件系统挂载脚本${NC}"
	echo -e "${BLUE}==========================================${NC}"
	echo ""

	echo "正在卸载设备..."
	if [ -n "$device_path" ]; then
		sudo anylinuxfs unmount "$device_path" && {
			echo -e "${GREEN}✅ 设备已成功卸载${NC}"
		} || {
			echo -e "${RED}❌ 卸载失败${NC}"
			exit 1
		}
	else
		sudo anylinuxfs unmount && {
			echo -e "${GREEN}✅ 所有设备已成功卸载${NC}"
		} || {
			echo -e "${RED}❌ 卸载失败${NC}"
			exit 1
		}
	fi
}

# ============================================================
# 显示使用帮助
# ============================================================
show_usage() {
	echo -e "${BLUE}==========================================${NC}"
	echo -e "${BLUE}Free NTFS for Mac - Linux 文件系统挂载脚本${NC}"
	echo -e "${BLUE}==========================================${NC}"
	echo ""
	echo "使用方法: $0 [设备路径] [anylinuxfs选项] | --list | --status | --unmount [设备路径]"
	echo ""
	echo "示例:"
	echo "  $0                          # 自动检测并挂载设备"
	echo "  $0 /dev/disk4s1             # 挂载指定设备"
	echo "  $0 /dev/disk4s1 -t ntfs3   # 使用 ntfs3 驱动挂载"
	echo "  $0 /dev/disk4s1 -o ro      # 只读挂载"
	echo "  $0 --list                  # 列出可用设备"
	echo "  $0 --status                # 查看挂载状态"
	echo "  $0 --unmount               # 卸载所有设备"
	echo "  $0 --unmount /dev/disk4s1  # 卸载指定设备"
}

# ============================================================
# 主程序
# ============================================================

# 解析命令行参数
DEVICE_ID=""
ANYLINUXFS_OPTS=()
ACTION="mount"

while [[ $# -gt 0 ]]; do
	case $1 in
		--list|-l)
			ACTION="list"
			shift
			;;
		--status|-s)
			ACTION="status"
			shift
			;;
		--unmount|--umount|-u)
			ACTION="unmount"
			if [[ "$2" =~ ^/dev/disk ]] || [[ "$2" =~ ^lvm: ]] || [[ "$2" =~ ^raid: ]]; then
				DEVICE_ID="$2"
				shift 2
			else
				shift
			fi
			;;
		--help|-h)
			show_usage
			exit 0
			;;
		/dev/disk*|lvm:*|raid:*)
			DEVICE_ID="$1"
			shift
			;;
		*)
			ANYLINUXFS_OPTS+=("$1")
			shift
			;;
	esac
done

# 显示脚本信息（仅在挂载操作时显示）
if [ "$ACTION" = "mount" ]; then
	show_script_info
fi

# 根据操作类型执行相应功能
case "$ACTION" in
	list)
		check_and_install_anylinuxfs
		list_available_devices
		exit 0
		;;
	status)
		check_and_install_anylinuxfs
		show_status
		exit 0
		;;
	unmount)
		check_and_install_anylinuxfs
		unmount_device "$DEVICE_ID"
		exit 0
		;;
	mount)
		# 继续执行挂载流程
		;;
esac

# 检查并安装 anylinuxfs（会先检查 Homebrew）
check_and_install_anylinuxfs

# 检查端口占用
if ! check_ports; then
	exit 1
fi

# 检测设备
echo "正在检测 Linux 文件系统分区..."
DEVICE_ID=$(detect_linux_partition "$DEVICE_ID")
if [ $? -ne 0 ]; then
	exit 1
fi

# 获取设备名称
DEVICE_NAME=$(get_device_name "$DEVICE_ID")
echo ">>> 发现设备: /dev/$DEVICE_ID (设备名称: ${DEVICE_NAME:-待挂载后检测})"

# 检查设备是否已经通过 anylinuxfs 挂载（在端口检查之后再次确认）
STATUS_OUTPUT=$(anylinuxfs status 2>/dev/null || echo "")
if [ -n "$STATUS_OUTPUT" ] && echo "$STATUS_OUTPUT" | grep -q "$DEVICE_ID"; then
	# 要挂载的设备已经挂载了
	echo -e "${YELLOW}⚠️  设备 /dev/$DEVICE_ID 已经通过 anylinuxfs 挂载${NC}"
	echo "$STATUS_OUTPUT"

	# 尝试找到挂载点
	FINAL_PATH=""
	if [ -n "$DEVICE_NAME" ] && [ -d "/Volumes/$DEVICE_NAME" ]; then
		FINAL_PATH="/Volumes/$DEVICE_NAME"
	else
		MOUNT_POINT=$(diskutil info "$DEVICE_ID" 2>/dev/null | grep "Mount Point" | awk -F': ' '{print $2}' | xargs)
		if [ -n "$MOUNT_POINT" ] && [ -d "$MOUNT_POINT" ]; then
			FINAL_PATH="$MOUNT_POINT"
		fi
	fi

	if [ -n "$FINAL_PATH" ] && [ -d "$FINAL_PATH" ]; then
		echo -e "${GREEN}✅ 设备已挂载: $FINAL_PATH${NC}"
		open "$FINAL_PATH"
	fi
	exit 0
fi

# 检查设备是否已被 macOS 挂载（只读模式，通常是 NTFS）
MOUNT_INFO=$(diskutil info "$DEVICE_ID" 2>/dev/null | grep -E "Mount Point|File System Personality")
MOUNT_POINT=$(echo "$MOUNT_INFO" | grep "Mount Point" | awk -F': ' '{print $2}' | xargs)
FS_TYPE=$(echo "$MOUNT_INFO" | grep "File System Personality" | awk -F': ' '{print $2}' | xargs)

if [ -n "$MOUNT_POINT" ] && [ -d "$MOUNT_POINT" ]; then
	# 检查是否是通过 anylinuxfs 挂载的
	STATUS_OUTPUT=$(anylinuxfs status 2>/dev/null || echo "")
	if [ -n "$STATUS_OUTPUT" ] && echo "$STATUS_OUTPUT" | grep -q "$DEVICE_ID"; then
		# 已经通过 anylinuxfs 挂载
		echo -e "${YELLOW}⚠️  设备 /dev/$DEVICE_ID 已经通过 anylinuxfs 挂载${NC}"
		echo "$STATUS_OUTPUT"
		echo -e "${GREEN}✅ 设备已挂载: $MOUNT_POINT${NC}"
		open "$MOUNT_POINT"
		exit 0
	else
		# 被 macOS 挂载为只读（通常是 NTFS）
		echo -e "${YELLOW}⚠️  设备 /dev/$DEVICE_ID 已被 macOS 挂载为只读模式${NC}"
		if [[ "$FS_TYPE" == *"NTFS"* ]] || [[ "$FS_TYPE" == *"Microsoft"* ]]; then
			echo "检测到 NTFS 文件系统，需要先卸载 macOS 的只读挂载，然后使用 anylinuxfs 挂载为读写模式"
			echo ""
			echo "正在卸载 macOS 的只读挂载..."
			diskutil unmount "$DEVICE_ID" || {
				echo -e "${RED}❌ 错误: 无法卸载设备，可能正在被使用${NC}"
				echo "提示: 请关闭所有使用该设备的应用程序后重试"
				exit 1
			}
			echo -e "${GREEN}✅ macOS 只读挂载已卸载${NC}"
			echo ""
			# 等待一下确保卸载完成
			sleep 1
		else
			echo -e "${YELLOW}设备挂载点: $MOUNT_POINT${NC}"
			echo "如果这是 Linux 文件系统，建议先卸载 macOS 挂载后再使用 anylinuxfs 挂载"
			read -p "是否继续卸载 macOS 挂载？(y/N): " unmount_macos
			if [[ "$unmount_macos" == "y" ]] || [[ "$unmount_macos" == "Y" ]]; then
				diskutil unmount "$DEVICE_ID" || {
					echo -e "${RED}❌ 错误: 无法卸载设备${NC}"
					exit 1
				}
				echo -e "${GREEN}✅ macOS 挂载已卸载${NC}"
				sleep 1
			else
				echo "已取消"
				exit 0
			fi
		fi
	fi
fi

# 检查设备是否已经通过 anylinuxfs 挂载（在卸载 macOS 挂载后再次检查）
STATUS_OUTPUT=$(anylinuxfs status 2>/dev/null || echo "")
if [ -n "$STATUS_OUTPUT" ] && echo "$STATUS_OUTPUT" | grep -q "$DEVICE_ID"; then
	echo -e "${YELLOW}⚠️  设备 /dev/$DEVICE_ID 已经通过 anylinuxfs 挂载${NC}"
	echo "$STATUS_OUTPUT"

	# 尝试找到挂载点
	FINAL_PATH=""
	if [ -n "$DEVICE_NAME" ] && [ -d "/Volumes/$DEVICE_NAME" ]; then
		FINAL_PATH="/Volumes/$DEVICE_NAME"
	else
		MOUNT_POINT=$(diskutil info "$DEVICE_ID" 2>/dev/null | grep "Mount Point" | awk -F': ' '{print $2}' | xargs)
		if [ -n "$MOUNT_POINT" ] && [ -d "$MOUNT_POINT" ]; then
			FINAL_PATH="$MOUNT_POINT"
		fi
	fi

	if [ -n "$FINAL_PATH" ] && [ -d "$FINAL_PATH" ]; then
		echo -e "${GREEN}✅ 设备已挂载: $FINAL_PATH${NC}"
		open "$FINAL_PATH"
	fi
	exit 0
fi

# 执行挂载
echo ">>> 正在执行挂载..."
if [ ${#ANYLINUXFS_OPTS[@]} -gt 0 ]; then
	sudo anylinuxfs mount "/dev/$DEVICE_ID" "${ANYLINUXFS_OPTS[@]}" || {
		echo -e "${RED}❌ 错误: 挂载失败${NC}"
		echo "提示: 可以使用 'anylinuxfs log' 查看详细错误信息"
		exit 1
	}
else
	sudo anylinuxfs mount "/dev/$DEVICE_ID" || {
		echo -e "${RED}❌ 错误: 挂载失败${NC}"
		echo "提示: 可以使用 'anylinuxfs log' 查看详细错误信息"
		exit 1
	}
fi

# 等待挂载完成
sleep 2

# 从 anylinuxfs status 获取挂载信息
STATUS_OUTPUT=$(anylinuxfs status 2>/dev/null || echo "")
if [ -n "$STATUS_OUTPUT" ] && echo "$STATUS_OUTPUT" | grep -q "$DEVICE_ID"; then
	# 从状态输出中提取设备名称（如果有）
	# anylinuxfs status 可能包含挂载点信息
	MOUNT_INFO=$(echo "$STATUS_OUTPUT" | grep "$DEVICE_ID")
	if [ -n "$MOUNT_INFO" ]; then
		# 尝试从状态信息中提取挂载点
		MOUNT_POINT=$(echo "$MOUNT_INFO" | grep -o '/Volumes/[^ ]*' | head -1)
		if [ -n "$MOUNT_POINT" ] && [ -d "$MOUNT_POINT" ]; then
			DEVICE_NAME=$(basename "$MOUNT_POINT")
		fi
	fi
fi

# 如果还没获取到设备名称，从 anylinuxfs list 获取
if [ -z "$DEVICE_NAME" ]; then
	DEVICE_NAME=$(get_device_name "$DEVICE_ID")
fi

# 动态权限修复
echo ">>> 正在等待虚拟机内部权限就绪..."
for i in {1..15}; do
	# 使用 anylinuxfs status 检查挂载状态
	STATUS_OUTPUT=$(anylinuxfs status 2>/dev/null || echo "")
	if [ -n "$STATUS_OUTPUT" ] && echo "$STATUS_OUTPUT" | grep -q "$DEVICE_ID"; then
		# 挂载成功，尝试修复权限
		# 注意：anylinuxfs 挂载后，权限修复可能需要通过其他方式
		# 这里先等待挂载完成
		break
	fi
	sleep 1
done

# 检测实际挂载点
echo ">>> 正在检测实际挂载点..."
FINAL_PATH=""
sleep 1

# 方法1: 如果 anylinuxfs 给出了设备名称，macOS 侧通常会是 /Volumes/<name>
if [ -n "$DEVICE_NAME" ] && [ -d "/Volumes/$DEVICE_NAME" ]; then
	FINAL_PATH="/Volumes/$DEVICE_NAME"
fi

# 方法2: 通过 diskutil info 查找该设备对应的实际挂载点
if [ -z "$FINAL_PATH" ]; then
	MOUNT_POINT=$(diskutil info "$DEVICE_ID" 2>/dev/null | grep "Mount Point" | awk -F': ' '{print $2}' | xargs)
	if [ -n "$MOUNT_POINT" ] && [ -d "$MOUNT_POINT" ]; then
		FINAL_PATH="$MOUNT_POINT"
	fi
fi

# 方法3: 扫描 /Volumes 目录，通过 diskutil info 匹配设备ID
if [ -z "$FINAL_PATH" ]; then
	for vol in /Volumes/*; do
		if [ -d "$vol" ] && [ ! "$vol" = "/Volumes" ]; then
			VOL_DEVICE=$(diskutil info "$vol" 2>/dev/null | grep "Device Node" | awk -F': ' '{print $2}' | xargs)
			if [ "$VOL_DEVICE" = "/dev/$DEVICE_ID" ]; then
				FINAL_PATH="$vol"
				break
			fi
		fi
	done
fi

# 打开 Finder
if [ -n "$FINAL_PATH" ] && [ -d "$FINAL_PATH" ]; then
	echo -e "${GREEN}✅ 挂载成功: $FINAL_PATH${NC}"

	# 显示挂载状态
	anylinuxfs status 2>/dev/null || true

	open "$FINAL_PATH"
else
	echo -e "${YELLOW}⚠️ 挂载已触发，但 Finder 路径未就绪，请手动查看 /Volumes${NC}"
	echo ">>> 调试信息:"
	echo "   - 设备: /dev/$DEVICE_ID"
	echo "   - 设备名称: ${DEVICE_NAME:-<空/未获取>}"
	echo "   - 挂载状态:"
	anylinuxfs status 2>/dev/null || echo "   （无法获取状态）"
	echo ""
	echo "提示:"
	echo "  - 可以使用 'anylinuxfs status' 查看挂载状态"
	echo "  - 可以使用 'anylinuxfs log' 查看详细日志"
	echo "  - 可以通过环境变量 VOLUME_NAME 指定卷名，例如:"
	echo "    VOLUME_NAME=${DEVICE_NAME:-your-volume-name} $0"
	open "/Volumes"
fi
