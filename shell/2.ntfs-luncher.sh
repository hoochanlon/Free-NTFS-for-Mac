#/bin/bash

newDev=$(mount | grep ntfs|awk -F ' ' '{print $1}')

for i in $newDev;
do
    echo "新设备 : "$i
    echo  '----------\n'  #打印换行

    onceCutVal="${i%/*}"

    twiceCutVal="${onceCutVal#*//}"

    sudo umount $i

    # ${twiceCutVal} 替代了NTFS
    sudo /System/Volumes/Data/opt/homebrew/bin/ntfs-3g /dev/${twiceCutVal} /Volumes/${twiceCutVal} -olocal -oallow_other -o auto_xattr
    # sudo /System/Volumes/Data/opt/homebrew/bin/ntfs-3g /dev/disk4s1 /Volumes/NTFS -olocal -oallow_other -o auto_xattr

    echo "新${twiceCutVal}设备，添加写权限成功！"

done
