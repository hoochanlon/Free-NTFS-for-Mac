#!/bin/bash
# ============================================================
# kamui.sh 多语言支持文件
# ============================================================

# 检测系统语言
detect_language() {
	# 优先使用环境变量 LANG
	if [ -n "$LANG" ]; then
		case "$LANG" in
			*zh*|*CN*|*TW*)
				echo "zh"
				;;
			*ja*|*JP*)
				echo "ja"
				;;
			*)
				echo "en"
				;;
		esac
	# 如果没有设置，检测系统默认语言
	elif [ -n "$LC_ALL" ]; then
		case "$LC_ALL" in
			*zh*|*CN*|*TW*)
				echo "zh"
				;;
			*ja*|*JP*)
				echo "ja"
				;;
			*)
				echo "en"
				;;
		esac
	else
		# 检测系统语言设置
		sys_lang=$(defaults read -g AppleLanguages 2>/dev/null | head -1 | sed 's/[",]//g' | cut -d'_' -f1)
		case "$sys_lang" in
			zh)
				echo "zh"
				;;
			ja)
				echo "ja"
				;;
			*)
				echo "en"
				;;
		esac
	fi
}

# 设置语言
SCRIPT_LANG=$(detect_language)

# 翻译函数
t() {
	local key=$1
	case "$SCRIPT_LANG" in
		zh)
			case "$key" in
				# 脚本标题和基本信息
				script_title) echo "Free NTFS for Mac - Linux 文件系统挂载脚本" ;;
				script_description) echo "使用 anylinuxfs 工具自动检测并挂载 Linux 支持的文件系统到 macOS" ;;

				# 文件系统类型
				fs_linux) echo "Linux 文件系统：ext2, ext3, ext4, btrfs, xfs, zfs" ;;
				fs_microsoft) echo "Microsoft 文件系统：NTFS, exFAT" ;;
				fs_encrypted) echo "加密卷：LUKS (crypto_LUKS), BitLocker" ;;
				fs_lvm) echo "逻辑卷：LVM (LVM2_member)" ;;
				fs_raid) echo "RAID：Linux RAID (linux_raid_member, mdadm)" ;;
				fs_multidisk) echo "多磁盘 btrfs (JBOD, RAID1等)" ;;

				# 工作流程
				workflow_step1) echo "检查并安装 Homebrew（如果未安装）" ;;
				workflow_step2) echo "检查并安装 MacFUSE 和 ntfs-3g-mac（运行时依赖）" ;;
				workflow_step3) echo "检查并安装 anylinuxfs 工具" ;;
				workflow_step4) echo "自动检测 Linux 文件系统分区" ;;
				workflow_step5) echo "使用 anylinuxfs 挂载分区" ;;
				workflow_step6) echo "修复权限并打开 Finder" ;;

				# 使用方法
				usage_mount) echo "挂载设备：" ;;
				usage_list) echo "列出可用设备：" ;;
				usage_status) echo "查看挂载状态：" ;;
				usage_unmount) echo "卸载设备：" ;;

				# 检查消息
				checking_homebrew) echo "检查 Homebrew..." ;;
				checking_macfuse) echo "检查 MacFUSE..." ;;
				checking_ntfs3g) echo "检查 ntfs-3g-mac..." ;;
				checking_anylinuxfs) echo "检查 anylinuxfs..." ;;

				# 安装消息
				installing_homebrew) echo "正在安装 Homebrew..." ;;
				installing_macfuse) echo "正在安装 MacFUSE..." ;;
				installing_ntfs3g) echo "正在安装 ntfs-3g-mac..." ;;
				installing_anylinuxfs) echo "正在安装 anylinuxfs..." ;;

				# 成功消息
				homebrew_installed) echo "✅ Homebrew 已安装" ;;
				macfuse_installed) echo "✅ MacFUSE 已安装" ;;
				ntfs3g_installed) echo "✅ ntfs-3g 已安装" ;;
				anylinuxfs_installed) echo "✅ anylinuxfs 已安装" ;;

				# 错误消息
				error_homebrew_failed) echo "❌ 错误: Homebrew 安装失败" ;;
				error_macfuse_failed) echo "❌ 错误: MacFUSE 安装失败" ;;
				error_ntfs3g_failed) echo "❌ 错误: ntfs-3g-mac 安装失败" ;;
				error_ntfs3g_not_found) echo "❌ 错误: 无法找到 ntfs-3g，请确保已正确安装" ;;
				error_anylinuxfs_failed) echo "❌ 错误: anylinuxfs 安装失败" ;;
				error_anylinuxfs_not_found) echo "❌ 错误: 未找到 anylinuxfs" ;;
				error_tap_failed) echo "❌ 错误: 无法添加 anylinuxfs 仓库" ;;
				error_port_in_use) echo "❌ 错误: 端口 $2 已被 $3 占用" ;;
				error_no_devices) echo "❌ 错误：未发现支持的文件系统分区。" ;;
				error_device_not_found) echo "❌ 错误: 设备 $2 未找到" ;;
				error_mount_failed) echo "❌ 错误: 挂载失败" ;;
				error_unmount_failed) echo "❌ 错误: 无法卸载设备，可能正在被使用" ;;
				error_unmount_macos_failed) echo "❌ 错误: 无法卸载设备" ;;

				# 警告消息
				warning_anylinuxfs_running) echo "⚠️  anylinuxfs 正在运行，检测到已有设备挂载" ;;
				warning_device_mounted) echo "⚠️  设备 /dev/$2 已经通过 anylinuxfs 挂载" ;;
				warning_macos_readonly) echo "⚠️  设备 /dev/$2 已被 macOS 挂载为只读模式" ;;
				warning_limit) echo "注意：anylinuxfs 限制" ;;

				# 提示消息
				tip_port_stop) echo "请停止占用该端口的服务后重试" ;;
				tip_list_devices) echo "提示: 可以使用 'sudo anylinuxfs list' 查看 Linux 文件系统" ;;
				tip_list_ms_devices) echo "     可以使用 'sudo anylinuxfs list -m' 查看 Microsoft 文件系统（NTFS, exFAT）" ;;
				tip_list_all) echo "     可以使用 '$2 --list' 查看所有可用设备" ;;
				tip_check_apps) echo "提示: 请关闭所有使用该设备的应用程序后重试" ;;
				tip_anylinuxfs_log) echo "提示: 可以使用 'anylinuxfs log' 查看详细错误信息" ;;
				tip_ensure_connected) echo "  - 确保设备已正确连接并已插入" ;;
				tip_ntfs_auto) echo "  - NTFS 设备：anylinuxfs 支持直接挂载 NTFS 为读写模式" ;;
				tip_ntfs_auto_unmount) echo "  - 如果 NTFS 设备已被 macOS 挂载为只读，anylinuxfs 会自动卸载并重新挂载为读写模式" ;;

				# 限制说明
				limit_single_device) echo "  - anylinuxfs 同一时间只能挂载一个设备" ;;
				limit_unmount_first) echo "  - 如需挂载新设备，需要先卸载当前已挂载的设备" ;;

				# 操作消息
				detecting_partitions) echo "正在检测 Linux 文件系统分区..." ;;
				device_found) echo ">>> 发现设备: /dev/$2 (设备名称: $3)" ;;
				unmounting_current) echo "正在卸载当前设备..." ;;
				unmounting_macos) echo "正在卸载 macOS 的只读挂载..." ;;
				mounting) echo ">>> 正在执行挂载..." ;;
				unmounting) echo "正在卸载设备..." ;;
				opening_finder) echo "正在打开 Finder..." ;;

				# 成功操作
				device_unmounted) echo "✅ 当前设备已卸载" ;;
				macos_unmounted) echo "✅ macOS 只读挂载已卸载" ;;
				macos_unmounted_simple) echo "✅ macOS 挂载已卸载" ;;
				device_mounted) echo "✅ 设备已挂载: $2" ;;
				device_unmounted_success) echo "✅ 设备已成功卸载" ;;

				# 确认消息
				continue_mount_new) echo "是否卸载当前设备并挂载新设备？(y/N): " ;;
				unmount_macos_confirm) echo "是否继续卸载 macOS 挂载？(y/N): " ;;
				mount_cancelled) echo "挂载已取消" ;;
				operation_cancelled) echo "已取消" ;;

				# 设备列表
				available_linux_devices) echo "可用的 Linux 文件系统设备:" ;;
				available_ms_devices) echo "可用的 Microsoft 文件系统设备 (NTFS, exFAT):" ;;
				no_linux_devices) echo "  （无 Linux 文件系统设备）" ;;
				no_ms_devices) echo "  （无 Microsoft 文件系统设备）" ;;

				# NTFS 说明
				ntfs_mount_info) echo "NTFS 挂载说明：" ;;
				ntfs_default_driver) echo "  - anylinuxfs 默认使用 ntfs-3g 驱动（更好的兼容性）" ;;
				ntfs_high_performance) echo "  - 如需更高性能，可使用 ntfs3 驱动：$2 /dev/diskXsY -t ntfs3" ;;
				ntfs_ntfs3_limitation) echo "  - 注意：ntfs3 不支持 Windows 休眠或快速启动的磁盘" ;;

				# 注意事项
				note_admin_required) echo "  - 需要管理员权限（会提示输入密码）" ;;
				note_first_run) echo "  - 首次运行会安装依赖，可能需要一些时间" ;;
				note_ports) echo "  - 需要确保端口 2049, 32765, 32767 未被占用" ;;
				note_apple_silicon) echo "  - 仅支持 Apple Silicon Mac（M1/M2/M3等）" ;;

				# 默认
				*) echo "$key" ;;
			esac
			;;
		ja)
			case "$key" in
				# 脚本标题和基本信息
				script_title) echo "Free NTFS for Mac - Linux ファイルシステムマウントスクリプト" ;;
				script_description) echo "anylinuxfs ツールを使用して Linux 対応ファイルシステムを macOS に自動検出・マウント" ;;

				# 文件系统类型
				fs_linux) echo "Linux ファイルシステム：ext2, ext3, ext4, btrfs, xfs, zfs" ;;
				fs_microsoft) echo "Microsoft ファイルシステム：NTFS, exFAT" ;;
				fs_encrypted) echo "暗号化ボリューム：LUKS (crypto_LUKS), BitLocker" ;;
				fs_lvm) echo "論理ボリューム：LVM (LVM2_member)" ;;
				fs_raid) echo "RAID：Linux RAID (linux_raid_member, mdadm)" ;;
				fs_multidisk) echo "マルチディスク btrfs (JBOD, RAID1等)" ;;

				# 工作流程
				workflow_step1) echo "Homebrew の確認とインストール（未インストールの場合）" ;;
				workflow_step2) echo "MacFUSE と ntfs-3g-mac の確認とインストール（ランタイム依存関係）" ;;
				workflow_step3) echo "anylinuxfs ツールの確認とインストール" ;;
				workflow_step4) echo "Linux ファイルシステムパーティションの自動検出" ;;
				workflow_step5) echo "anylinuxfs を使用してパーティションをマウント" ;;
				workflow_step6) echo "権限の修正と Finder の起動" ;;

				# 使用方法
				usage_mount) echo "デバイスのマウント：" ;;
				usage_list) echo "利用可能なデバイスの一覧：" ;;
				usage_status) echo "マウント状態の確認：" ;;
				usage_unmount) echo "デバイスのアンマウント：" ;;

				# 检查消息
				checking_homebrew) echo "Homebrew を確認中..." ;;
				checking_macfuse) echo "MacFUSE を確認中..." ;;
				checking_ntfs3g) echo "ntfs-3g-mac を確認中..." ;;
				checking_anylinuxfs) echo "anylinuxfs を確認中..." ;;

				# 安装消息
				installing_homebrew) echo "Homebrew をインストール中..." ;;
				installing_macfuse) echo "MacFUSE をインストール中..." ;;
				installing_ntfs3g) echo "ntfs-3g-mac をインストール中..." ;;
				installing_anylinuxfs) echo "anylinuxfs をインストール中..." ;;

				# 成功消息
				homebrew_installed) echo "✅ Homebrew がインストールされています" ;;
				macfuse_installed) echo "✅ MacFUSE がインストールされています" ;;
				ntfs3g_installed) echo "✅ ntfs-3g がインストールされています" ;;
				anylinuxfs_installed) echo "✅ anylinuxfs がインストールされています" ;;

				# 错误消息
				error_homebrew_failed) echo "❌ エラー: Homebrew のインストールに失敗しました" ;;
				error_macfuse_failed) echo "❌ エラー: MacFUSE のインストールに失敗しました" ;;
				error_ntfs3g_failed) echo "❌ エラー: ntfs-3g-mac のインストールに失敗しました" ;;
				error_ntfs3g_not_found) echo "❌ エラー: ntfs-3g が見つかりません。正しくインストールされていることを確認してください" ;;
				error_anylinuxfs_failed) echo "❌ エラー: anylinuxfs のインストールに失敗しました" ;;
				error_anylinuxfs_not_found) echo "❌ エラー: anylinuxfs が見つかりません" ;;
				error_tap_failed) echo "❌ エラー: anylinuxfs リポジトリを追加できませんでした" ;;
				error_port_in_use) echo "❌ エラー: ポート $2 は $3 によって使用されています" ;;
				error_no_devices) echo "❌ エラー：サポートされているファイルシステムパーティションが見つかりませんでした。" ;;
				error_device_not_found) echo "❌ エラー: デバイス $2 が見つかりません" ;;
				error_mount_failed) echo "❌ エラー: マウントに失敗しました" ;;
				error_unmount_failed) echo "❌ エラー: デバイスをアンマウントできません。使用中の可能性があります" ;;
				error_unmount_macos_failed) echo "❌ エラー: デバイスをアンマウントできません" ;;

				# 警告消息
				warning_anylinuxfs_running) echo "⚠️  anylinuxfs が実行中です。デバイスがマウントされていることが検出されました" ;;
				warning_device_mounted) echo "⚠️  デバイス /dev/$2 は既に anylinuxfs によってマウントされています" ;;
				warning_macos_readonly) echo "⚠️  デバイス /dev/$2 は macOS によって読み取り専用モードでマウントされています" ;;
				warning_limit) echo "注意：anylinuxfs の制限" ;;

				# 提示消息
				tip_port_stop) echo "ポートを使用しているサービスを停止してから再試行してください" ;;
				tip_list_devices) echo "ヒント: 'sudo anylinuxfs list' を使用して Linux ファイルシステムを確認できます" ;;
				tip_list_ms_devices) echo "     'sudo anylinuxfs list -m' を使用して Microsoft ファイルシステム（NTFS, exFAT）を確認できます" ;;
				tip_list_all) echo "     '$2 --list' を使用してすべての利用可能なデバイスを確認できます" ;;
				tip_check_apps) echo "ヒント: デバイスを使用しているすべてのアプリケーションを閉じてから再試行してください" ;;
				tip_anylinuxfs_log) echo "ヒント: 'anylinuxfs log' を使用して詳細なエラー情報を確認できます" ;;
				tip_ensure_connected) echo "  - デバイスが正しく接続され、挿入されていることを確認してください" ;;
				tip_ntfs_auto) echo "  - NTFS デバイス：anylinuxfs は NTFS を直接読み書きモードでマウントできます" ;;
				tip_ntfs_auto_unmount) echo "  - NTFS デバイスが macOS によって読み取り専用でマウントされている場合、anylinuxfs は自動的にアンマウントして読み書きモードで再マウントします" ;;

				# 限制说明
				limit_single_device) echo "  - anylinuxfs は一度に1つのデバイスのみマウントできます" ;;
				limit_unmount_first) echo "  - 新しいデバイスをマウントするには、現在マウントされているデバイスを先にアンマウントする必要があります" ;;

				# 操作消息
				detecting_partitions) echo "Linux ファイルシステムパーティションを検出中..." ;;
				device_found) echo ">>> デバイスを検出: /dev/$2 (デバイス名: $3)" ;;
				unmounting_current) echo "現在のデバイスをアンマウント中..." ;;
				unmounting_macos) echo "macOS の読み取り専用マウントをアンマウント中..." ;;
				mounting) echo ">>> マウントを実行中..." ;;
				unmounting) echo "デバイスをアンマウント中..." ;;
				opening_finder) echo "Finder を開いています..." ;;

				# 成功操作
				device_unmounted) echo "✅ 現在のデバイスがアンマウントされました" ;;
				macos_unmounted) echo "✅ macOS 読み取り専用マウントがアンマウントされました" ;;
				macos_unmounted_simple) echo "✅ macOS マウントがアンマウントされました" ;;
				device_mounted) echo "✅ デバイスがマウントされました: $2" ;;
				device_unmounted_success) echo "✅ デバイスが正常にアンマウントされました" ;;

				# 确认消息
				continue_mount_new) echo "現在のデバイスをアンマウントして新しいデバイスをマウントしますか？(y/N): " ;;
				unmount_macos_confirm) echo "macOS マウントをアンマウントしますか？(y/N): " ;;
				mount_cancelled) echo "マウントがキャンセルされました" ;;
				operation_cancelled) echo "キャンセルされました" ;;

				# 设备列表
				available_linux_devices) echo "利用可能な Linux ファイルシステムデバイス:" ;;
				available_ms_devices) echo "利用可能な Microsoft ファイルシステムデバイス (NTFS, exFAT):" ;;
				no_linux_devices) echo "  （Linux ファイルシステムデバイスなし）" ;;
				no_ms_devices) echo "  （Microsoft ファイルシステムデバイスなし）" ;;

				# NTFS 说明
				ntfs_mount_info) echo "NTFS マウントの説明：" ;;
				ntfs_default_driver) echo "  - anylinuxfs はデフォルトで ntfs-3g ドライバを使用します（より良い互換性）" ;;
				ntfs_high_performance) echo "  - より高いパフォーマンスが必要な場合は、ntfs3 ドライバを使用できます：$2 /dev/diskXsY -t ntfs3" ;;
				ntfs_ntfs3_limitation) echo "  - 注意：ntfs3 は Windows の休止状態または高速スタートアップのディスクをサポートしていません" ;;

				# 注意事项
				note_admin_required) echo "  - 管理者権限が必要です（パスワードの入力が求められます）" ;;
				note_first_run) echo "  - 初回実行時は依存関係のインストールが必要で、時間がかかる場合があります" ;;
				note_ports) echo "  - ポート 2049, 32765, 32767 が使用されていないことを確認してください" ;;
				note_apple_silicon) echo "  - Apple Silicon Mac（M1/M2/M3等）のみサポート" ;;

				# 默认
				*) echo "$key" ;;
			esac
			;;
		en|*)
			case "$key" in
				# 脚本标题和基本信息
				script_title) echo "Free NTFS for Mac - Linux Filesystem Mount Script" ;;
				script_description) echo "Automatically detect and mount Linux-supported filesystems to macOS using anylinuxfs tool" ;;

				# 文件系统类型
				fs_linux) echo "Linux filesystems: ext2, ext3, ext4, btrfs, xfs, zfs" ;;
				fs_microsoft) echo "Microsoft filesystems: NTFS, exFAT" ;;
				fs_encrypted) echo "Encrypted volumes: LUKS (crypto_LUKS), BitLocker" ;;
				fs_lvm) echo "Logical volumes: LVM (LVM2_member)" ;;
				fs_raid) echo "RAID: Linux RAID (linux_raid_member, mdadm)" ;;
				fs_multidisk) echo "Multi-disk btrfs (JBOD, RAID1, etc.)" ;;

				# 工作流程
				workflow_step1) echo "Check and install Homebrew (if not installed)" ;;
				workflow_step2) echo "Check and install MacFUSE and ntfs-3g-mac (runtime dependencies)" ;;
				workflow_step3) echo "Check and install anylinuxfs tool" ;;
				workflow_step4) echo "Automatically detect Linux filesystem partitions" ;;
				workflow_step5) echo "Mount partitions using anylinuxfs" ;;
				workflow_step6) echo "Fix permissions and open Finder" ;;

				# 使用方法
				usage_mount) echo "Mount device:" ;;
				usage_list) echo "List available devices:" ;;
				usage_status) echo "View mount status:" ;;
				usage_unmount) echo "Unmount device:" ;;

				# 检查消息
				checking_homebrew) echo "Checking Homebrew..." ;;
				checking_macfuse) echo "Checking MacFUSE..." ;;
				checking_ntfs3g) echo "Checking ntfs-3g-mac..." ;;
				checking_anylinuxfs) echo "Checking anylinuxfs..." ;;

				# 安装消息
				installing_homebrew) echo "Installing Homebrew..." ;;
				installing_macfuse) echo "Installing MacFUSE..." ;;
				installing_ntfs3g) echo "Installing ntfs-3g-mac..." ;;
				installing_anylinuxfs) echo "Installing anylinuxfs..." ;;

				# 成功消息
				homebrew_installed) echo "✅ Homebrew is installed" ;;
				macfuse_installed) echo "✅ MacFUSE is installed" ;;
				ntfs3g_installed) echo "✅ ntfs-3g is installed" ;;
				anylinuxfs_installed) echo "✅ anylinuxfs is installed" ;;

				# 错误消息
				error_homebrew_failed) echo "❌ Error: Homebrew installation failed" ;;
				error_macfuse_failed) echo "❌ Error: MacFUSE installation failed" ;;
				error_ntfs3g_failed) echo "❌ Error: ntfs-3g-mac installation failed" ;;
				error_ntfs3g_not_found) echo "❌ Error: Cannot find ntfs-3g. Please ensure it is properly installed" ;;
				error_anylinuxfs_failed) echo "❌ Error: anylinuxfs installation failed" ;;
				error_anylinuxfs_not_found) echo "❌ Error: anylinuxfs not found" ;;
				error_tap_failed) echo "❌ Error: Failed to add anylinuxfs repository" ;;
				error_port_in_use) echo "❌ Error: Port $2 is in use by $3" ;;
				error_no_devices) echo "❌ Error: No supported filesystem partitions found." ;;
				error_device_not_found) echo "❌ Error: Device $2 not found" ;;
				error_mount_failed) echo "❌ Error: Mount failed" ;;
				error_unmount_failed) echo "❌ Error: Cannot unmount device, may be in use" ;;
				error_unmount_macos_failed) echo "❌ Error: Cannot unmount device" ;;

				# 警告消息
				warning_anylinuxfs_running) echo "⚠️  anylinuxfs is running, detected mounted device" ;;
				warning_device_mounted) echo "⚠️  Device /dev/$2 is already mounted via anylinuxfs" ;;
				warning_macos_readonly) echo "⚠️  Device /dev/$2 is mounted as read-only by macOS" ;;
				warning_limit) echo "Note: anylinuxfs limitations" ;;

				# 提示消息
				tip_port_stop) echo "Please stop the service using this port and try again" ;;
				tip_list_devices) echo "Tip: Use 'sudo anylinuxfs list' to view Linux filesystems" ;;
				tip_list_ms_devices) echo "     Use 'sudo anylinuxfs list -m' to view Microsoft filesystems (NTFS, exFAT)" ;;
				tip_list_all) echo "     Use '$2 --list' to view all available devices" ;;
				tip_check_apps) echo "Tip: Please close all applications using this device and try again" ;;
				tip_anylinuxfs_log) echo "Tip: Use 'anylinuxfs log' to view detailed error information" ;;
				tip_ensure_connected) echo "  - Ensure the device is properly connected and inserted" ;;
				tip_ntfs_auto) echo "  - NTFS devices: anylinuxfs can mount NTFS directly in read-write mode" ;;
				tip_ntfs_auto_unmount) echo "  - If NTFS device is mounted as read-only by macOS, anylinuxfs will automatically unmount and remount in read-write mode" ;;

				# 限制说明
				limit_single_device) echo "  - anylinuxfs can only mount one device at a time" ;;
				limit_unmount_first) echo "  - To mount a new device, you need to unmount the currently mounted device first" ;;

				# 操作消息
				detecting_partitions) echo "Detecting Linux filesystem partitions..." ;;
				device_found) echo ">>> Device found: /dev/$2 (Device name: $3)" ;;
				unmounting_current) echo "Unmounting current device..." ;;
				unmounting_macos) echo "Unmounting macOS read-only mount..." ;;
				mounting) echo ">>> Mounting..." ;;
				unmounting) echo "Unmounting device..." ;;
				opening_finder) echo "Opening Finder..." ;;

				# 成功操作
				device_unmounted) echo "✅ Current device unmounted" ;;
				macos_unmounted) echo "✅ macOS read-only mount unmounted" ;;
				macos_unmounted_simple) echo "✅ macOS mount unmounted" ;;
				device_mounted) echo "✅ Device mounted: $2" ;;
				device_unmounted_success) echo "✅ Device successfully unmounted" ;;

				# 确认消息
				continue_mount_new) echo "Unmount current device and mount new device? (y/N): " ;;
				unmount_macos_confirm) echo "Continue to unmount macOS mount? (y/N): " ;;
				mount_cancelled) echo "Mount cancelled" ;;
				operation_cancelled) echo "Cancelled" ;;

				# 设备列表
				available_linux_devices) echo "Available Linux filesystem devices:" ;;
				available_ms_devices) echo "Available Microsoft filesystem devices (NTFS, exFAT):" ;;
				no_linux_devices) echo "  (No Linux filesystem devices)" ;;
				no_ms_devices) echo "  (No Microsoft filesystem devices)" ;;

				# NTFS 说明
				ntfs_mount_info) echo "NTFS mount information:" ;;
				ntfs_default_driver) echo "  - anylinuxfs uses ntfs-3g driver by default (better compatibility)" ;;
				ntfs_high_performance) echo "  - For higher performance, use ntfs3 driver: $2 /dev/diskXsY -t ntfs3" ;;
				ntfs_ntfs3_limitation) echo "  - Note: ntfs3 does not support disks from Windows systems with hibernation or Fast Startup enabled" ;;

				# 注意事项
				note_admin_required) echo "  - Administrator privileges required (password will be prompted)" ;;
				note_first_run) echo "  - First run will install dependencies, may take some time" ;;
				note_ports) echo "  - Ensure ports 2049, 32765, 32767 are not in use" ;;
				note_apple_silicon) echo "  - Only supports Apple Silicon Mac (M1/M2/M3, etc.)" ;;

				# 默认
				*) echo "$key" ;;
			esac
			;;
	esac
}
