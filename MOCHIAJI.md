## 个性化
 
**重命名及格式化U盘，需用 `diskutil list` 查看挂载盘ID方可对应操作。**

### 重命名
 
![](https://fastly.jsdelivr.net/gh/hoochanlon/free-mac-ntfs/shashin/rename.png)
 
 
 ```shell
 sudo umount /dev/disk4s2
 ```
 
 ```shell
 sudo ntfslabel /dev/disk4s2 carsh
 ```
 
### 格式化为NTFS

![](https://fastly.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac/shashin/formatntfs.png)
 
```shell
 sudo diskutil unmount /dev/disk4s1
```
 
```shell
 sudo mkntfs -f /dev/disk4s1
```

注意格式化完成后，是不显示U盘的，此时需要重新插拔U盘。

### U盘图标设定

macOS与Windows图标设置是独立的，只能在所在的对应系统显示。关于Windows系统，请查看[保姆级教学，手把手教你修改U盘显示图标](https://baijiahao.baidu.com/s?id=1717036176555487935&wfr=spider&for=pc&searchword=ntfs-3g修改u盘图标)，macOS的演示研究中。


