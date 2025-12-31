config_u_drive(){
	sudo spctl --master-disable

	if [ ! -x $(command -v swift) ]; then
	xcode-select --install
	fi


	if [ ! -x $(command -v brew) ]; then
	/bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"
	fi


	# 获取 ntfs-3g 路径
	NTFS3G_PATH=$(which ntfs-3g 2>/dev/null | tr -d '\n')
	if [ -z "$NTFS3G_PATH" ]; then
		# 如果 which 找不到，尝试常见路径
		if [ -f "/opt/homebrew/bin/ntfs-3g" ]; then
			NTFS3G_PATH="/opt/homebrew/bin/ntfs-3g"
		elif [ -f "/usr/local/bin/ntfs-3g" ]; then
			NTFS3G_PATH="/usr/local/bin/ntfs-3g"
		fi
	fi

	if [ -z "$NTFS3G_PATH" ] || [ ! -e "/System/Volumes/Data/$NTFS3G_PATH" ]; then
		brew tap gromgit/homebrew-fuse && brew install --cask macfuse && brew install ntfs-3g-mac
		# 安装后重新获取路径
		NTFS3G_PATH=$(which ntfs-3g 2>/dev/null | tr -d '\n')
		if [ -z "$NTFS3G_PATH" ]; then
			if [ -f "/opt/homebrew/bin/ntfs-3g" ]; then
				NTFS3G_PATH="/opt/homebrew/bin/ntfs-3g"
			elif [ -f "/usr/local/bin/ntfs-3g" ]; then
				NTFS3G_PATH="/usr/local/bin/ntfs-3g"
			fi
		fi
	fi

	# 检查 ntfs-3g 是否可用
	if [ -z "$NTFS3G_PATH" ] || [ ! -f "/System/Volumes/Data/$NTFS3G_PATH" ]; then
		echo "错误: 无法找到 ntfs-3g，请确保已正确安装。"
		return 1
	fi


	#***********************************************************************
	# macOS13及以下
	# echo $i
	# macOS14输出结果：/dev/disk6s1

	# for i in $1; do

	# 	onceCutVal=${i%/*}
	# 	twiceCutVal=${onceCutVal#*//}
	# 	thriceCutVal=${i##*/}
	# 	echo "新设备: "${thriceCutVal}

	# 	# echo "---------\n"
	# 	sudo umount $i

	# 	sudo -S /System/Volumes/Data/$NTFS3G_PATH /dev/${twiceCutVal} "/Volumes/${thriceCutVal}" -olocal -oallow_other -oauto_xattr -ovolname="${thriceCutVal}"
	# 	echo "新设备: ${thriceCutVal}，已可读写！"

	# 	echo "---------\n"
	# done
	#*******************************************************************


	#***********************************************************************
	# macOS14及以上
 	# https://github.com/hoochanlon/Free-NTFS-for-Mac/issues/20

	# 输出结果：
	# /dev/disk4s1 on /Volumes/TOSHIBA (ntfs, local, nodev, nosuid, read-only, noowners, noatime)
	lines=$(mount | grep ntfs)

	# 逐行处理
	while IFS= read -r line; do
	    # 提取disk和volume名称
	    disk=$(echo "$line" | awk '{split($1, a, "/"); print a[3]}')
	    volume=$(echo "$line" | awk '{split($3, a, "/"); print a[3]}')

	    # 检查是否已经处理过（避免重复处理）
	    if [ -f "/tmp/ntfs_mounted_${disk}" ]; then
	        continue
	    fi

	    echo "Disk: $disk"
	    echo "Volume: $volume"

	    # 卸载分区
	    # sudo umount /dev/$disk
	    # 强制卸载
	    sudo umount -f /dev/$disk 2>/dev/null

	    # 检查卸载是否成功
	    if [ $? -eq 0 ]; then
	        echo "分区 /dev/$disk 已成功卸载。"
	    else
	        echo "分区 /dev/$disk 卸载失败，请检查是否还有进程正在使用该分区。"
	        continue
	    fi

	    # 重新挂载为读写模式（添加超时和Windows快速启动处理）
	    # 使用 timeout 命令防止卡死（macOS 使用 gtimeout，如果没有则使用后台进程+kill）
	    # -o remove_hiberfile: 处理Windows快速启动导致的休眠文件
	    # -o noatime: 提高性能
	    echo "正在挂载 /dev/$disk 到 /Volumes/$volume..."

	    # 尝试使用 timeout（如果系统有的话），否则使用后台进程+超时kill
	    if command -v timeout >/dev/null 2>&1; then
	        timeout 10 sudo -S /System/Volumes/Data/$NTFS3G_PATH /dev/$disk /Volumes/$volume -olocal -oallow_other -oauto_xattr -ovolname=$volume -oremove_hiberfile -onoatime 2>&1
	        mount_result=$?
	    elif command -v gtimeout >/dev/null 2>&1; then
	        gtimeout 10 sudo -S /System/Volumes/Data/$NTFS3G_PATH /dev/$disk /Volumes/$volume -olocal -oallow_other -oauto_xattr -ovolname=$volume -oremove_hiberfile -onoatime 2>&1
	        mount_result=$?
	    else
	        # 如果没有 timeout 命令，使用后台进程+超时kill
	        sudo -S /System/Volumes/Data/$NTFS3G_PATH /dev/$disk /Volumes/$volume -olocal -oallow_other -oauto_xattr -ovolname=$volume -oremove_hiberfile -onoatime 2>&1 &
	        mount_pid=$!
	        # 等待最多10秒
	        for i in {1..10}; do
	            if ! kill -0 $mount_pid 2>/dev/null; then
	                wait $mount_pid
	                mount_result=$?
	                break
	            fi
	            sleep 1
	        done
	        # 如果10秒后还在运行，杀死进程
	        if kill -0 $mount_pid 2>/dev/null; then
	            echo "警告: 挂载操作超时（可能是Windows快速启动导致），正在终止..."
	            sudo kill -9 $mount_pid 2>/dev/null
	            mount_result=124  # timeout exit code
	        fi
	    fi

	    # 检查挂载是否成功
	    if [ $mount_result -eq 0 ]; then
	        echo "新设备: ${volume}，已可读写！"
	        # 标记为已处理
	        touch "/tmp/ntfs_mounted_${disk}"
	    elif [ $mount_result -eq 124 ]; then
	        echo "错误: 挂载超时。可能是Windows快速启动导致文件系统处于脏状态。"
	        echo "建议: 在Windows中完全关闭（而非休眠），或禁用快速启动功能。"
	    else
	        echo "重新挂载分区 /dev/$disk 到 /Volumes/$volume 失败（退出码: $mount_result）。"
	        echo "提示: 如果是Windows快速启动问题，请在Windows中完全关闭后再试。"
	    fi

	    echo '---------'
	    echo " "
	done <<< "$lines"
		#***********************************************************************
	}

echo " "
echo " "
echo "等待NTFS新设备接入"
echo " "
echo '---------'
echo " "

# 清理旧的标记文件（设备可能已移除）
cleanup_old_mounts() {
	for marker in /tmp/ntfs_mounted_*; do
		if [ -f "$marker" ]; then
			disk=$(basename "$marker" | sed 's/ntfs_mounted_//')
			if ! mount | grep -q "/dev/$disk"; then
				rm -f "$marker"
			fi
		fi
	done
}

while true
do
	sleep 5
	# 清理已移除设备的标记
	cleanup_old_mounts

	newDev=$(mount | grep ntfs | awk -F ' ' '{print $1}')
	if [ ! -n "$newDev" ]; then
		a=1 # 无意义，过语法检测
	else
	#   echo "NTFS新设备接入成功"
	  config_u_drive $newDev
	fi

done
