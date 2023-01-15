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

---

<details><summary><i> 不建议的操作，U盘图标设定 </i></summary>

须注意：

***macOS与Windows图标设置是独立的，只能在所在的对应系统显示，而且由于Mac平台下NTFS的特殊性，配置图标操作尤为有限。**

**⚠️不能直接配置在`/Volumes/`根目录，图标配置不当会导致挂载功能紊乱。⚠️** 

**解决办法：再安装一个同类的NTFS for Mac，只要不卸载，挂载功能紊乱，就不出继续出现。还想成当初的样子，得重装系统了。** 

说完前面善意提醒，以下正题：

配置NTFS磁盘图标缺陷颇多，在 `/Library/Filesystems/`以包内容显示macfuse.fs，可替换对应图标。

![](https://fastly.jsdelivr.net/gh/hoochanlon/Free-NTFS-for-Mac/shashin/icon-re.png)

通过 `sudo ntfs-3g /dev/disk4s1 ~/Desktop/mnt` 挂载可出现效果，可这样挂载忽略显示了NTFS已有文件，再复制同名到U盘会报错。

附：Windows系统改写U盘图标，[保姆级教学，手把手教你修改U盘显示图标](https://baijiahao.baidu.com/s?id=1717036176555487935&wfr=spider&for=pc&searchword=ntfs-3g修改u盘图标)。

</details>
