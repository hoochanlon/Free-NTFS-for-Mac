# Nigate 1.6.1

Compared with [v1.5.4](https://github.com/hoochanlon/Free-NTFS-for-Mac/releases/tag/v1.5.4).

- Native Swift / SwiftUI app (macOS 14+). Electron and Ninja Tools are gone.
- Always stays in the menu bar. Closing the window hides it; quit from the title bar or the menu-bar icon.
- Automatic read-write is always on. Inserted or scanned read-only NTFS volumes are remounted RW. Volumes you restore to read-only stay RO for that connection.
- Dual mount backend: MacFUSE + `ntfs-3g` by default; optional FSKit on macOS 15.4+ (Settings → Mount Backend). No silent fallback.
- Sleep prevention default is Smart (cyan). Cycle: Off → Prevent Sleep (brown) → Smart → Off.
- Status protection only locks remaining settings (e.g. sleep). It does not turn off auto-RW.
- Device actions: mount, restore RO, unmount, eject, repair, rename, reset, format (external whole disk only). Redundant mount / restore buttons are hidden.
- In-app help with search. Hover hints off by default.

---

# Nigate 1.6.1

相对 [v1.5.4](https://github.com/hoochanlon/Free-NTFS-for-Mac/releases/tag/v1.5.4)。

- 原生 Swift / SwiftUI 应用（macOS 14+）。Electron 与 Ninja Tools 已移除。
- 始终驻留菜单栏。关闭窗口只是隐藏；从标题栏或菜单栏图标退出。
- 自动读写始终开启。插入或扫描后，只读 NTFS 会改挂为读写。手动还原为只读的卷，本次连接保持只读。
- 双挂载后端：默认 MacFUSE + `ntfs-3g`；macOS 15.4+ 可在设置中选用 FSKit。失败不会静默降级。
- 防止休眠默认为智能（青色）。循环：关闭 → 防止休眠（棕色）→ 智能 → 关闭。
- 状态保护只锁定其余设置（如防止休眠），不会关闭自动读写。
- 设备操作：挂载、还原只读、卸载、推出、修复、重命名、重置、格式化（仅外置整盘）。已读写隐藏挂载，已只读隐藏还原。
- 应用内帮助支持搜索。悬停提示默认关闭。
