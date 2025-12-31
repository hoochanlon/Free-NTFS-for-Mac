'''
双引号转义：https://blog.csdn.net/try_and_do/article/details/80649663
强制字符串不转义：https://zhidao.baidu.com/question/2057931750861815427.html
'''


def shell_script(folder_path):
    ntfs_shell = [
        "#/bin/bash\n",
        "\n",
        "close_boring(){\n",
        "   sudo spctl --master-disable\n",
        "}\n",
        "\n",
        "check_install(){\n",
        "   if [ ! -x $(command -v swift) ]; then\n",
        "       xcode-select --install\n",
        "   fi\n",
        "\n",
        "   if [ ! -x $(command -v brew) ]; then\n",
        "       /bin/bash -c ", '"$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"\n',
        "   fi\n",
        "\n",
        '   if [ ! -e "/System/Volumes/Data/opt/homebrew/bin/ntfs-3g" ]; then\n',
        "       brew tap gromgit/homebrew-fuse && brew install --cask macfuse && brew install ntfs-3g-mac\n",
        "   fi\n",
        "}\n",
        "\n",
        "mount_nfs(){\n",
        "   newDev=$(mount | grep ntfs | awk -F ' ' '{print $1}')\n",
        "   for i in $newDev; do\n",
        "       onceCutVal=${i%/*}\n",
        "       twiceCutVal=${onceCutVal#*//}\n",
        "       thriceCutVal=${i##*/}\n",
        "       echo '新设备: '${thriceCutVal}\n",
        "       echo '---------\\n'\n",
        "       sudo umount $i\n",
        "       sudo -S /System/Volumes/Data/opt/homebrew/bin/ntfs-3g /dev/${twiceCutVal} /Volumes/${twiceCutVal} -olocal -oallow_other -o auto_xattr -ovolname=${thriceCutVal}\n",
        '       echo "新设备: ${thriceCutVal}，已可读写!"\n',
        "   done\n",
        "}\n",
        "\n",
        "close_boring\n",
        "check_install\n",
        "mount_nfs\n"
    ]
    file = open(folder_path, mode='w')
    file.writelines(ntfs_shell)


if __name__ == "__main__":
    # shell_script("C:\\Users\\admin\\Desktop\\shell-ntfs.sh")
    pass
