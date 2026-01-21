#!/bin/bash
# ============================================================
# dev.sh 多语言支持文件
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
				script_title) echo "Free NTFS for Mac - 一键运行脚本" ;;
				script_subtitle) echo "仅支持 macOS 系统" ;;
				script_description) echo "一键运行脚本 - 自动检测并安装所有必要的工具" ;;
				script_description_detail) echo "适用于 macOS 系统，完全没有 npm、pnpm、ts、styl 环境的用户" ;;

				# 步骤标题
				step_check_nodejs) echo "步骤 1/6: 检查 Node.js" ;;
				step_check_pnpm) echo "步骤 2/6: 检查 pnpm" ;;
				step_install_dependencies) echo "步骤 3/6: 安装项目依赖" ;;
				step_build_typescript) echo "步骤 4/6: 编译 TypeScript" ;;
				step_build_stylus) echo "步骤 5/6: 编译 Stylus" ;;
				step_start_app) echo "步骤 6/6: 启动应用" ;;
				step_complete) echo "完成" ;;

				# Node.js 相关
				nodejs_installed) echo "Node.js 已安装: $2" ;;
				nodejs_not_found) echo "未检测到 Node.js 或版本过低（需要 >= 16）" ;;
				nodejs_installing_homebrew) echo "使用 Homebrew 安装 Node.js..." ;;
				nodejs_homebrew_not_found) echo "未检测到 Homebrew" ;;
				nodejs_installing_homebrew_now) echo "正在安装 Homebrew..." ;;
				nodejs_installing) echo "使用 Homebrew 安装 Node.js..." ;;
				nodejs_install_failed) echo "Node.js 安装失败或版本不正确" ;;
				nodejs_install_success) echo "Node.js 安装成功: $2" ;;

				# pnpm 相关
				pnpm_installed) echo "pnpm 已安装: $2" ;;
				pnpm_not_found) echo "未检测到 pnpm，正在安装..." ;;
				pnpm_installing) echo "使用 npm 安装 pnpm..." ;;
				pnpm_npm_not_found) echo "未检测到 npm，请先安装 Node.js" ;;
				pnpm_install_failed) echo "pnpm 安装失败，请手动安装：" ;;
				pnpm_install_manual) echo "  npm install -g pnpm" ;;
				pnpm_install_success) echo "pnpm 安装成功: $2" ;;

				# Electron 相关
				electron_checking) echo "检查 Electron 安装..." ;;
				electron_installing) echo "Electron 安装异常，正在修复..." ;;
				electron_script_not_found) echo "找不到 Electron 安装脚本" ;;
				electron_reinstalling) echo "尝试重新安装 Electron..." ;;
				electron_reinstalling_force) echo "重新安装 Electron（允许构建脚本）..." ;;
				electron_reinstalling_normal) echo "强制安装失败，尝试普通安装..." ;;
				electron_script_found) echo "找到 Electron 安装脚本: $2" ;;
				electron_running_script) echo "运行 Electron 安装脚本（下载二进制文件）..." ;;
				electron_script_complete) echo "安装脚本执行完成（可能没有输出）" ;;
				electron_fix_success) echo "Electron 修复成功" ;;
				electron_fix_failed) echo "Electron 修复失败" ;;
				electron_install_normal) echo "Electron 安装正常" ;;
				electron_not_installed) echo "Electron 未安装，请先运行依赖安装" ;;
				electron_verifying) echo "最后验证 Electron..." ;;
				electron_verify_failed) echo "Electron 验证失败，尝试修复..." ;;
				electron_manual_fix) echo "建议手动运行修复脚本: ./ninja/fix-electron.sh" ;;
				electron_manual_fix_alt) echo "可以尝试手动运行: ./ninja/fix-electron.sh" ;;
				electron_manual_fix_simple) echo "请尝试手动修复：" ;;
				electron_clean_install) echo "或者清理后重新安装：" ;;
				electron_clean_commands) echo "  rm -rf node_modules" ;;
				electron_clean_commands2) echo "  pnpm install" ;;

				# 依赖安装相关
				dependencies_checking) echo "检测到已安装的依赖，检查是否需要更新..." ;;
				dependencies_installing) echo "安装项目依赖（这可能需要几分钟）..." ;;
				dependencies_install_failed) echo "依赖安装失败" ;;
				dependencies_installing_electron) echo "检测到 Electron 可能未正确安装，尝试运行安装脚本..." ;;
				dependencies_running_electron_script) echo "运行 Electron 安装脚本..." ;;
				dependencies_install_success) echo "依赖安装完成" ;;

				# TypeScript 编译相关
				typescript_scripts_empty) echo "scripts 目录为空，需要编译 TypeScript..." ;;
				typescript_compiling) echo "编译 TypeScript..." ;;
				typescript_compiled_exists) echo "检测到已编译的文件，跳过编译..." ;;
				typescript_compile_failed) echo "TypeScript 编译失败，尝试使用本地 TypeScript..." ;;
				typescript_compile_error) echo "TypeScript 编译失败" ;;
				typescript_main_not_found) echo "编译失败：找不到 scripts/main.js" ;;
				typescript_recompiling) echo "尝试重新编译..." ;;
				typescript_check_error) echo "TypeScript 编译失败，请检查错误信息" ;;
				typescript_compile_success) echo "TypeScript 编译完成" ;;

				# Stylus 编译相关
				stylus_css_not_found) echo "styles.css 不存在，需要编译 Stylus..." ;;
				stylus_compiling) echo "编译 Stylus..." ;;
				stylus_compiled_exists) echo "检测到 styles.css，跳过编译..." ;;
				stylus_compile_failed) echo "Stylus 编译失败，尝试使用本地 Stylus..." ;;
				stylus_compile_warning) echo "Stylus 编译失败，但继续执行..." ;;
				stylus_compile_success) echo "Stylus 编译完成" ;;
				stylus_css_missing) echo "styles.css 不存在，但继续执行..." ;;

				# 版本同步相关
				version_syncing) echo "同步版本号..." ;;
				version_sync_failed) echo "版本号同步失败，继续执行..." ;;
				version_sync_not_found) echo "ninja/sync-version.js 不存在，跳过版本同步" ;;

				# 应用启动相关
				app_all_ready) echo "所有准备工作完成！" ;;
				app_starting) echo "启动 Electron 应用..." ;;
				app_starting_dev) echo "启动 Electron 应用（开发模式，带热重载）..." ;;

				# 文件检查相关
				files_checking) echo "检查必要文件..." ;;
				files_not_found) echo "找不到文件: $2" ;;
				files_check_success) echo "必要文件检查完成" ;;

				# 错误消息
				error_macos_only) echo "此脚本仅支持 macOS 系统" ;;
				error_not_root_dir) echo "请在项目根目录运行此脚本" ;;

				# 完成提示
				complete_all_ready) echo "所有准备工作完成！" ;;
				complete_commands) echo "现在可以运行以下命令：" ;;
				complete_command_start) echo "  pnpm start        # 启动应用（生产模式）" ;;
				complete_command_dev) echo "  pnpm run dev     # 启动应用（开发模式，带热重载）" ;;

				# 默认
				*) echo "$key" ;;
			esac
			;;
		ja)
			case "$key" in
				# 脚本标题和基本信息
				script_title) echo "Free NTFS for Mac - ワンクリック実行スクリプト" ;;
				script_subtitle) echo "macOS システムのみサポート" ;;
				script_description) echo "ワンクリック実行スクリプト - 必要なツールを自動検出してインストール" ;;
				script_description_detail) echo "macOS システム用、npm、pnpm、ts、styl 環境が全くないユーザー向け" ;;

				# 步骤标题
				step_check_nodejs) echo "ステップ 1/6: Node.js の確認" ;;
				step_check_pnpm) echo "ステップ 2/6: pnpm の確認" ;;
				step_install_dependencies) echo "ステップ 3/6: プロジェクト依存関係のインストール" ;;
				step_build_typescript) echo "ステップ 4/6: TypeScript のコンパイル" ;;
				step_build_stylus) echo "ステップ 5/6: Stylus のコンパイル" ;;
				step_start_app) echo "ステップ 6/6: アプリケーションの起動" ;;
				step_complete) echo "完了" ;;

				# Node.js 相关
				nodejs_installed) echo "Node.js がインストールされています: $2" ;;
				nodejs_not_found) echo "Node.js が検出されないか、バージョンが低すぎます（>= 16 が必要）" ;;
				nodejs_installing_homebrew) echo "Homebrew を使用して Node.js をインストール中..." ;;
				nodejs_homebrew_not_found) echo "Homebrew が検出されません" ;;
				nodejs_installing_homebrew_now) echo "Homebrew をインストール中..." ;;
				nodejs_installing) echo "Homebrew を使用して Node.js をインストール中..." ;;
				nodejs_install_failed) echo "Node.js のインストールに失敗したか、バージョンが正しくありません" ;;
				nodejs_install_success) echo "Node.js のインストールが成功しました: $2" ;;

				# pnpm 相关
				pnpm_installed) echo "pnpm がインストールされています: $2" ;;
				pnpm_not_found) echo "pnpm が検出されません。インストール中..." ;;
				pnpm_installing) echo "npm を使用して pnpm をインストール中..." ;;
				pnpm_npm_not_found) echo "npm が検出されません。先に Node.js をインストールしてください" ;;
				pnpm_install_failed) echo "pnpm のインストールに失敗しました。手動でインストールしてください：" ;;
				pnpm_install_manual) echo "  npm install -g pnpm" ;;
				pnpm_install_success) echo "pnpm のインストールが成功しました: $2" ;;

				# Electron 相关
				electron_checking) echo "Electron のインストールを確認中..." ;;
				electron_installing) echo "Electron のインストールに異常があります。修復中..." ;;
				electron_script_not_found) echo "Electron インストールスクリプトが見つかりません" ;;
				electron_reinstalling) echo "Electron を再インストール中..." ;;
				electron_reinstalling_force) echo "Electron を再インストール中（ビルドスクリプトを許可）..." ;;
				electron_reinstalling_normal) echo "強制インストールに失敗しました。通常インストールを試行中..." ;;
				electron_script_found) echo "Electron インストールスクリプトが見つかりました: $2" ;;
				electron_running_script) echo "Electron インストールスクリプトを実行中（バイナリファイルをダウンロード）..." ;;
				electron_script_complete) echo "インストールスクリプトの実行が完了しました（出力がない場合があります）" ;;
				electron_fix_success) echo "Electron の修復が成功しました" ;;
				electron_fix_failed) echo "Electron の修復に失敗しました" ;;
				electron_install_normal) echo "Electron のインストールは正常です" ;;
				electron_not_installed) echo "Electron がインストールされていません。先に依存関係をインストールしてください" ;;
				electron_verifying) echo "Electron を最終確認中..." ;;
				electron_verify_failed) echo "Electron の確認に失敗しました。修復を試行中..." ;;
				electron_manual_fix) echo "手動で修復スクリプトを実行することをお勧めします: ./ninja/fix-electron.sh" ;;
				electron_manual_fix_alt) echo "手動で実行してみてください: ./ninja/fix-electron.sh" ;;
				electron_manual_fix_simple) echo "手動で修復を試みてください：" ;;
				electron_clean_install) echo "または、クリーンアップ後に再インストール：" ;;
				electron_clean_commands) echo "  rm -rf node_modules" ;;
				electron_clean_commands2) echo "  pnpm install" ;;

				# 依赖安装相关
				dependencies_checking) echo "インストール済みの依存関係が検出されました。更新が必要か確認中..." ;;
				dependencies_installing) echo "プロジェクト依存関係をインストール中（数分かかる場合があります）..." ;;
				dependencies_install_failed) echo "依存関係のインストールに失敗しました" ;;
				dependencies_installing_electron) echo "Electron が正しくインストールされていない可能性があります。インストールスクリプトを実行中..." ;;
				dependencies_running_electron_script) echo "Electron インストールスクリプトを実行中..." ;;
				dependencies_install_success) echo "依存関係のインストールが完了しました" ;;

				# TypeScript 编译相关
				typescript_scripts_empty) echo "scripts ディレクトリが空です。TypeScript をコンパイルする必要があります..." ;;
				typescript_compiling) echo "TypeScript をコンパイル中..." ;;
				typescript_compiled_exists) echo "コンパイル済みファイルが検出されました。コンパイルをスキップします..." ;;
				typescript_compile_failed) echo "TypeScript のコンパイルに失敗しました。ローカルの TypeScript を使用してみます..." ;;
				typescript_compile_error) echo "TypeScript のコンパイルに失敗しました" ;;
				typescript_main_not_found) echo "コンパイルに失敗しました：scripts/main.js が見つかりません" ;;
				typescript_recompiling) echo "再コンパイルを試行中..." ;;
				typescript_check_error) echo "TypeScript のコンパイルに失敗しました。エラー情報を確認してください" ;;
				typescript_compile_success) echo "TypeScript のコンパイルが完了しました" ;;

				# Stylus 编译相关
				stylus_css_not_found) echo "styles.css が存在しません。Stylus をコンパイルする必要があります..." ;;
				stylus_compiling) echo "Stylus をコンパイル中..." ;;
				stylus_compiled_exists) echo "styles.css が検出されました。コンパイルをスキップします..." ;;
				stylus_compile_failed) echo "Stylus のコンパイルに失敗しました。ローカルの Stylus を使用してみます..." ;;
				stylus_compile_warning) echo "Stylus のコンパイルに失敗しましたが、続行します..." ;;
				stylus_compile_success) echo "Stylus のコンパイルが完了しました" ;;
				stylus_css_missing) echo "styles.css が存在しませんが、続行します..." ;;

				# 版本同步相关
				version_syncing) echo "バージョン番号を同期中..." ;;
				version_sync_failed) echo "バージョン番号の同期に失敗しました。続行します..." ;;
				version_sync_not_found) echo "ninja/sync-version.js が存在しません。バージョン同期をスキップします" ;;

				# 应用启动相关
				app_all_ready) echo "すべての準備が完了しました！" ;;
				app_starting) echo "Electron アプリケーションを起動中..." ;;
				app_starting_dev) echo "Electron アプリケーションを起動中（開発モード、ホットリロード付き）..." ;;

				# 文件检查相关
				files_checking) echo "必要なファイルを確認中..." ;;
				files_not_found) echo "ファイルが見つかりません: $2" ;;
				files_check_success) echo "必要なファイルの確認が完了しました" ;;

				# 错误消息
				error_macos_only) echo "このスクリプトは macOS システムのみサポートしています" ;;
				error_not_root_dir) echo "プロジェクトルートディレクトリでこのスクリプトを実行してください" ;;

				# 完成提示
				complete_all_ready) echo "すべての準備が完了しました！" ;;
				complete_commands) echo "次のコマンドを実行できます：" ;;
				complete_command_start) echo "  pnpm start        # アプリケーションを起動（本番モード）" ;;
				complete_command_dev) echo "  pnpm run dev     # アプリケーションを起動（開発モード、ホットリロード付き）" ;;

				# 默认
				*) echo "$key" ;;
			esac
			;;
		en|*)
			case "$key" in
				# 脚本标题和基本信息
				script_title) echo "Free NTFS for Mac - One-Click Run Script" ;;
				script_subtitle) echo "macOS Only" ;;
				script_description) echo "One-click run script - Automatically detect and install all necessary tools" ;;
				script_description_detail) echo "For macOS systems, users with no npm, pnpm, ts, styl environment at all" ;;

				# 步骤标题
				step_check_nodejs) echo "Step 1/6: Check Node.js" ;;
				step_check_pnpm) echo "Step 2/6: Check pnpm" ;;
				step_install_dependencies) echo "Step 3/6: Install project dependencies" ;;
				step_build_typescript) echo "Step 4/6: Compile TypeScript" ;;
				step_build_stylus) echo "Step 5/6: Compile Stylus" ;;
				step_start_app) echo "Step 6/6: Start application" ;;
				step_complete) echo "Complete" ;;

				# Node.js 相关
				nodejs_installed) echo "Node.js installed: $2" ;;
				nodejs_not_found) echo "Node.js not detected or version too low (requires >= 16)" ;;
				nodejs_installing_homebrew) echo "Installing Node.js using Homebrew..." ;;
				nodejs_homebrew_not_found) echo "Homebrew not detected" ;;
				nodejs_installing_homebrew_now) echo "Installing Homebrew..." ;;
				nodejs_installing) echo "Installing Node.js using Homebrew..." ;;
				nodejs_install_failed) echo "Node.js installation failed or version incorrect" ;;
				nodejs_install_success) echo "Node.js installed successfully: $2" ;;

				# pnpm 相关
				pnpm_installed) echo "pnpm installed: $2" ;;
				pnpm_not_found) echo "pnpm not detected, installing..." ;;
				pnpm_installing) echo "Installing pnpm using npm..." ;;
				pnpm_npm_not_found) echo "npm not detected, please install Node.js first" ;;
				pnpm_install_failed) echo "pnpm installation failed, please install manually:" ;;
				pnpm_install_manual) echo "  npm install -g pnpm" ;;
				pnpm_install_success) echo "pnpm installed successfully: $2" ;;

				# Electron 相关
				electron_checking) echo "Checking Electron installation..." ;;
				electron_installing) echo "Electron installation abnormal, fixing..." ;;
				electron_script_not_found) echo "Electron installation script not found" ;;
				electron_reinstalling) echo "Trying to reinstall Electron..." ;;
				electron_reinstalling_force) echo "Reinstalling Electron (allowing build scripts)..." ;;
				electron_reinstalling_normal) echo "Force installation failed, trying normal installation..." ;;
				electron_script_found) echo "Found Electron installation script: $2" ;;
				electron_running_script) echo "Running Electron installation script (downloading binaries)..." ;;
				electron_script_complete) echo "Installation script execution completed (may have no output)" ;;
				electron_fix_success) echo "Electron fixed successfully" ;;
				electron_fix_failed) echo "Electron fix failed" ;;
				electron_install_normal) echo "Electron installation is normal" ;;
				electron_not_installed) echo "Electron not installed, please run dependency installation first" ;;
				electron_verifying) echo "Final verification of Electron..." ;;
				electron_verify_failed) echo "Electron verification failed, trying to fix..." ;;
				electron_manual_fix) echo "Suggest manually running fix script: ./ninja/fix-electron.sh" ;;
				electron_manual_fix_alt) echo "You can try manually running: ./ninja/fix-electron.sh" ;;
				electron_manual_fix_simple) echo "Please try manual fix:" ;;
				electron_clean_install) echo "Or clean and reinstall:" ;;
				electron_clean_commands) echo "  rm -rf node_modules" ;;
				electron_clean_commands2) echo "  pnpm install" ;;

				# 依赖安装相关
				dependencies_checking) echo "Detected installed dependencies, checking if update needed..." ;;
				dependencies_installing) echo "Installing project dependencies (this may take a few minutes)..." ;;
				dependencies_install_failed) echo "Dependency installation failed" ;;
				dependencies_installing_electron) echo "Detected Electron may not be installed correctly, trying to run installation script..." ;;
				dependencies_running_electron_script) echo "Running Electron installation script..." ;;
				dependencies_install_success) echo "Dependency installation completed" ;;

				# TypeScript 编译相关
				typescript_scripts_empty) echo "scripts directory is empty, need to compile TypeScript..." ;;
				typescript_compiling) echo "Compiling TypeScript..." ;;
				typescript_compiled_exists) echo "Detected compiled files, skipping compilation..." ;;
				typescript_compile_failed) echo "TypeScript compilation failed, trying to use local TypeScript..." ;;
				typescript_compile_error) echo "TypeScript compilation failed" ;;
				typescript_main_not_found) echo "Compilation failed: scripts/main.js not found" ;;
				typescript_recompiling) echo "Trying to recompile..." ;;
				typescript_check_error) echo "TypeScript compilation failed, please check error messages" ;;
				typescript_compile_success) echo "TypeScript compilation completed" ;;

				# Stylus 编译相关
				stylus_css_not_found) echo "styles.css does not exist, need to compile Stylus..." ;;
				stylus_compiling) echo "Compiling Stylus..." ;;
				stylus_compiled_exists) echo "Detected styles.css, skipping compilation..." ;;
				stylus_compile_failed) echo "Stylus compilation failed, trying to use local Stylus..." ;;
				stylus_compile_warning) echo "Stylus compilation failed, but continuing..." ;;
				stylus_compile_success) echo "Stylus compilation completed" ;;
				stylus_css_missing) echo "styles.css does not exist, but continuing..." ;;

				# 版本同步相关
				version_syncing) echo "Syncing version number..." ;;
				version_sync_failed) echo "Version sync failed, continuing..." ;;
				version_sync_not_found) echo "ninja/sync-version.js does not exist, skipping version sync" ;;

				# 应用启动相关
				app_all_ready) echo "All preparations complete!" ;;
				app_starting) echo "Starting Electron application..." ;;
				app_starting_dev) echo "Starting Electron application (development mode with hot reload)..." ;;

				# 文件检查相关
				files_checking) echo "Checking required files..." ;;
				files_not_found) echo "File not found: $2" ;;
				files_check_success) echo "Required files check completed" ;;

				# 错误消息
				error_macos_only) echo "This script only supports macOS systems" ;;
				error_not_root_dir) echo "Please run this script from the project root directory" ;;

				# 完成提示
				complete_all_ready) echo "All preparations complete!" ;;
				complete_commands) echo "You can now run the following commands:" ;;
				complete_command_start) echo "  pnpm start        # Start application (production mode)" ;;
				complete_command_dev) echo "  pnpm run dev     # Start application (development mode with hot reload)" ;;

				# 默认
				*) echo "$key" ;;
			esac
			;;
	esac
}
