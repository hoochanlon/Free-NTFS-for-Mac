import os
from time import sleep
import getpass
# 双引号转义：https://blog.csdn.net/try_and_do/article/details/80649663
# 强制字符串不转义：https://zhidao.baidu.com/question/2057931750861815427.html

苦手 = [

    "#/bin/bash\n", "\n", "close_boring(){\n", "sudo spctl --master-disable\n", 
    "}\n",
    "check_install() {\n","if [ ! -x $(command -v swift) ]; then\n",
    "xcode-select --install\n",
    "fi\n",
    "\n","\n",
    "if [ ! -x $(command -v brew) ]; then\n",
    "/bin/bash -c ", "\"$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)\"",
    "\nfi\n",
    "\n","\n",
    "if [ ! -e \"/System/Volumes/Data/opt/homebrew/bin/ntfs-3g\" ]; then"
    "\n",
    "brew tap gromgit/homebrew-fuse && brew install --cask macfuse && brew install ntfs-3g-mac\n",
    "fi\n",
    "}\n",
    "mount_nfs() {\n",
    "newDev=$(mount | grep ntfs | awk -F ' ' '{print $1}')\n",
    "for i in $newDev; do\n",
    "onceCutVal=","${i%/*}","\n",
    "twiceCutVal=","${onceCutVal#*//}","\n",
    "thriceCutVal=","${i##*/}","\n",
    "echo \"新设备: \"${thriceCutVal}\n",
    "echo '---------\\n'","\n",
    # "echo \"新设备 : \"$i\n",
    # "onceCutVal=","${i%/*}","\n",
    # "twiceCutVal=","${onceCutVal#*//}","\n",
    # "thriceCutVal=","${i##*/}","\n",
    "sudo umount $i","\n",
    "sudo -S /System/Volumes/Data/opt/homebrew/bin/ntfs-3g /dev/${twiceCutVal} /Volumes/${twiceCutVal} -olocal -oallow_other -o auto_xattr -ovolname=${thriceCutVal}",
    "\n","echo " "\"新设备: ${thriceCutVal}，已可读写！\"",
    "\ndone\n","}\n",
    "close_boring\n",
    "check_install\n",
    "mount_nfs\n"

]  
username = getpass.getuser()

def File_plus():
    folder_path = "/Users/"+username+"/Public/shell-ntfs.sh"
    if not os.path.exists(folder_path):
        file = open(folder_path, mode='w')
        file.writelines(苦手)
    
    else:
        print('\nshell-ntfs.sh 文件已检测\n')
        print('开启程序第一次启动，接入优盘时，需要输入电脑开机密码，方可正常使用\n')
        print('等待NTFS格式优盘接入')

File_plus()

# 第一个U盘完全挂载，再插入第二个U盘
while True:
    sleep(5)
    udev = os.popen("mount | grep ntfs | awk -F ' ' '{print $1}'")
    udev_result = udev.read()
    udev.close()
    if udev_result:
        print("\n已接入优盘")
        os.system("chmod 777 /Users/"+username+"/Public/shell-ntfs.sh")
        os.system("/Users/"+username+"/Public/shell-ntfs.sh")
        while True:
            sleep(5)
            udev = os.popen("mount | grep ntfs | awk -F ' ' '{print $1}'")
            udev_result = udev.read()
            udev .close()
            if not udev_result:
                print("------------")
                break

    else:
        # print("没有NTFS优盘接入")
        continue

