
    if [ ! -x $(command -v swift) ]; then
        xcode-select --install
    fi

    if [ ! -x $(command -v brew) ]; then
        /bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"
    fi

    if [ ! -e "/System/Volumes/Data/$(which ntfs-3g)" ]; then
        brew tap gromgit/homebrew-fuse && brew install --cask macfuse && brew install ntfs-3g-mac
    fi

    version=$(sw_vers -productVersion | cut -d '.' -f 1)

    if [ $version -ge 14 ]; then
        # macOS14及以上执行的代码
        # https://github.com/hoochanlon/Free-NTFS-for-Mac/issues/20

        # 输出结果：
        # /dev/disk4s1 on /Volumes/TOSHIBA (ntfs, local, nodev, nosuid, read-only, noowners, noatime)
        # 特殊：macfuse已成功加载的情况下
        # /dev/disk4s1 on /Volumes/TOSHIBA (macfuse, local, synchronous)
        line=$(mount | grep ntfs)

        # 提取disk和volume名称
        disk=$(echo "$line" | awk '{split($1, a, "/"); print a[3]}')
        volume=$(echo "$line" | awk '{split($3, a, "/"); print a[3]}')
        # echo  $line
        # echo "Disk: $disk"
        # echo "Volume: $volume"
        sudo umount /dev/$disk
        sudo -S ntfs-3g /dev/$disk /Volumes/$volume -olocal -oallow_other -o auto_xattr -ovolname=$volume
        echo "新设备: ${volume}，已可读写！"
        echo '---------'
        echo " "
    else
        # macOS13及以下执行的代码
        # echo $i （macOS14输出结果：/dev/disk6s1）
        # $1表示传递给脚本或函数的第一个参数，即U盘挂载信息。
        for i in $1; do
            onceCutVal=${i%/*}
            twiceCutVal=${onceCutVal#*//}
            thriceCutVal=${i##*/}
            # echo "新设备: "${thriceCutVal}
            sudo umount $i
            sudo -S /System/Volumes/Data/$(which ntfs-3g) /dev/${twiceCutVal} "/Volumes/${thriceCutVal}" -olocal -oallow_other -oauto_xattr -ovolname="${thriceCutVal}"
            echo "新设备: ${thriceCutVal}，已可读写！"
            echo '---------'
            echo " "
        done
    fi
}

echo " "
echo " "
echo "等待NTFS新设备接入"
echo " "
echo '---------'
echo " "

while true; do
    sleep 5
    newDev=$(mount | grep ntfs | awk -F ' ' '{print $1}')
    if [ ! -n "$newDev" ]; then
        a=1 # 无意义，过语法检测
    else
        #   echo "NTFS新设备接入成功"
        config_u_drive $newDev
    fi

done
