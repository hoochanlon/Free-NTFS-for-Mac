#/bin/bash

# set -e

function check_install() {

  # 判断Xcode是否有安装，如果不存在工具行目录，安装Xcode
  if [ ! -d "/Library/Developer/CommandLineTools/" ]; then
    xcode-select --install
  fi

  # [! -n] 条件不为空，[! -d] 则不是或不存在这个目录
  if [ ! -d "/opt/homebrew/bin/" ]; then
    /bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"
  fi

  # /usr/local/bin/ntfs-3g
  # 有提示安装升级，不需要判断是否安装过此软件。
  brew tap gromgit/homebrew-fuse && brew install --cask macfuse && brew install ntfs-3g-mac

}

function mount_nfs() {

  newDev=$(mount | grep ntfs | awk -F ' ' '{print $1}')

# for循环，每有一个新设备，来一次。
  for i in $newDev; do
    echo "新设备 : "$i
    echo '----------\n' #打印换行

    onceCutVal="${i%/*}"

    twiceCutVal="${onceCutVal#*//}"

    sudo umount $i

    # ${twiceCutVal} 替代了NTFS
    sudo /System/Volumes/Data/opt/homebrew/bin/ntfs-3g /dev/${twiceCutVal} /Volumes/${twiceCutVal} -olocal -oallow_other -o auto_xattr
    # sudo /System/Volumes/Data/opt/homebrew/bin/ntfs-3g /dev/disk4s1 /Volumes/NTFS -olocal -oallow_other -o auto_xattr

    echo "新${twiceCutVal}设备，添加写权限成功！"

  done

}

ping -c 3 www.baidu.com
if [ $? -eq 0 ]; then
  echo "success!"
  check_install
  mount_nfs
else
  echo "fail!"
fi
