config_u_drive(){
	sudo spctl --master-disable
	
	if [ ! -x $(command -v swift) ]; then
	xcode-select --install
	fi


	if [ ! -x $(command -v brew) ]; then
	/bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"
	fi


	if [ ! -e "/System/Volumes/Data/$(which ntfs-3g)" ]; then
	brew tap gromgit/homebrew-fuse && brew install --cask macfuse && brew install ntfs-3g-mac
	fi
	
	for i in $1; do
		onceCutVal=${i%/*}
		twiceCutVal=${onceCutVal#*//}
		thriceCutVal=${i##*/}
		echo "新设备: "${thriceCutVal}
		## echo '---------\n'
		sudo umount $i
		sudo -S /System/Volumes/Data/$(which ntfs-3g) /dev/${twiceCutVal} "/Volumes/${thriceCutVal}" -olocal -oallow_other -oauto_xattr -ovolname="${thriceCutVal}"
		echo "新设备: ${thriceCutVal}，已可读写！"
		# echo '---------\n'
		echo '---------'
		echo " "
	done

}

# origin echo text
# echo "\n"
# echo "等待NTFS新设备接入\n"
# echo '---------\n'

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
