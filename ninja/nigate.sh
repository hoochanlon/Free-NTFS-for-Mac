#!/bin/bash

################################################################################
# Free NTFS for Mac - NTFS 设备自动挂载脚本 (Multi-language Support)
#
# 功能说明：
#   这个脚本会持续监控系统，当检测到 NTFS 格式的 U盘/移动硬盘插入时，
#   自动将其从只读模式切换为读写模式，让你可以在 Mac 上正常写入文件。
#
# 工作原理：
#   1. 检查并安装必要的系统依赖（Swift、Homebrew、MacFUSE、ntfs-3g）
#   2. 每 5 秒检查一次是否有新的 NTFS 设备接入
#   3. 如果发现只读的 NTFS 设备，自动卸载并重新挂载为读写模式
#
# 使用方法：
#   直接运行: bash nigate.sh
#   或添加执行权限后: chmod +x nigate.sh && ./nigate.sh
#   设置语言: LANG=ja bash nigate.sh (日文) 或 LANG=en bash nigate.sh (英文)
#
# 注意事项：
#   - 需要管理员权限（会提示输入密码）
#   - 首次运行会安装必要的依赖，可能需要一些时间
#   - 如果设备在 Windows 中使用了快速启动，可能导致挂载失败
################################################################################

# ============================================================
# 多语言支持
# ============================================================

# 检测系统语言
detect_language() {
	# 优先使用环境变量 LANG
	if [ -n "$LANG" ]; then
		case "$LANG" in
			*zh*|*CN*|*TW*)
				echo "zh"
				;;
			*ja*|*JP*)
				echo "ja"
				;;
			*)
				echo "en"
				;;
		esac
	# 如果没有设置，检测系统默认语言
	elif [ -n "$LC_ALL" ]; then
		case "$LC_ALL" in
			*zh*|*CN*|*TW*)
				echo "zh"
				;;
			*ja*|*JP*)
				echo "ja"
				;;
			*)
				echo "en"
				;;
		esac
	else
		# 检测系统语言设置
		sys_lang=$(defaults read -g AppleLanguages 2>/dev/null | head -1 | sed 's/[",]//g' | cut -d'_' -f1)
		case "$sys_lang" in
			zh)
				echo "zh"
				;;
			ja)
				echo "ja"
				;;
			*)
				echo "en"
				;;
		esac
	fi
}

# 设置语言
SCRIPT_LANG=$(detect_language)

# 翻译函数
t() {
	local key=$1
	case "$SCRIPT_LANG" in
		zh)
			case "$key" in
				error_ntfs3g_not_found) echo "错误: 无法找到 ntfs-3g，请确保已正确安装。" ;;
				partition_unmounted) echo "分区 /dev/$2 已成功卸载。" ;;
				partition_unmount_failed) echo "分区 /dev/$2 卸载失败，请检查是否还有进程正在使用该分区。" ;;
				mounting) echo "正在挂载 /dev/$2 到 /Volumes/$3..." ;;
				warning_mount_timeout) echo "警告: 挂载操作超时（可能是Windows快速启动导致），正在终止..." ;;
				new_device_readwrite) echo "新设备: $2，已可读写！" ;;
				error_mount_timeout) echo "错误: 挂载超时。可能是Windows快速启动导致文件系统处于脏状态。" ;;
				suggestion_fast_boot) echo "建议: 在Windows中完全关闭（而非休眠），或禁用快速启动功能。" ;;
				error_remount_failed) echo "重新挂载分区 /dev/$2 到 /Volumes/$3 失败（退出码: $4）。" ;;
				tip_fast_boot) echo "提示: 如果是Windows快速启动问题，请在Windows中完全关闭后再试。" ;;
				waiting_device) echo "等待NTFS新设备接入" ;;
				*) echo "$key" ;;
			esac
			;;
		ja)
			case "$key" in
				error_ntfs3g_not_found) echo "エラー: ntfs-3g が見つかりません。正しくインストールされていることを確認してください。" ;;
				partition_unmounted) echo "パーティション /dev/$2 のアンマウントに成功しました。" ;;
				partition_unmount_failed) echo "パーティション /dev/$2 のアンマウントに失敗しました。パーティションを使用しているプロセスがないか確認してください。" ;;
				mounting) echo "/dev/$2 を /Volumes/$3 にマウントしています..." ;;
				warning_mount_timeout) echo "警告: マウント操作がタイムアウトしました（Windows の高速スタートアップが原因の可能性があります）。終了しています..." ;;
				new_device_readwrite) echo "新しいデバイス: $2、読み書き可能になりました！" ;;
				error_mount_timeout) echo "エラー: マウントがタイムアウトしました。Windows の高速スタートアップによりファイルシステムがダーティ状態になっている可能性があります。" ;;
				suggestion_fast_boot) echo "推奨: Windows で完全にシャットダウンする（スリープではなく）、または高速スタートアップ機能を無効にしてください。" ;;
				error_remount_failed) echo "パーティション /dev/$2 を /Volumes/$3 に再マウントできませんでした（終了コード: $4）。" ;;
				tip_fast_boot) echo "ヒント: Windows の高速スタートアップの問題の場合は、Windows で完全にシャットダウンしてから再試行してください。" ;;
				waiting_device) echo "NTFS デバイスの接続を待機中" ;;
				*) echo "$key" ;;
			esac
			;;
		en|*)
			case "$key" in
				error_ntfs3g_not_found) echo "Error: Cannot find ntfs-3g. Please ensure it is properly installed." ;;
				partition_unmounted) echo "Partition /dev/$2 has been successfully unmounted." ;;
				partition_unmount_failed) echo "Failed to unmount partition /dev/$2. Please check if any process is still using this partition." ;;
				mounting) echo "Mounting /dev/$2 to /Volumes/$3..." ;;
				warning_mount_timeout) echo "Warning: Mount operation timed out (possibly due to Windows Fast Startup). Terminating..." ;;
				new_device_readwrite) echo "New device: $2, now read-write enabled!" ;;
				error_mount_timeout) echo "Error: Mount timeout. The filesystem may be in a dirty state due to Windows Fast Startup." ;;
				suggestion_fast_boot) echo "Suggestion: Fully shut down Windows (not sleep), or disable Fast Startup feature." ;;
				error_remount_failed) echo "Failed to remount partition /dev/$2 to /Volumes/$3 (exit code: $4)." ;;
				tip_fast_boot) echo "Tip: If this is a Windows Fast Startup issue, please fully shut down Windows and try again." ;;
				waiting_device) echo "Waiting for NTFS device connection" ;;
				*) echo "$key" ;;
			esac
			;;
	esac
}

# 定义配置函数：检查依赖并挂载 NTFS 设备为读写模式
config_u_drive(){
	# ============================================================
	# 第一步：禁用 macOS 的安全检查（允许运行未签名的软件）
	# ============================================================
	# spctl 是 macOS 的 Gatekeeper 工具，--master-disable 会禁用主开关
	# 这样系统就不会阻止运行未签名的软件（比如我们安装的 ntfs-3g）
	sudo spctl --master-disable

	# ============================================================
	# 第二步：检查并安装 Swift（Apple 的编程语言）
	# ============================================================
	# command -v swift: 检查系统中是否有 swift 命令
	# ! -x: 如果命令不存在或不可执行
	# 如果 Swift 不存在，就安装 Xcode Command Line Tools（包含 Swift）
	if [ ! -x $(command -v swift) ]; then
		xcode-select --install
	fi

	# ============================================================
	# 第三步：检查并安装 Homebrew（Mac 的包管理器）
	# ============================================================
	# Homebrew 类似于 Linux 的 apt 或 yum，用来安装各种软件
	# 如果 Homebrew 不存在，就从国内镜像源（Gitee）安装
	if [ ! -x $(command -v brew) ]; then
		/bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"
	fi

	# ============================================================
	# 第四步：查找 ntfs-3g 程序的路径
	# ============================================================
	# ntfs-3g 是用来读写 NTFS 文件系统的核心工具
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

	# ============================================================
	# 第五步：如果 ntfs-3g 不存在，自动安装它
	# ============================================================
	# 检查条件：
	#   -z "$NTFS3G_PATH": 路径为空（没找到）
	#   -e "/System/Volumes/Data/$NTFS3G_PATH": 文件不存在
	# 如果任一条件为真，就执行安装
	if [ -z "$NTFS3G_PATH" ] || [ ! -e "/System/Volumes/Data/$NTFS3G_PATH" ]; then
		# brew tap: 添加第三方软件源（仓库）
		# brew install --cask macfuse: 安装 MacFUSE（文件系统框架，ntfs-3g 需要它）
		# brew install ntfs-3g-mac: 安装 ntfs-3g（NTFS 读写工具）
		brew tap gromgit/homebrew-fuse && brew install --cask macfuse && brew install ntfs-3g-mac

		# 安装后重新查找路径（因为刚安装完，路径可能变了）
		NTFS3G_PATH=$(which ntfs-3g 2>/dev/null | tr -d '\n')
		if [ -z "$NTFS3G_PATH" ]; then
			if [ -f "/opt/homebrew/bin/ntfs-3g" ]; then
				NTFS3G_PATH="/opt/homebrew/bin/ntfs-3g"
			elif [ -f "/usr/local/bin/ntfs-3g" ]; then
				NTFS3G_PATH="/usr/local/bin/ntfs-3g"
			fi
		fi
	fi

	# ============================================================
	# 第六步：最终检查 ntfs-3g 是否可用
	# ============================================================
	# 如果还是找不到，说明安装失败，退出函数并返回错误码 1
	if [ -z "$NTFS3G_PATH" ] || [ ! -f "/System/Volumes/Data/$NTFS3G_PATH" ]; then
		t error_ntfs3g_not_found
		return 1
	fi

	# ============================================================
	# 第七步：查找所有已挂载的 NTFS 设备并重新挂载为读写模式
	# ============================================================
	# 注意：以下代码适用于 macOS 14 及以上版本
	# 旧版本 macOS 的代码已注释掉（在下面）

	# mount | grep ntfs: 列出所有已挂载的 NTFS 设备
	# 输出示例：/dev/disk4s1 on /Volumes/TOSHIBA (ntfs, local, nodev, nosuid, read-only, ...)
	# 可以看到设备路径、挂载点和状态（read-only 表示只读）
	lines=$(mount | grep ntfs)

	# 逐行处理每个 NTFS 设备
	while IFS= read -r line; do
	    # ============================================================
	    # 从挂载信息中提取设备名和卷名
	    # ============================================================
	    # 示例输入: /dev/disk4s1 on /Volumes/TOSHIBA (ntfs, ...)
	    # awk '{split($1, a, "/"); print a[3]}':
	    #   - $1 是第一个字段（/dev/disk4s1）
	    #   - split 按 "/" 分割，a[3] 是第三个部分（disk4s1）
	    disk=$(echo "$line" | awk '{split($1, a, "/"); print a[3]}')

	    # awk '{split($3, a, "/"); print a[3]}':
	    #   - $3 是第三个字段（/Volumes/TOSHIBA）
	    #   - split 按 "/" 分割，a[3] 是第三个部分（TOSHIBA）
	    volume=$(echo "$line" | awk '{split($3, a, "/"); print a[3]}')

	    # ============================================================
	    # 检查这个设备是否已经处理过（避免重复处理）
	    # ============================================================
	    # 在 /tmp 目录创建一个标记文件，文件名包含设备名
	    # 如果标记文件存在，说明这个设备已经处理过了，跳过
	    if [ -f "/tmp/ntfs_mounted_${disk}" ]; then
	        continue  # 跳过这个设备，处理下一个
	    fi

	    echo "Disk: $disk"      # 输出设备名，如 disk4s1
	    echo "Volume: $volume"  # 输出卷名，如 TOSHIBA

	    # ============================================================
	    # 卸载当前设备（必须先卸载才能重新挂载）
	    # ============================================================
	    # sudo umount -f: 强制卸载（-f 表示 force）
	    # 2>/dev/null: 隐藏错误信息（如果已经卸载了，会有错误，但可以忽略）
	    sudo umount -f /dev/$disk 2>/dev/null

	    # ============================================================
	    # 检查卸载是否成功
	    # ============================================================
	    # $? 是上一个命令的退出码，0 表示成功
	    if [ $? -eq 0 ]; then
	        t partition_unmounted "$disk"
	    else
	        t partition_unmount_failed "$disk"
	        continue  # 卸载失败，跳过这个设备
	    fi

	    # ============================================================
	    # 重新挂载为读写模式
	    # ============================================================
	    # 这是最关键的一步：使用 ntfs-3g 将设备挂载为读写模式
	    t mounting "$disk" "$volume"

	    # 为了防止挂载操作卡死（比如 Windows 快速启动导致的问题），
	    # 我们使用超时机制：如果 10 秒内没完成，就终止操作

	    # 方法 1: 尝试使用系统的 timeout 命令（如果有的话）
	    if command -v timeout >/dev/null 2>&1; then
	        # timeout 10: 10 秒超时
	        # sudo -S: 从标准输入读取密码（如果需要）
	        # /System/Volumes/Data/$NTFS3G_PATH: ntfs-3g 的完整路径
	        # /dev/$disk: 要挂载的设备
	        # /Volumes/$volume: 挂载点（U盘在 Finder 中显示的位置）
	        # 参数说明：
	        #   -olocal: 本地文件系统
	        #   -oallow_other: 允许其他用户访问
	        #   -oauto_xattr: 自动处理扩展属性
	        #   -ovolname=$volume: 设置卷名
	        #   -oremove_hiberfile: 删除 Windows 休眠文件（解决快速启动问题）
	        #   -onoatime: 不更新访问时间（提高性能）
	        timeout 10 sudo -S /System/Volumes/Data/$NTFS3G_PATH /dev/$disk /Volumes/$volume -olocal -oallow_other -oauto_xattr -ovolname=$volume -oremove_hiberfile -onoatime 2>&1
	        mount_result=$?  # 保存退出码

	    # 方法 2: 如果系统没有 timeout，尝试使用 gtimeout（GNU 版本）
	    elif command -v gtimeout >/dev/null 2>&1; then
	        gtimeout 10 sudo -S /System/Volumes/Data/$NTFS3G_PATH /dev/$disk /Volumes/$volume -olocal -oallow_other -oauto_xattr -ovolname=$volume -oremove_hiberfile -onoatime 2>&1
	        mount_result=$?

	    # 方法 3: 如果都没有，使用后台进程 + 手动超时控制
	    else
	        # & 表示在后台运行
	        sudo -S /System/Volumes/Data/$NTFS3G_PATH /dev/$disk /Volumes/$volume -olocal -oallow_other -oauto_xattr -ovolname=$volume -oremove_hiberfile -onoatime 2>&1 &
	        mount_pid=$!  # $! 是最后一个后台进程的 PID（进程 ID）

	        # 等待最多 10 秒，每秒检查一次进程是否还在运行
	        for i in {1..10}; do
	            # kill -0: 检查进程是否存在（不实际杀死进程）
	            # 如果进程已经结束，说明挂载完成
	            if ! kill -0 $mount_pid 2>/dev/null; then
	                wait $mount_pid  # 等待进程结束并获取退出码
	                mount_result=$?
	                break  # 退出循环
	            fi
	            sleep 1  # 等待 1 秒
	        done

	        # 如果 10 秒后进程还在运行，说明超时了，强制终止
	        if kill -0 $mount_pid 2>/dev/null; then
	            t warning_mount_timeout
	            sudo kill -9 $mount_pid 2>/dev/null  # kill -9 强制终止
	            mount_result=124  # 124 是 timeout 的标准退出码
	        fi
	    fi

	    # ============================================================
	    # 检查挂载结果并给出反馈
	    # ============================================================
	    if [ $mount_result -eq 0 ]; then
	        # 退出码 0 表示成功
	        t new_device_readwrite "$volume"
	        # 创建标记文件，表示这个设备已经处理过了
	        touch "/tmp/ntfs_mounted_${disk}"

	    elif [ $mount_result -eq 124 ]; then
	        # 退出码 124 表示超时
	        t error_mount_timeout
	        t suggestion_fast_boot

	    else
	        # 其他退出码表示失败
	        t error_remount_failed "$disk" "$volume" "$mount_result"
	        t tip_fast_boot
	    fi

	    echo '---------'
	    echo " "
	done <<< "$lines"  # <<< 是 here-string，将变量内容作为输入
}

# ============================================================
# 主程序：持续监控新设备
# ============================================================

echo " "
echo " "
t waiting_device
echo " "
echo '---------'
echo " "

# ============================================================
# 清理函数：删除已移除设备的标记文件
# ============================================================
# 当设备被拔出后，标记文件还在，需要清理掉
cleanup_old_mounts() {
	# /tmp/ntfs_mounted_*: 匹配所有标记文件
	for marker in /tmp/ntfs_mounted_*; do
		if [ -f "$marker" ]; then
			# 从文件名中提取设备名（去掉前缀 "ntfs_mounted_"）
			disk=$(basename "$marker" | sed 's/ntfs_mounted_//')
			# 检查这个设备是否还在系统中（mount | grep）
			# 如果不在，说明设备已移除，删除标记文件
			if ! mount | grep -q "/dev/$disk"; then
				rm -f "$marker"
			fi
		fi
	done
}

# ============================================================
# 无限循环：每 5 秒检查一次新设备
# ============================================================
while true
do
	sleep 5  # 等待 5 秒

	# 清理已移除设备的标记
	cleanup_old_mounts

	# 查找所有已挂载的 NTFS 设备
	# mount | grep ntfs: 列出所有 NTFS 设备
	# awk -F ' ' '{print $1}': 提取第一列（设备路径，如 /dev/disk4s1）
	newDev=$(mount | grep ntfs | awk -F ' ' '{print $1}')

	# 检查是否有新设备
	# ! -n "$newDev": 如果变量为空（没有设备）
	if [ ! -n "$newDev" ]; then
		a=1 # 无意义，只是为了满足 if-else 语法
	else
		# 有设备，调用配置函数进行挂载
		config_u_drive $newDev
	fi

done  # 循环继续
