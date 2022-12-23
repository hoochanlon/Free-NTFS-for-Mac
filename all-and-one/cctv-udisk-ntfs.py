from time import sleep
import os
# 第一个U盘完全挂载，再插入第二个U盘
while True:
    sleep(5)
    udev = os.popen("mount | grep ntfs | awk -F ' ' '{print $1}'")
    udev_result = udev.read()
    udev.close()
    if udev_result:
        print("已接入优盘")
        os.system("chmod 777 /Users/chanlonhoo/Desktop/ntfs_support.sh")
        os.system("/Users/chanlonhoo/Desktop/ntfs_support.sh")
        while True:
            sleep(5)
            udev = os.popen("mount | grep ntfs | awk -F ' ' '{print $1}'")
            udev_result = udev.read()
            udev .close()
            if not udev_result:
                print("------------")
                break

    else:
        print("No USB disk found")
        continue
