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

	    echo "Disk: $disk"
	    echo "Volume: $volume"

	    # 卸载分区
	    # sudo umount /dev/$disk
	    # 强制卸载
	    sudo umount -f /dev/$disk

	    # 检查卸载是否成功
	    if [ $? -eq 0 ]; then
	        echo "分区 /dev/$disk 已成功卸载。"
	    else
	        echo "分区 /dev/$disk 卸载失败，请检查是否还有进程正在使用该分区。"
	        continue
	    fi

	    # 重新挂载为读写模式
	    sudo -S /System/Volumes/Data/$NTFS3G_PATH /dev/$disk /Volumes/$volume -olocal -oallow_other -oauto_xattr -ovolname=$volume

	    # 检查挂载是否成功
	    if [ $? -eq 0 ]; then
	        echo "新设备: ${volume}，已可读写！"
	    else
	        echo "重新挂载分区 /dev/$disk 到 /Volumes/$volume 失败。"
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

while true
do
	sleep 5
	newDev=$(mount | grep ntfs | awk -F ' ' '{print $1}')
	if [ ! -n "$newDev" ]; then
		a=1 # 无意义，过语法检测
	else
	#   echo "NTFS新设备接入成功"
	  config_u_drive $newDev
	fi

done
