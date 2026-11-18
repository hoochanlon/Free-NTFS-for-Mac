#!/bin/bash

################################################################################
# Shuriken - macOS 系统权限与安全性设置工具 (Multi-language Support)
#
# 设置语言: LANG=ja bash shuriken.sh (日文) 或 LANG=en bash shuriken.sh (英文)
################################################################################

# ============================================================
# 加载多语言支持
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/shuriken-lang.sh" ]; then
	source "$SCRIPT_DIR/shuriken-lang.sh"
else
	t() { echo "$1"; }
fi

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
        print_error "$(t error_macos_only)"
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
    print_info "$(t preparing_disable)"
    print_warning "$(t needs_admin)"
    echo ""
    print_info "$(t gatekeeper_desc)"
    print_info "$(t gatekeeper_result)"
    echo ""

    if check_admin; then
        print_info "$(t executing)"
        output=$(spctl --master-disable 2>&1)
        exit_code=$?

        if echo "$output" | grep -qi "assessment system\|Globally disabling" || [ $exit_code -eq 0 ]; then
            print_success "$(t disabled)"
            if echo "$output" | grep -qi "System Settings"; then
                print_info "$(t confirm_settings)"
            fi
            print_info "$(t anywhere_option)"
        else
            print_error "$(t disable_failed)"
            if [ -n "$output" ]; then
                echo "$output"
            fi
        fi
    else
        print_info "$(t enter_password)"
        output=$(sudo spctl --master-disable 2>&1)
        exit_code=$?

        if echo "$output" | grep -qi "assessment system\|Globally disabling" || [ $exit_code -eq 0 ]; then
            print_success "$(t disabled)"
            if echo "$output" | grep -qi "System Settings"; then
                print_info "$(t confirm_settings)"
            fi
            print_info "$(t anywhere_option)"
        else
            print_error "$(t password_error)"
            if [ -n "$output" ]; then
                echo "$output"
            fi
        fi
    fi

    echo ""
    read -p "$(t press_enter)"
}

# 选项 2: SIP 禁用说明
show_sip_info() {
    print_info "$(t sip_info)"
    echo ""
    print_warning "$(t sip_warning)"
    print_warning "$(t sip_warning2)"
    echo ""
    print_info "$(t sip_status_check)"
    print_info "$(t sip_status_cmd)"
    echo ""
    print_info "$(t sip_disable_steps)"
    echo ""
    print_info "$(t sip_step1)"
    print_info "$(t sip_step2)"
    print_info "$(t sip_step3)"
    print_info "$(t sip_step4)"
    print_info "$(t sip_step5)"
    echo ""
    print_warning "$(t sip_security_warning)"
    print_warning "$(t sip_reenable)"
    echo ""
    print_info "$(t current_status)"
    echo ""
    print_info "$(t gatekeeper_status)"
    gatekeeper_status=$(spctl --status 2>&1)
    if [ -n "$gatekeeper_status" ]; then
        echo "  $gatekeeper_status"
    else
        print_warning "$(t cannot_check_gatekeeper)"
    fi
    echo ""
    print_info "$(t sip_status_check2)"
    sip_status=$(csrutil status 2>&1)
    if [ $? -eq 0 ]; then
        echo "  $sip_status"
    else
        print_warning "$(t cannot_check_sip)"
        print_info "$(t sip_recovery_mode)"
    fi
    echo ""
    read -p "$(t press_enter)"
}

# 选项 3: 解锁应用程序（xattr -cr）
unlock_app() {
    print_info "$(t unlock_app)"
    echo ""
    print_info "$(t unlock_desc)"
    print_info "$(t unlock_desc2)"
    echo ""

    print_info "$(t drag_app)"
    read -r app_path

    app_path=$(echo "$app_path" | sed "s/^[[:space:]]*//;s/[[:space:]]*$//" | sed "s/^['\"]//;s/['\"]$//")

    if [ -z "$app_path" ]; then
        print_error "$(t no_path)"
        read -p "$(t press_enter)"
        return
    fi

    if [ ! -e "$app_path" ]; then
        print_error "$(t not_found "$app_path")"
        read -p "$(t press_enter)"
        return
    fi

    print_info "$(t unlocking "$app_path")"
    print_info "$(t unlock_cmd "$app_path")"

    xattr -cr "$app_path" 2>/dev/null

    if [ $? -eq 0 ]; then
        print_success "$(t unlocked)"
        print_info "$(t unlock_try)"
    else
        print_warning "$(t unlock_warning)"
    fi

    echo ""
    read -p "$(t press_enter)"
}

# 选项 4: 检查当前状态
check_status() {
    print_info "$(t checking_status)"
    echo ""

    print_info "$(t gatekeeper_status_title)"
    gatekeeper_status=$(spctl --status 2>&1)
    if [ -n "$gatekeeper_status" ]; then
        echo "$gatekeeper_status"
        if echo "$gatekeeper_status" | grep -qi "disabled"; then
            print_success "$(t gatekeeper_disabled)"
        else
            print_info "$(t gatekeeper_enabled)"
            print_info "$(t disable_option)"
        fi
    else
        print_warning "$(t cannot_check_gatekeeper)"
    fi

    echo ""
    print_info "$(t sip_status_title)"
    sip_status=$(csrutil status 2>&1)
    if [ $? -eq 0 ]; then
        echo "$sip_status"
        if echo "$sip_status" | grep -q "disabled"; then
            print_success "$(t sip_disabled)"
        else
            print_info "$(t sip_enabled)"
            print_info "$(t sip_disable_info)"
        fi
    else
        print_warning "$(t cannot_check_sip)"
        print_info "$(t sip_recovery_mode)"
        print_info "$(t sip_disable_info)"
    fi

    echo ""
    read -p "$(t press_enter)"
}

# 主菜单
show_menu() {
    clear
    echo -e "${CYAN}==========================================${NC}"
    echo -e "  ${BOLD}${WHITE}$(t menu_title)${NC}"
    echo -e "${CYAN}==========================================${NC}"
    echo ""
    echo -e "${BOLD}$(t select_operation)${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} ${BOLD}$(t option1)${NC}"
    echo -e "     ${YELLOW}$(t option1_cmd)${NC}"
    echo ""
    echo -e "  ${MAGENTA}2)${NC} ${BOLD}$(t option2)${NC}"
    echo -e "     ${YELLOW}$(t option2_desc)${NC}"
    echo ""
    echo -e "  ${CYAN}3)${NC} ${BOLD}$(t option3)${NC}"
    echo -e "     ${YELLOW}$(t option3_desc)${NC}"
    echo ""
    echo -e "  ${YELLOW}4)${NC} ${BOLD}$(t option4)${NC}"
    echo -e "     ${YELLOW}$(t option4_desc)${NC}"
    echo ""
    echo -e "  ${RED}0)${NC} ${BOLD}$(t option0)${NC}"
    echo ""
    echo -e "${CYAN}==========================================${NC}"
    echo -ne "${BOLD}$(t enter_option)${NC}"
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
                print_info "$(t thanks)"
                exit 0
                ;;
            *)
                print_error "$(t invalid_option)"
                sleep 1
                ;;
        esac
    done
}

# 运行主程序
main
