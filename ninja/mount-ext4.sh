#!/usr/bin/env bash

# 1. 自动检测 Linux 分区标识符 (如 disk4s1)
DEVICE_ID=$(diskutil list | grep "Linux" | awk '{print $NF}' | head -n 1)

if [ -z "$DEVICE_ID" ]; then
    echo "❌ 错误：未发现 Linux (ext4) 分区。"
    exit 1
fi

# 2. 尝试获取卷标名称 (Volume Name)
# 优先从 diskutil 获取，如果无效则挂载后动态检测
VOL_NAME=$(diskutil info "$DEVICE_ID" | grep "Volume Name" | awk -F': ' '{print $2}' | xargs)

# 如果是 macOS 的占位描述，标记为无效
if [[ "$VOL_NAME" == "Not applicable (no file system)" ]]; then
    VOL_NAME=""
fi

# 如果环境变量设置了卷名，优先使用
if [ -n "$EXT4_VOLUME_NAME" ]; then
    VOL_NAME="$EXT4_VOLUME_NAME"
fi

echo ">>> 发现设备: /dev/$DEVICE_ID (卷名: ${VOL_NAME:-待挂载后检测})"

# 3. 清理旧挂载防止冲突
sudo anylinuxfs unmount > /dev/null 2>&1

# 4. 执行挂载
echo ">>> 正在执行挂载..."
sudo anylinuxfs mount "/dev/$DEVICE_ID"

# 4.1 挂载后：从 anylinuxfs list 反查设备名称（通常就是你想要的 /Volumes 目录名）
# 示例行：
# 1:                       ext4 sandisk-ext             30.1 GB    disk4s1
ANYLINUXFS_LINE=$(sudo anylinuxfs list 2>/dev/null | grep "$DEVICE_ID" | head -n 1)
if [ -n "$ANYLINUXFS_LINE" ]; then
    ANYLINUXFS_VOL_NAME=$(echo "$ANYLINUXFS_LINE" | awk '{print $3}' | xargs)
    # 如果前面 diskutil 拿不到卷名，这里用 anylinuxfs 的名称补上
    if [ -z "$VOL_NAME" ] && [ -n "$ANYLINUXFS_VOL_NAME" ]; then
        VOL_NAME="$ANYLINUXFS_VOL_NAME"
    fi
fi

# 5. 动态权限修复
# 循环检测直到虚拟机内部挂载点就绪
echo ">>> 正在等待虚拟机内部权限就绪..."
for i in {1..15}; do
    # anylinuxfs list 的最后一列通常是内部挂载路径
    VM_PATH=$(sudo anylinuxfs list | grep "$DEVICE_ID" | awk '{print $NF}')

    if [ ! -z "$VM_PATH" ] && [ "$VM_PATH" != "PATH" ]; then
        # 在虚拟机 Linux 内部直接暴力提权
        sudo anylinuxfs exec "chmod -R 777 $VM_PATH" > /dev/null 2>&1
        break
    fi
    sleep 1
done

# 6. 动态检测实际挂载点
echo ">>> 正在检测实际挂载点..."
FINAL_PATH=""

# 等待挂载完成
sleep 2

# 优先：如果 anylinuxfs 给出了设备名称，macOS 侧通常会是 /Volumes/<name>
if [ -n "$VOL_NAME" ] && [ -d "/Volumes/$VOL_NAME" ]; then
    FINAL_PATH="/Volumes/$VOL_NAME"
fi

# 方法1: 通过 diskutil info 查找该设备对应的实际挂载点
if [ -z "$FINAL_PATH" ]; then
    MOUNT_POINT=$(diskutil info "$DEVICE_ID" 2>/dev/null | grep "Mount Point" | awk -F': ' '{print $2}' | xargs)
    if [ -n "$MOUNT_POINT" ] && [ -d "$MOUNT_POINT" ]; then
        FINAL_PATH="$MOUNT_POINT"
    fi
fi

# 方法2: 如果 diskutil 找不到，尝试从 anylinuxfs list 获取
if [ -z "$FINAL_PATH" ] && [ -n "$VOL_NAME" ]; then
    # 退而求其次：用卷名拼 /Volumes
    if [ -d "/Volumes/$VOL_NAME" ]; then
        FINAL_PATH="/Volumes/$VOL_NAME"
    fi
fi

# 方法3: 如果环境变量设置了卷名，尝试使用
if [ -z "$FINAL_PATH" ] && [ -n "$VOL_NAME" ]; then
    if [ -d "/Volumes/$VOL_NAME" ]; then
        FINAL_PATH="/Volumes/$VOL_NAME"
    fi
fi

# 方法4: 扫描 /Volumes 目录，通过 diskutil info 匹配设备ID
if [ -z "$FINAL_PATH" ]; then
    for vol in /Volumes/*; do
        if [ -d "$vol" ] && [ ! "$vol" = "/Volumes" ]; then
            # 检查该挂载点是否对应我们的设备
            VOL_DEVICE=$(diskutil info "$vol" 2>/dev/null | grep "Device Node" | awk -F': ' '{print $2}' | xargs)
            if [ "$VOL_DEVICE" = "/dev/$DEVICE_ID" ]; then
                FINAL_PATH="$vol"
                break
            fi
        fi
    done
fi

# 7. 打开 Finder
if [ -n "$FINAL_PATH" ] && [ -d "$FINAL_PATH" ]; then
    echo "✅ 挂载成功且权限已修复: $FINAL_PATH"
    open "$FINAL_PATH"
else
    echo "⚠️ 挂载已触发，但 Finder 路径未就绪，请手动查看 /Volumes"
    echo ">>> 调试信息:"
    echo "   - 设备: /dev/$DEVICE_ID"
    echo "   - diskutil Volume Name: ${VOL_NAME:-<空/未获取>}"
    echo "   - diskutil Mount Point: ${MOUNT_POINT:-<空/未获取>}"
    echo "   - anylinuxfs list:"
    sudo anylinuxfs list 2>/dev/null | grep "$DEVICE_ID" || true
    echo "   提示: 可以通过环境变量 EXT4_VOLUME_NAME 指定卷名，例如:"
    echo "   EXT4_VOLUME_NAME=${VOL_NAME:-your-volume-name} $0"
    open "/Volumes"
fi
