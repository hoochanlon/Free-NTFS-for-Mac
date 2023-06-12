# 引入模块
import os
from time import sleep
import getpass
# 双引号转义：https://blog.csdn.net/try_and_do/article/details/80649663
# 强制字符串不转义：https://zhidao.baidu.com/question/2057931750861815427.html

# 要运行的命令序列
ntfs_yes = [
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
    "if [ ! -e \"/System/Volumes/Data/$(which ntfs-3g)\" ]; then"
    "\n",
    "brew tap gromgit/homebrew-fuse && brew install --cask macfuse && brew install ntfs-3g-mac\n",
    "fi\n",
    "}\n",
    "mount_nfs() {\n",
    # 将所有挂载为 NTFS 格式的设备读取出来进行处理
    "newDev=$(mount | grep ntfs | awk -F ' ' '{print $1}')\n",
    # 对于每个设备进行操作
    "for i in $newDev; do\n",
    # 对设备路径字符串进行处理，获取设备名字和挂载路径
    "onceCutVal=","${i%/*}","\n",
    "twiceCutVal=","${onceCutVal#*//}","\n",
    "thriceCutVal=","${i##*/}","\n",
    # 输出设备名字
    "echo \"新设备: \"${thriceCutVal}\n",
    # 输出分割线
    "echo '---------\\n'","\n",
    # 将设备卸载
    "sudo umount $i","\n",
    # 重新挂载为可读写的 NTFS 格式
    'sudo -S /System/Volumes/Data/$(which ntfs-3g) /dev/${twiceCutVal} "/Volumes/${thriceCutVal}" -olocal -oallow_other -oauto_xattr -ovolname="${thriceCutVal}"',
    # 输出挂载完成信息
    "\n","echo " "\"新设备: ${thriceCutVal}，已可读写！\"",
    "\ndone\n","}\n",
    # 禁用 macOS 的 Gatekeeper
    "close_boring\n",
    # 检查是否已安装必要软件
    "check_install\n",
    # 挂载 NTFS 格式的设备
    "mount_nfs\n"
]

# 获取当前用户名
username = getpass.getuser()

def File_plus():
    # 定义 shell 文件存放路径
    folder_path = "/Users/" + username + "/Public/shell-ntfs.sh"

    # 如果文件不存在则创建
    if not os.path.exists(folder_path):
        file = open(folder_path, mode='w')
        file.writelines(ntfs_yes)
        print('\n等待NTFS格式优盘接入')
    else:
        print('\nshell-ntfs.sh 文件已检测\n')
        print('开启程序第一次启动，接入优盘时，需要输入电脑开机密码，方可正常使用\n')
        print('等待NTFS格式优盘接入')

# 创建 shell 文件
File_plus()

# 第一个 U 盘完全挂载，再插入第二个 U 盘
while True:
    sleep(5)
    udev = os.popen("mount | grep ntfs | awk -F ' ' '{print $1}'")
    udev_result = udev.read()
    udev.close()

    # 如果已接入 NTFS 格式的优盘，则执行进行挂载的脚本 shell-ntfs.sh
    if udev_result:
        print("\n已接入优盘")
        os.system("chmod 777 /Users/"+username+"/Public/shell-ntfs.sh")
        os.system("/Users/"+username+"/Public/shell-ntfs.sh")

        # 挂载完成后等待下一个 U 盘插入
        while True:
            sleep(5)
            udev = os.popen("mount | grep ntfs | awk -F ' ' '{print $1}'")
            udev_result = udev.read()
            udev.close()
            if not udev_result:
                print("------------")
                break

    else:
        # 没有 NTFS 格式的优盘插入则继续等待
        continue
