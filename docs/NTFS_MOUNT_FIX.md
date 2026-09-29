# NTFS 用户映射修复：实现、验证和回滚

## 交付状态

源码已修改，TypeScript 与 Stylus 编译通过，39 项自动测试通过（36 项隔离的状态/流程测试 + 3 项本机临时目录文件操作测试）。2026-09-29 已将本地修复构建安装至 `/Applications/Nigate.app`，完成真实 GUI 启动、依赖页面和设备只读状态识别检查。新版 GUI 的实盘读写挂载及应用保存回归尚未进行，不能以此前手动挂载实验替代。源码修复基于 `9b3bef34603c13c1dc263104ea4eff87bddd46e7`；提交前再次确认 39 项自动测试、TypeScript/Stylus 编译、Shell 语法和差异空白检查全部通过。

**当前“数据”卷为已验证的系统只读挂载，新版 Nigate 已在启动检查后正常退出。** 启动检查临时关闭自动挂载，退出后已按原始文件字节恢复设置（自动挂载、托盘模式、开机启动仍开启）。此前源码阶段发生过一次测试隔离缺陷，详情见本文“测试隔离事件”。此前 B 组的可写挂载已不再保持，不能继续引用旧报告里的“当前可写”状态。

## 根因与已完成的真实实验

原 GUI 直接运行 ntfs-3g，没有设置日常用户 uid/gid。手动 A/B 对照只改变这一组参数：不映射时文件呈现为 root 所有，内容写入可行，但保留元数据的 Cocoa 保存报 EACCES；映射为实验用户后，Cocoa 探针由 5/11 变为 10/11，TextEdit 两次普通保存、VS Code 保存及 Finder 复制/重命名通过。两组 12 项基础文件操作均通过，证明问题不等于“NTFS-3G 不支持原地写入”。

完整原始证据在工作区 `diagnostics/remount-20260929-003032-688c9b/comparison-with-gui.json`。TextEdit 保存采用替换方式；真正的 in-place 能力由独立 seek/write/truncate/append 探针验证。

## 修改内容

| 文件 | 原因与行为 |
|---|---|
| `src/scripts/ntfs-manager/mount-policy.ts` | 每次挂载前读取进程真实 UID/GID，核对有效身份；拒绝 root/提权 GUI、不可用身份及不安全参数，不读取 SUDO_UID 或固定 501/20 |
| `src/scripts/ntfs-manager/mount-state.ts` | 使用完整设备名、UUID、物理分区 Size、挂载点及真实可写标志；通过 diskutil/plutil 和 mount 读取状态，要求连续两次一致；不比较随挂载变化的 TotalSize |
| `src/scripts/ntfs-manager/write-verifier.ts` | 以普通用户在独立临时目录中校验创建、重新打开、偏移覆盖、截断、追加、fsync、内容/inode、元数据时间修改、重命名和删除；只清理自身文件 |
| `src/scripts/ntfs-manager/mount-operations.ts` | 在实际 GUI 调用处接入参数与验证；普通卸载、同设备操作互斥、挂载点非空/符号链接拒绝、成功后才记状态；失败时尝试并验证只读恢复；超时不再谎称已取消 |
| `src/scripts/ntfs-manager/device-detector.ts`、`utils.ts` | 完整解析含空格/括号的路径；旧标记不得覆盖实际只读状态；df 使用 argv，避免路径被 shell 解释 |
| `ninja/nigate.sh` | 独立 CLI 的三个执行分支共用动态 uid/gid、安全参数数组和路径引用；拒绝 root 启动，使用普通卸载。CLI 尚未合并为 GUI 服务，也未进行新一轮实盘验收 |
| `package.json`、`tests/` | 增加自动测试；流程测试从 Node 权限层禁止所有子进程，显式注入命令替身，并使用不存在的设备编号 |
| `README.md`、`README.ja.md` | 删除未经证实的“缺少内核写权限所以不能原地修改”断言，区分手动实验证据与新版 GUI 待验收项 |

已有自动挂载和手动只读列表的设置/renderer 分支未改。新增互斥阻止同一服务同时操作同一设备，但跨用户、跨进程的并发挂载没有经过实测。显式“重置/修复”动作仍保留原有 ntfsfix 功能，现在先确认正常卸载；普通挂载和失败恢复不会自动调用它。

新的 GUI 默认参数为：

```text
ntfs-3g -olocal -oallow_other -oauto_xattr -ovolname=<卷名>
        -onoatime -onorecover -ouid=<启动用户UID> -ogid=<启动用户GID>
        <设备节点> <挂载点>
```

不设置新的 umask/fmask/dmask，不改变原有 allow_other 策略。默认移除 remove_hiberfile，并显式使用 norecover。遇到休眠、脏卷或不安全状态由驱动拒绝，给出 Windows 完全关机提示；默认不自动删除休眠文件、清理 Windows 日志或运行修复。驱动挂载后的文件归属仍需自检通过，不能仅凭传入 uid/gid 假定生效。

如果驱动明确报告 Windows 休眠、快速启动或脏卷状态，GUI 会显示警告并提供两个选择：

- **保留并只读**：保留 Windows 的恢复状态，停止读写挂载；这是默认按钮。
- **删除并继续读写**：只有用户明确选择后，才重试并传入 `remove_hiberfile`。这会删除 Windows 的休眠/快速启动恢复状态，使 Windows 无法从本次休眠现场恢复，但不会主动删除普通文档。该操作不可逆，也不是 Windows `chkdsk` 的替代品。

普通错误不会显示这个删除选项；取消或关闭警告不会运行 `ntfsfix`。设备容量显示使用二进制单位，在达到 1 TB、1 PB 等阈值后切换到对应单位，例如 `1.00 TB` 不再显示为 `1024.00 GB`。

## 构建与测试

本机使用 Node 26.10.0；测试命令需要支持 `--permission` 的 Node。依赖按现有 pnpm-lock.yaml 安装，没有升级或修改锁文件。

```bash
cd '/Volumes/128G PM981/NTFS-file/Free-NTFS-for-Mac'
pnpm install --frozen-lockfile --ignore-scripts
pnpm test
pnpm run build:stylus
bash -n ninja/nigate.sh
git diff --check
```

`pnpm test` 先编译 TypeScript。状态与服务测试禁止子进程，即使模拟失效也不能执行真实 sudo/diskutil/mount。由于 Node 权限模型同时禁用 fsync，文件操作测试独立运行，代码仅导入 fs/path 和写入验证模块，只操作 os.tmpdir 下新建的目录。两类测试都不能替代实盘挂载或 GUI 测试。新状态读取模块还在真实“数据”只读卷上完成了 UUID、分区容量、只读标志及连续两次稳定状态核验，没有执行写入探针。完整收尾记录在工作区 diagnostics/source-implementation-checks-20260929.json。

实机只读检查中，最初一次 3 秒预算的 diskutil 查询超时；随后的只读复测耗时约 0.14–0.18 秒，初次超时原因未确定。现将单次快照查询上限设为 10 秒，状态稳定窗口设为 30 秒，并向每次查询传递剩余预算，避免超时叠加；增加了对应自动测试。

源码阶段仅编译；后续安装阶段已使用锁定的 Electron 28.3.3 arm64 完成打包。下载包 SHA-256 与项目内校验表一致，使用 ditto 完整解压；修正 node-pty arm64 spawn-helper 的执行权限后，其预编译模块在 Electron 内及最终应用包内均通过真实启动探针，无需更换依赖版本。直接调用 electron-builder，未使用包含强制卸载逻辑的 ninja/build.sh。应用采用本机 ad-hoc 签名，保留 Hardened Runtime，codesign 深度严格验证通过；这不等于 Developer ID 公证发布。版本显示仍为 1.4.5，Info.plist 的 NigateLocalBuild 标识为 ntfs-user-mapping-20260929。安装证据见工作区 diagnostics/install-20260929-014317/INSTALLATION.md。

## 新版 GUI 待验收

| 项目 | 本轮证据 |
|---|---|
| 动态身份、安全 argv、身份/路径拒绝 | 自动测试通过，含两组不同 UID/GID |
| 状态延迟、错误卷、忙碌卸载、密码重试、超时、不误报成功 | 隔离流程/状态测试通过 |
| 恢复只读、普通卸载、推出、旧标记与空格路径 | 隔离测试通过；新增 GUI 实盘操作未执行 |
| 文件 seek/truncate/append/fsync 等 | 新验证器在本机临时目录通过；NTFS 上此前独立探针通过 |
| 新版 GUI 挂载后的 TextEdit、VS Code、Finder | 待执行；旧的手动 B 组实测通过不等于本项通过 |
| 自动读写、手动只读保护、托盘、睡眠唤醒 | 设置逻辑保留；新版 GUI 端到端回归待执行 |
| Word、多用户、多盘、Intel、其他 macOS | 未测试 |

TextEdit 永久版本历史与 RENAME_SWAP 的限制仍保留。现有 SudoExecutor 有 30 秒命令等待限制；服务移除了较短且不取消子进程的外层 Promise.race。超时仍不能证明特权子进程已经终止，因此不会立即自动重挂或声称取消成功。

## 测试隔离事件

早期测试误用了 Node child_process mock：execFile 的自定义 promisifier 保留真实函数，使正常 diskutil eject 命令触及 `/dev/disk8s3`，导致之前 B 组挂载被正常卸载。几次指向虚构挂载点的 mount 命令因目录不存在失败。模拟 sudo 与 ntfs-3g 路径没有执行真实命令，未在该卷执行新的写入探针。

发现后立即停止测试，核对 VolumeUUID、DiskUUID 与分区 Size；一致后执行系统只读恢复并核验 `/Volumes/数据`、WritableVolume=false 和 read-only 挂载标志。完整记录在工作区 `diagnostics/source-test-isolation-incident-20260929.json`。这不是业务文件内容完整性的全盘校验，不能据此作此类保证。

整改包含三层：显式注入系统命令执行函数、使用虚构设备号、从 Node 权限层拒绝所有子进程。独立隔离测试同时覆盖直接 spawn 和自定义 promisify 两条路径。最后通过的自动测试使用整改后的机制。

## 回滚

旧应用的完整副本位于 `/Volumes/128G PM981/NTFS-file/diagnostics/install-20260929-014317/backup/Nigate.app`，备份的 273 个文件/链接条目已核对。回滚应用时先从托盘菜单正常退出 Nigate，将 `/Applications/Nigate.app` 移至另一个保留目录，再将该备份复制回 `/Applications/Nigate.app`。原设置备份同在 backup 目录，安装检查结束已恢复，无需重复覆盖。当前磁盘状态为只读；应用或源码回滚不会自动改变挂载状态。不要启动旧版期待它继承新的挂载参数。

若要保留本次修改并取得原始源码，可从基线导出到新目录，不需要 reset/clean 当前仓库：

```bash
cd '/Volumes/128G PM981/NTFS-file/Free-NTFS-for-Mac'
mkdir '../Free-NTFS-baseline-9b3bef3' &&
  git archive 9b3bef34603c13c1dc263104ea4eff87bddd46e7 |
  tar -x -C '../Free-NTFS-baseline-9b3bef3'
```

以后安装测试构建时，应先保留旧应用副本；退出测试版后恢复旧副本即可回滚应用，磁盘仍应通过正常卸载/只读恢复独立处理。
