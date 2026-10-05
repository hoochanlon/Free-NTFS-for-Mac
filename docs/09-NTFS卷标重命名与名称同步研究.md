# macOS 上 NTFS 可移动介质的名称身份分裂与同步机制

## 摘要

在 macOS 上对 NTFS 可移动介质执行重命名时，桌面（Finder）可以立刻显示新名称，而 `diskutil` 与本应用设备列表仍停留在旧名称；只有整盘推出再接入后，三者才会重新对齐。本文把这一现象建模为**多源名称身份**问题：NTFS 卷标、GPT 分区名、Finder 显示名、DiskArbitration 缓存、以及 `/Volumes` 挂载路径并不共享同一写入路径。基于实测与实现对照，本文说明：仅用 `ntfslabel` 改卷标并挂回旧路径，不足以刷新 `diskutil` 与应用侧读取源；必须在卸载后同步 GPT 分区名、强制整盘卸载以清空 DiskArbitration 旧名，再把卷挂到 `/Volumes/<新名称>`。该流程在不物理推出设备的前提下完成名称收敛。

**关键词**：NTFS 卷标；GPT 分区名；DiskArbitration；macOS 挂载路径；名称一致性

---

## 1. 问题陈述

### 1.1 现象

用户在本应用中对 NTFS 设备执行重命名后，出现如下三方不一致：

| 观察面 | 重命名后立即状态 | 推出再接入后 |
|--------|------------------|--------------|
| 桌面 / Finder | 已显示新名称 | 新名称 |
| 本应用设备列表 | 仍显示旧名称 | 新名称 |
| `diskutil list` 的 `NAME` 列 | 仍显示旧名称 | 新名称 |

该现象在 GPT 分区的 U 盘上尤为稳定。典型对照是：桌面图标已经是 `SanDisk 32`，而 `diskutil list` 仍打印 `SanDisk 32G`，本应用同步读取后者。

### 1.2 研究问题

1. 桌面名称、`diskutil` 名称、应用内名称分别从哪一层数据源读取？
2. 为什么只写 NTFS 卷标并重新挂载，无法让后两者同步？
3. 不依赖物理推出的最小充分操作集是什么？

### 1.3 约束

- 目标文件系统为 NTFS，宿主为 macOS。
- 本应用通过 `ntfs-3g` / macFUSE 提供读写挂载，只读路径走系统 `diskutil mount`。
- 不允许把“推出再插入”作为产品流程的一部分。
- GPT 分区名写入失败时，不得阻断已经成功的 NTFS 卷标更新。

---

## 2. 名称身份的分层模型

macOS 并不存在单一的“磁盘名字段”。可移动 NTFS 介质至少同时携带五层可独立演化的标识：

```
┌─────────────────────────────────────────────────────────┐
│  L5  Finder / 桌面显示名                                 │
│      .DS_Store / Spotlight / 卷显示属性                  │
├─────────────────────────────────────────────────────────┤
│  L4  挂载路径  /Volumes/<name>                           │
│      mount(8) 与本应用 volumeName 的直接来源              │
├─────────────────────────────────────────────────────────┤
│  L3  DiskArbitration 运行时缓存                          │
│      diskarbitrationd 记住的卷名，随整盘卸载/推出失效     │
├─────────────────────────────────────────────────────────┤
│  L2  分区表名称                                          │
│      GPT: PARTNAME（diskutil list 的 NAME）              │
│      MBR: 无独立分区名，diskutil 常回退到卷标             │
├─────────────────────────────────────────────────────────┤
│  L1  NTFS 卷标                                           │
│      $Volume / BPB 中的 volume label（ntfslabel）        │
└─────────────────────────────────────────────────────────┘
```

五层之间没有强制事务。任意一层被单独改写，都会表现为“有的界面已经改名，有的界面还没有”。

### 2.1 L1：NTFS 卷标

NTFS 把卷名存在文件系统内部。`ntfs-3g` 提供的 `ntfslabel` 直接改这一层。这是跨 Windows / macOS / Linux 真正可携带的名字，也是“重命名成功”的语义终点。

限制：

- 必须在未挂载状态下写入。
- 脏卷（hiberfile、快速启动残留）会导致写入失败。
- 写入成功并不自动改 GPT 分区名，也不保证 macOS 立刻丢掉旧缓存。

### 2.2 L2：GPT 分区名

`diskutil list` 在 GPT 盘上打印的 `NAME`，来自分区表项的 `PARTNAME`，不是 NTFS 卷标。实测形态如下：

```
/dev/disk6 (external, physical):
   #:                       TYPE NAME                    SIZE       IDENTIFIER
   0:      GUID_partition_scheme                        *30.8 GB   disk6
   1:                        EFI EFI                    209.7 MB   disk6s1
   2:          Microsoft Basic Data SanDisk 32G         30.6 GB    disk6s2
```

这里的 `SanDisk 32G` 是 GPT 名。Finder 已经改成 `SanDisk 32` 时，这一列可以纹丝不动。

MBR / FDisk 盘没有等价字段。`Windows_NTFS Samsung USB` 这类输出里，`NAME` 更接近卷标，因此 MBR 盘上的不同步往往更轻。

### 2.3 L3：DiskArbitration 缓存

`diskarbitrationd` 在设备接入时登记卷身份。只卸载分区（`diskutil unmount /dev/diskXsY`）常常不够：父盘仍在，守护进程继续持有旧名。整盘卸载（`diskutil unmountDisk`）或物理推出才会让它重建登记。

这解释了用户的原始 workaround：推出再装上之后，`diskutil` 与应用才看到新名。

### 2.4 L4：挂载路径

本应用检测器对已挂载设备的命名规则是：

```
volumeName = volume.replace('/Volumes/', '')
```

也就是说，**应用显示名等于挂载点目录名**，而不是 `diskutil info` 的 `Volume Name`。

因此：

- 若仍挂在 `/Volumes/SanDisk 32G`，应用必然显示旧名。
- `ntfs-3g -ovolname=新名` 只影响 Finder / FUSE 显示名，不改挂载路径。
- 重挂时若把 `device.volume` 原样传回，等于主动把旧路径写死。

这是第一版实现失败的直接原因。

### 2.5 L5：Finder 显示名

Finder 允许用户在桌面改名，且可以只改显示属性，不写 L1 / L2。桌面“已经是新名”因此不能被解读为“磁盘上的卷标已经更新”。它只说明 L5（有时加上 L4 的显示层）变了。

本应用若只追随 Finder，会把一次未落盘的显示名改动误判为卷标重命名。正确策略是以 L1 为写入目标，再主动收敛 L2–L4。

---

## 3. 读取路径对照

| 消费者 | 主读取源 | 次读取源 | 对旧名的敏感点 |
|--------|----------|----------|----------------|
| Finder / 桌面 | L5 显示属性，其次 L4 / FUSE `volname` | L1 | 显示层可单独超前 |
| `diskutil list` | L2 GPT `PARTNAME` | L1（MBR） | GPT 盘上与卷标解耦 |
| `diskutil info` | L3 缓存的 Volume Name | L1 | 整盘未卸载时滞后 |
| 本应用（已挂载） | L4 `/Volumes/<name>` | — | 挂回旧路径即显示旧名 |
| 本应用（未挂载） | `diskutil info` 的 Volume Name | L2 | 继承 L3 滞后 |
| `ntfs-3g` 读写挂载 | `-ovolname` + 传入的挂载点 | L1 | 参数不更新则两边都旧 |

结论：应用与 `diskutil` 对齐失败，不是 UI 刷新 bug，而是读取源根本不在 Finder 那一层。

---

## 4. 失败路径分析

### 4.1 第一版流程

```
unmount(分区)
  → ntfslabel(设备, 新名)          # 只写 L1
  → 若只读: diskutil mount 分区
    若读写: ntfs-3g -ovolname=新名，挂载点仍为旧 volume
  → 刷新设备列表
```

### 4.2 为何桌面先变、工具仍旧

1. **L1 已更新**，Finder 能从卷标或 `volname` 读到新名，L5 立即超前。
2. **L4 未更新**。读写重挂仍使用 `device.volume = /Volumes/旧名`，检测器继续切出旧 `volumeName`。
3. **L2 未更新**。GPT 盘上 `diskutil list` 继续打印分区名。
4. **L3 未失效**。只卸载分区时，`diskarbitrationd` 仍缓存旧 Volume Name。
5. 物理推出同时击穿 L3 与挂载点，系统按 L1/L2 重建身份，三方才偶然对齐。

因此，“推出再装上就能好”不是重命名本身需要热插拔，而是热插拔碰巧做了一次全层缓存失效。

### 4.3 检测器放大效应

设备列表哈希最初只包含 `disk / isMounted / isReadOnly`，不含 `volumeName`。即便底层名变了，事件层也可能判定“无变化”。名称同步必须同时满足：

- 挂载路径或 `diskutil` 输出已经是新名；
- 检测缓存被强制失效。

---

## 5. 收敛策略

目标是一次重命名内完成：

```
L1 写入成功
  ∧ L4 挂到 /Volumes/新名
  ∧ L3 通过整盘卸载失效
  ∧ L2 尽力写成新名（失败不阻断）
```

L5 由系统在重新挂载后自然跟随，不作为写入对象。

### 5.1 操作序列

```
校验路径与新名
  → 取管理员密码
  → diskutil unmount 分区
  → 清除本应用读写标记
  → ntfslabel 写入 L1
  → 若 L1 成功:
        diskutil unmountDisk force 父盘     # 失效 L3
        gpt label -i <分区号> -l 新名 rdisk  # 尽力写 L2
  → 按原模式重挂:
        只读 → mountDisk 父盘，失败则 mount 分区
        读写 → ntfs-3g，volume 与 volname 均为新名
  → rmdir 旧 /Volumes/旧名（仅空目录）
  → 使设备检测缓存失效
```

### 5.2 设计选择

**整盘卸载而不是物理推出。**  
`unmountDisk force` 足以让 DiskArbitration 丢掉旧登记，设备节点仍在，用户不必拔插。

**GPT 写入放在 L1 成功之后，且允许失败。**  
MBR 盘没有 `PARTNAME`；部分系统上 `gpt label` 会因 SIP 或设备忙失败。L1 才是可携带卷标，L2 只服务 `diskutil` 观感。

**读写挂载必须改 `volume`，不能只改 `volname`。**  
否则 Finder 新、应用旧的分裂会原样保留。

**旧挂载点只 `rmdir`。**  
避免误删用户数据；目录非空或不存在时忽略。

**名称校验保持 NTFS 惯例。**  
去空白、长度 ≤ 32、禁止 `\ / : * ? " < > |`。

---

## 6. 实现对应

核心状态机在 `MountOperations.renameDevice`：

```
输入: device, newName
输出: 成功文案 | 分类错误码

newVolumePath = /Volumes/trimmedName
parentDisk    = devicePath 去掉 sN

unmount(devicePath)
writeLabel(ntfslabel)              → 失败记入 labelError，不立即抛出
if 无 labelError:
    unmountDisk(parentDisk)
    gpt label (best-effort)
remount:
    只读 ? mountDisk(parent) : mountDevice(volume=newVolumePath)
removeStaleMountPoint(旧 volume)
if labelError: 抛 RENAME_LABEL_FAILED
```

辅助函数职责：

| 函数 | 作用层 | 失败策略 |
|------|--------|----------|
| `ntfslabel` | L1 | 硬失败 |
| `tryRefreshDiskName` | L3 + L2 | 软失败 |
| `mountDevice(..., volume: 新路径)` | L4 | 硬失败 |
| `removeStaleMountPoint` | L4 残留 | 软失败 |
| `deviceDetector.invalidateCache` | 应用缓存 | 必须执行 |

错误码保持分类，便于界面区分“卷不可用 / 名称非法 / 缺工具 / 卸载失败 / 卷标失败需 chkdsk / 重挂失败”。

---

## 7. 验证

### 7.1 判定标准

一次重命名在**不推出**的前提下视为收敛，当且仅当：

1. Finder 显示新名；
2. 本应用设备列表显示新名；
3. `mount` 中该设备路径对应 `/Volumes/新名`；
4. GPT 盘上 `diskutil list` 的 `NAME` 为新名，或明确记录为 L2 软失败。

### 7.2 实测结果

在 GPT 分区的 SanDisk 设备上，按第 5 节流程执行后，上述 1–3 立即成立，无需推出再接入。这与“L3 失效 + L4 改路径”的因果解释一致。

L2 在部分环境仍可能短暂滞后：`diskutil list` 读分区表，刷新时机与 DiskArbitration 不完全相同。此时应用仍应显示新名，因为它已经改读 L4。

### 7.3 反例（第一版）

仅写 L1 并挂回旧路径时，1 成立、2 与 3 失败，4 在 GPT 盘上失败。该反例排除了“只是 UI 没刷新”这一假说。

---

## 8. 讨论

### 8.1 为何不把 Finder 显示名当作源

Finder 名可以不落盘。若应用跟随 L5，下次在 Windows 上插入同一设备时，卷标仍是旧的。产品语义应是“改 NTFS 卷标”，不是“改当前 Mac 的桌面别名”。

### 8.2 为何不调用 `diskutil rename`

`diskutil rename` 面向 APFS / HFS+ 等 macOS 本地卷。对 NTFS 它既不保证写 L1，也不能在 GPT 盘上稳定改 `PARTNAME`。跨文件系统的可携带写入仍以 `ntfslabel` 为准。

### 8.3 整盘卸载的副作用

`unmountDisk force` 会卸下同一物理盘上的其他分区（例如 EFI）。重挂时只读路径优先 `mountDisk` 父盘，正是为了把这些分区一并拉回。对单数据分区 U 盘，该成本可接受；对多数据分区磁盘，需要后续按分区分别恢复挂载模式。

### 8.4 残留风险

- 脏 NTFS 导致 `ntfslabel` 失败，需在 Windows 上 `chkdsk`。
- 新名与已有 `/Volumes` 目录冲突时，系统可能挂到 `/Volumes/新名 1`，应用会显示带后缀的名字。
- `gpt label` 失败时，`diskutil list` 可能仍旧；应用侧因 L4 已更新而不受影响。

---

## 9. 结论

macOS 上 NTFS 重命名的不同步，不是单一 API 失效，而是五层名称身份缺少共同事务。桌面显示名可以单独超前；`diskutil` 在 GPT 盘上读分区名并受 DiskArbitration 缓存约束；本应用对已挂载设备读的是 `/Volumes` 路径。

第一版只更新了 NTFS 卷标，却把设备挂回旧路径，因此必然出现“桌面已改、软件与 diskutil 未改，直到推出”。充分条件是：写入卷标、整盘卸载以失效缓存、尽力同步 GPT 名、把挂载点改到新路径。物理推出不是重命名的必要步骤，只是上述失效过程的一种粗粒度实现。

---

## 附录 A 数据流

```
用户输入新名
    │
    ▼
renameDevice
    │
    ├─ ntfslabel              → L1 NTFS 卷标
    ├─ unmountDisk force      → 失效 L3 DiskArbitration
    ├─ gpt label（尽力）       → L2 GPT PARTNAME
    ├─ 挂到 /Volumes/新名      → L4 挂载路径
    │     ├─ 只读: mountDisk / mount
    │     └─ 读写: ntfs-3g -ovolname=新名
    └─ invalidateCache        → 应用重读 L4
           │
           ▼
     Finder / 应用 / diskutil 收敛
```

## 附录 B 相关代码

| 位置 | 职责 |
|------|------|
| `src/scripts/ntfs-manager/mount-operations.ts` | 重命名状态机、GPT 刷新、旧挂载点清理 |
| `src/scripts/ntfs-manager.ts` | 重命名成功后使检测缓存失效 |
| `src/scripts/ntfs-manager/device-detector.ts` | 已挂载设备从 `/Volumes` 派生 `volumeName` |
| `src/scripts/modules/devices/device-operations.ts` | 界面侧重命名入口与错误映射 |
| `src/scripts/ipc-handlers.ts` | `rename-device` IPC 与列表广播 |

## 附录 C 术语

| 术语 | 含义 |
|------|------|
| 卷标 / volume label | NTFS 文件系统内部的卷名（L1） |
| 分区名 / PARTNAME | GPT 分区表项名称（L2） |
| 显示名 | Finder 桌面所见名称（L5） |
| 挂载路径 | `/Volumes/` 下的目录名（L4） |
| 名称收敛 | 各读取源在一次操作后指向同一用户可见名 |

