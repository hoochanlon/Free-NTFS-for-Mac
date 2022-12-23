from time import sleep
import os
# 结论：并没什么用的。
while True:
    sleep(5)
    # NTFS格式、FAT23格式、exFAT格式
    format = ["ntfs", "msdos", "exfat"]
    for i in format:
    	# 通过Linux命令查询是否插入U盘
        print("mount | grep {0} | awk -F ' ' {1}".format(i, "'{print $1}'"))
        # 返回的是一个文件对象
        udev = os.popen("mount | grep {0} | awk -F ' ' {1}".format(i, "'{print $1}'"))
        # 通过文件的read()读取所返回的内容
        udev_result = udev.read()
        # 返回值是文件对象，使用完必须关闭。
        udev.close()
        if udev_result:
            print("USB disk connected")
            while True:
                sleep(5)
                udev = os.popen("mount | grep {0} | awk -F ' ' {1}".format(i, "'{print $1}'"))
                udev_result = udev.read()
                udev .close()
                if not udev_result:
                    print("USB disk unplugged")
                    break

    else:
        print("No USB disk found")
        continue