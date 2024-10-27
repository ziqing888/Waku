#!/bin/bash

# =============================================================================
# 脚本名称: setup_waku_node.sh
# 描述: 自动化安装和管理 Waku 节点
# 作者: 子清
# 日期: 2024-10-27
# =============================================================================

# 检查是否以 root 用户运行
if [ "$(id -u)" != "0" ]; then
    echo -e "\e[1;31m❌ 此脚本需要以root用户权限运行。请使用 'sudo -i' 切换到root用户后再次运行。\e[0m"
    exit 1
fi

# 设置日志文件
LOG_FILE="./waku_setup.log"
if ! touch "$LOG_FILE" &> /dev/null; then
    LOG_FILE="./waku_setup.log"
fi

# 定义颜色和样式变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
RESET='\033[0m'

# 定义图标
INFO_ICON="ℹ️"
SUCCESS_ICON="✅"
WARNING_ICON="⚠️"
ERROR_ICON="❌"

# 定义信息显示函数
log_info() {
    echo -e "${BLUE}${INFO_ICON} [INFO]${RESET} $1"
    echo "[INFO] $1" >> "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}${SUCCESS_ICON} [SUCCESS]${RESET} $1"
    echo "[SUCCESS] $1" >> "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}${WARNING_ICON} [WARNING]${RESET} $1"
    echo "[WARNING] $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}${ERROR_ICON} [ERROR]${RESET} $1"
    echo "[ERROR] $1" >> "$LOG_FILE"
}

# 设置 nwaku 目录
SCRIPT_PATH="$HOME/nwaku-compose"

# 主菜单函数
function main_menu() {
    while true; do
        clear
        # 下载并显示 logo
        curl -s https://raw.githubusercontent.com/ziqing888/logo.sh/refs/heads/main/logo.sh | bash
        sleep 3
        echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${CYAN}${BOLD}║${RESET}               🚀 ${CYAN}${BOLD}欢迎使用 Waku 节点管理脚本${RESET} 🚀              ${CYAN}${BOLD}║${RESET}"
        echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════╝${RESET}"
        echo -e "${BOLD}请选择您要执行的操作:${RESET}"
        echo -e "  ${GREEN}1. ${RESET}${BOLD}安装节点${RESET}          ${INFO_ICON}"
        echo -e "  ${YELLOW}2. ${RESET}${BOLD}修复错误${RESET}          ${WARNING_ICON}"
        echo -e "  ${BLUE}3. ${RESET}${BOLD}更新脚本${RESET}          ${SUCCESS_ICON}"
        echo -e "  ${CYAN}4. ${RESET}${BOLD}查看日志${RESET}          ${INFO_ICON}"
        echo -e "  ${RED}5. ${RESET}${BOLD}退出${RESET}              ${ERROR_ICON}"
        echo -e "${CYAN}${BOLD}============================================================${RESET}"
        read -rp "请输入操作选项 [1-5]: " choice

        case $choice in
            1) install_node ;;
            2) fix_errors ;;
            3) update_script ;;
            4) view_logs ;;
            5) log_info "退出脚本。"; exit 0 ;;
            *) log_warning "无效的选择，请重新选择。"; sleep 2 ;;
        esac
    done
}

# 安装节点工具和 Docker
function install_node_tools() {
    log_info "更新软件源并安装必备软件包..."
    sudo apt update && sudo apt upgrade -y
    log_info "安装必要的软件和 Docker..."
    sudo apt install -y curl iptables build-essential git wget jq make gcc nano tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev docker.io

    # 检查 Docker Compose 安装
    if ! command -v docker-compose &> /dev/null; then
        log_info "安装 docker-compose..."
        sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        docker-compose --version
    else
        log_info "docker-compose 已安装。"
    fi
    log_success "系统和必备软件包安装完成。"
}

# 安装 Waku 节点
function install_node() {
    install_node_tools  # 安装工具和 Docker

    # 克隆或更新 nwaku-compose 项目
    if [ -d "$SCRIPT_PATH" ]; then
        log_info "更新 nwaku-compose 项目..."
        cd "$SCRIPT_PATH" || { log_error "进入目录失败，请检查错误信息。"; exit 1; }
        git stash push --include-untracked
        git pull origin master
    else
        log_info "克隆 nwaku-compose 项目..."
        git clone https://github.com/waku-org/nwaku-compose "$SCRIPT_PATH"
    fi

    cd "$SCRIPT_PATH" || { log_error "进入目录失败，请检查错误信息。"; exit 1; }

    cp .env.example .env
    log_info "配置 .env 文件..."
    read -rp "请输入您的 Infura 项目密钥： " infura_key
    read -rp "请输入您的测试网络私钥（不要0x开头）： " testnet_private_key
    read -rp "请输入您的安全密钥存储密码： " keystore_password

    sed -i "s|<key>|$infura_key|g" .env
    sed -i "s|<YOUR_TESTNET_PRIVATE_KEY_HERE>|$testnet_private_key|g" .env
    sed -i "s|my_secure_keystore_password|$keystore_password|g" .env

    ./register_rln.sh
    log_info "启动 Docker Compose 服务..."
    docker-compose up -d || { log_error "启动 Docker Compose 失败，请检查错误信息。"; exit 1; }
    log_success "Waku 节点已成功安装并启动。"
    read -rp "按 Enter 返回菜单。"
}

# 查看日志函数
function view_logs() {
    log_info "查看 Waku 节点日志..."
    cd "$SCRIPT_PATH" || { log_error "无法进入目录，请检查错误信息。"; exit 1; }
    docker-compose logs -f nwaku
    log_info "按 Ctrl+C 退出日志查看。"
}

# 修复错误函数
function fix_errors() {
    cd "$SCRIPT_PATH" || { log_error "无法进入目录，请检查错误信息。"; exit 1; }
    docker-compose down
    git stash push --include-untracked
    git pull origin master
    rm -rf keystore rln_tree
    nano .env
    docker-compose up -d || { log_error "启动 Docker Compose 失败，请检查错误信息。"; exit 1; }
    log_success "错误修复完成。"
    read -rp "按 Enter 返回菜单。"
}

# 更新脚本函数
function update_script() {
    cd "$SCRIPT_PATH" || { log_error "无法进入目录，请检查错误信息。"; exit 1; }
    docker-compose down
    git pull origin master
    docker-compose up -d || { log_error "启动 Docker Compose 失败，请检查错误信息。"; exit 1; }
    log_success "脚本更新完成。"
    read -rp "按 Enter 返回菜单。"
}

# 启动主程序
main_menu
