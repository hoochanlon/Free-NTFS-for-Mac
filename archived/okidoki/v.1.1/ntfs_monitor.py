import os
from time import sleep
from shell_ntfs_by_python import shell_script


def run_shell():
    path = os.getcwd()
    folder_path = f"{path}/shell-ntfs.sh"
    monitor_val = 1
    while True:
        if not os.path.exists(folder_path):
            shell_script(folder_path)

        else:
            if monitor_val == 1:
                print('\nshell-ntfs.sh 文件已检测\n')
                print('开启程序第一次启动，接入优盘时，需要输入电脑开机密码，方可正常使用\n')
                print('等待NTFS格式优盘接入')
            monitor_val -= 1
            sleep(3)
            udev = os.popen("mount | grep ntfs | awk -F ' ' '{print $1}'")
            udev_result = udev.read()
            udev.close()
            if udev_result:
                print("\n已接入优盘")
                os.system(f"chmod 777 {path}/shell-ntfs.sh")
                os.system(f"{path}/shell-ntfs.sh")
                while True:
                    sleep(3)
                    udev = os.popen("mount | grep ntfs | awk -F ' ' '{print $1}'")
                    udev_result = udev.read()
                    udev .close()
                    if not udev_result:
                        print("------------")
                        break

            else:
                # print("没有NTFS优盘接入")
                continue


if __name__ == "__main__":
    run_shell()
