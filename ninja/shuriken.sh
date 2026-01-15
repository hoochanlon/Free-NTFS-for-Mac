#!/bin/bash

################################################################################
# Shuriken - macOS 系统权限与安全性设置工具
#
# 功能说明：
#   提供便捷的选项来配置 macOS 系统权限设置，包括：
#   - 禁用 Gatekeeper（允许任何来源的应用）
#   - 解锁拖拽安装的应用程序
#   - 检查 SIP 和 Gatekeeper 状态
#   - SIP 禁用说明（需在恢复模式下操作）
# 重要说明：
#   - Gatekeeper: 通过 spctl --master-disable 禁用（可在正常模式下操作）
#   - SIP (System Integrity Protection): 需在恢复模式下使用 csrutil disable
#
# 使用方法：
#   chmod +x shuriken.sh && ./shuriken.sh
#   或直接运行: bash shuriken.sh
################################################################################

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 检查是否为 macOS
check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "此脚本仅适用于 macOS 系统"
        exit 1
    fi
}

# 检查管理员权限
check_admin() {
    if [[ $EUID -ne 0 ]]; then
        return 1
    fi
    return 0
}

# 选项 1: 禁用 Gatekeeper（允许任何来源）
disable_gatekeeper() {
    print_info "准备禁用 Gatekeeper（允许任何来源的应用）..."
    print_warning "此操作需要管理员权限"
    echo ""
    print_info "说明：Gatekeeper 是 macOS 的安全功能，用于限制未签名应用的运行。"
    print_info "禁用后，您可以在「系统设置」>「隐私与安全性」中看到「任何来源」选项。"
    echo ""

    if check_admin; then
        print_info "正在执行: sudo spctl --master-disable"
        output=$(spctl --master-disable 2>&1)
        exit_code=$?

        # spctl --master-disable 成功时会输出提示信息，即使退出码可能非零
        if echo "$output" | grep -qi "assessment system\|Globally disabling" || [ $exit_code -eq 0 ]; then
            print_success "Gatekeeper 已禁用"
            if echo "$output" | grep -qi "System Settings"; then
                print_info "提示：需要在「系统设置」>「隐私与安全性」中确认此更改"
            fi
            print_info "现在可以在「系统设置」>「隐私与安全性」中看到「任何来源」选项"
        else
            print_error "禁用失败，请检查权限"
            if [ -n "$output" ]; then
                echo "$output"
            fi
        fi
    else
        print_info "需要管理员权限，请输入密码："
        output=$(sudo spctl --master-disable 2>&1)
        exit_code=$?

        # spctl --master-disable 成功时会输出提示信息，即使退出码可能非零
        if echo "$output" | grep -qi "assessment system\|Globally disabling" || [ $exit_code -eq 0 ]; then
            print_success "Gatekeeper 已禁用"
            if echo "$output" | grep -qi "System Settings"; then
                print_info "提示：需要在「系统设置」>「隐私与安全性」中确认此更改"
            fi
            print_info "现在可以在「系统设置」>「隐私与安全性」中看到「任何来源」选项"
        else
            print_error "禁用失败，可能是密码错误或权限不足"
            if [ -n "$output" ]; then
                echo "$output"
            fi
        fi
    fi

    echo ""
    read -p "按回车键继续..."
}

# 选项 2: SIP 禁用说明
show_sip_info() {
    print_info "系统完整性保护 (SIP) 说明"
    echo ""
    print_warning "SIP (System Integrity Protection) 是 macOS 的系统完整性保护机制，"
    print_warning "用于限制 root 账户对系统的完全控制权（也叫 Rootless 保护机制）。"
    echo ""
    print_info "SIP 状态检查："
    print_info "  在终端输入: csrutil status"
    echo ""
    print_info "禁用 SIP 步骤（需要在恢复模式下操作）："
    echo ""
    print_info "  1. 重启 Mac，按住 Command + R 直到屏幕上出现苹果标志和进度条"
    print_info "  2. 进入恢复模式后，在屏幕上方的工具栏找到并打开「终端」"
    print_info "  3. 在终端输入命令: csrutil disable"
    print_info "  4. 关闭终端，重启 Mac"
    print_info "  5. 重启后可以在终端中运行 csrutil status 确认状态"
    echo ""
    print_warning "注意：禁用 SIP 会降低系统安全性，请谨慎操作。"
    print_warning "如需重新启用 SIP，在恢复模式下运行: csrutil enable"
    echo ""
    print_info "当前状态检查："
    echo ""
    print_info "Gatekeeper 状态（使用 spctl --status 检查）："
    gatekeeper_status=$(spctl --status 2>&1)
    # spctl --status 即使成功也可能返回非零退出码，所以检查输出内容
    if [ -n "$gatekeeper_status" ]; then
        echo "  $gatekeeper_status"
    else
        print_warning "  无法检查 Gatekeeper 状态"
    fi
    echo ""
    print_info "SIP 状态（使用 csrutil status 检查）："
    sip_status=$(csrutil status 2>&1)
    if [ $? -eq 0 ]; then
        echo "  $sip_status"
    else
        print_warning "  无法在正常模式下检查 SIP 状态"
        print_info "  SIP 状态检查需要在恢复模式下运行 csrutil 命令"
    fi
    echo ""
    read -p "按回车键继续..."
}

# 选项 3: 解锁应用程序（xattr -cr）
unlock_app() {
    print_info "应用程序解锁工具"
    echo ""
    print_info "此功能可以移除应用程序的隔离属性（quarantine），"
    print_info "允许运行从网络下载或拖拽安装的应用。"
    echo ""

    # 方法 1: 拖拽应用
    print_info "请拖拽应用程序到此窗口，然后按回车："
    read -r app_path

    # 移除路径中的引号和空格
    app_path=$(echo "$app_path" | sed "s/^[[:space:]]*//;s/[[:space:]]*$//" | sed "s/^['\"]//;s/['\"]$//")

    if [ -z "$app_path" ]; then
        print_error "未输入应用程序路径"
        read -p "按回车键继续..."
        return
    fi

    if [ ! -e "$app_path" ]; then
        print_error "文件或目录不存在: $app_path"
        read -p "按回车键继续..."
        return
    fi

    print_info "正在解锁: $app_path"
    print_info "执行命令: xattr -cr \"$app_path\""

    xattr -cr "$app_path" 2>/dev/null

    if [ $? -eq 0 ]; then
        print_success "应用程序已解锁"
        print_info "您现在可以尝试运行该应用程序"
    else
        print_warning "解锁操作完成（某些文件可能没有隔离属性）"
    fi

    echo ""
    read -p "按回车键继续..."
}

# 选项 4: 检查当前状态
check_status() {
    print_info "正在检查系统安全设置状态..."
    echo ""

    print_info "=== Gatekeeper 状态 ==="
    gatekeeper_status=$(spctl --status 2>&1)
    # spctl --status 即使成功也可能返回非零退出码，所以检查输出内容
    if [ -n "$gatekeeper_status" ]; then
        echo "$gatekeeper_status"
        if echo "$gatekeeper_status" | grep -qi "disabled"; then
            print_success "Gatekeeper 已禁用（允许任何来源）"
        else
            print_info "Gatekeeper 已启用"
            print_info "如需禁用，请选择选项 1"
        fi
    else
        print_warning "无法检查 Gatekeeper 状态"
    fi

    echo ""
    print_info "=== SIP (系统完整性保护) 状态 ==="
    sip_status=$(csrutil status 2>&1)
    if [ $? -eq 0 ]; then
        echo "$sip_status"
        if echo "$sip_status" | grep -q "disabled"; then
            print_success "SIP 已禁用"
        else
            print_info "SIP 已启用（默认状态）"
            print_info "如需禁用，请选择选项 2 查看详细说明"
        fi
    else
        print_warning "无法在正常模式下检查 SIP 状态"
        print_info "SIP 状态检查需要在恢复模式下运行 csrutil 命令"
        print_info "请选择选项 2 查看 SIP 禁用说明"
    fi

    echo ""
    read -p "按回车键继续..."
}

# 主菜单
show_menu() {
    clear
    echo -e "${CYAN}==========================================${NC}"
    echo -e "  ${BOLD}${WHITE}🥷 Shuriken - macOS 权限设置工具${NC}"
    echo -e "${CYAN}==========================================${NC}"
    echo ""
    echo -e "${BOLD}请选择操作：${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} ${BOLD}禁用 Gatekeeper（允许任何来源）${NC}"
    echo -e "     ${YELLOW}sudo spctl --master-disable${NC}"
    echo ""
    echo -e "  ${MAGENTA}2)${NC} ${BOLD}SIP 禁用说明${NC}"
    echo -e "     ${YELLOW}查看系统完整性保护的禁用方法（需恢复模式）${NC}"
    echo ""
    echo -e "  ${CYAN}3)${NC} ${BOLD}解锁应用程序 (xattr -cr)${NC}"
    echo -e "     ${YELLOW}移除应用的隔离属性${NC}"
    echo ""
    echo -e "  ${YELLOW}4)${NC} ${BOLD}检查当前状态${NC}"
    echo -e "     ${YELLOW}查看 Gatekeeper 和 SIP 的当前状态${NC}"
    echo ""
    echo -e "  ${RED}0)${NC} ${BOLD}退出${NC}"
    echo ""
    echo -e "${CYAN}==========================================${NC}"
    echo -ne "${BOLD}请输入选项 ${GREEN}[0-4]${NC}${BOLD}: ${NC}"
}

# 主循环
main() {
    check_macos

    while true; do
        show_menu
        read -r choice

        case $choice in
            1)
                disable_gatekeeper
                ;;
            2)
                show_sip_info
                ;;
            3)
                unlock_app
                ;;
            4)
                check_status
                ;;
            0)
                print_info "感谢使用 Shuriken！"
                exit 0
                ;;
            *)
                print_error "无效选项，请重新选择"
                sleep 1
                ;;
        esac
    done
}

# 运行主程序
main
