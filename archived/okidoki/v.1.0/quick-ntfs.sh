close_boring() {
	sudo spctl --master-disable
}
check_install() {
	if [ ! -x $(command -v swift) ]; then
		xcode-select --install
	fi

	if [ ! -x $(command -v brew) ]; then
		/bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"
	fi

	if [ ! -e "/System/Volumes/Data/opt/homebrew/bin/ntfs-3g" ]; then
		brew tap gromgit/homebrew-fuse && brew install --cask macfuse && brew install ntfs-3g-mac
	fi
}

mount_nfs() {
    

	newDev=$(mount | grep ntfs | awk -F ' ' '{print $1}')
	for i in $newDev; do
		onceCutVal=${i%/*}
		twiceCutVal=${onceCutVal#*//}
		thriceCutVal=${i##*/}
		echo "新设备: "${thriceCutVal}
		echo '---------\n'
		sudo umount $i
		sudo -S /System/Volumes/Data/opt/homebrew/bin/ntfs-3g /dev/${twiceCutVal} /Volumes/${twiceCutVal} -olocal -oallow_other -o auto_xattr -ovolname=${thriceCutVal}
		echo "新设备: ${thriceCutVal}，已可读写！"
	done

}

cctv() {

	while
		true
		sleep 5
	do
		mount_nfs
	done
}

close_boring
check_install
cctv

# udev=$(mount | grep ntfs | awk -F ' ' '{print $1}')
# chmod 777 /Users/"$(whoami)"/Public/shell-ntfs.sh
# /Users/"$(whoami)"/Public/shell-ntfs.sh
# close_boring
# check_install
# mount_nfs
