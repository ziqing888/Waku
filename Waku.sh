#!/bin/bash

# 定义颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 检查是否以 root 用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}此脚本需要以 root 用户权限运行。${NC}"
    echo -e "${YELLOW}请尝试使用 'sudo -i' 命令切换到 root 用户，然后再次运行此脚本。${NC}"
    exit 1
fi

# 下载并显示 Logo
display_logo() {
    curl -s https://raw.githubusercontent.com/ziqing888/logo.sh/refs/heads/main/logo.sh | bash
}

# 主菜单显示
show_menu() {
    clear
    display_logo  # 在菜单顶部显示 Logo
    echo -e "${CYAN}======================================================${NC}"
    echo -e "${YELLOW}            🌐 Waku 节点自动化安装菜单               ${NC}"
    echo -e "${CYAN}======================================================${NC}"
    echo -e "${GREEN}1)${NC} 更新系统并安装依赖项"
    echo -e "${GREEN}2)${NC} 安装 Docker 和 Docker Compose"
    echo -e "${GREEN}3)${NC} 安装和配置节点"
    echo -e "${GREEN}4)${NC} 查看节点日志"
    echo -e "${GREEN}5)${NC} 更新节点"
    echo -e "${GREEN}6)${NC} 显示节点监控链接"
    echo -e "${GREEN}7)${NC} 退出脚本"
    echo -e "${CYAN}======================================================${NC}"
}

# 更新系统并安装依赖项
install_dependencies() {
    echo -e "${YELLOW}更新系统并安装依赖项...${NC}"
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl iptables build-essential git wget jq make gcc nano tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev
}

# 安装 Docker 和 Docker Compose
install_docker() {
    echo -e "${YELLOW}检查 Docker 和 Docker Compose 是否已安装...${NC}"
    
    if command -v docker &> /dev/null; then
        echo -e "${CYAN}Docker 已安装，跳过 Docker 安装步骤。${NC}"
    else
        echo -e "${YELLOW}安装 Docker...${NC}"
        sudo apt install docker.io -y
    fi
    
    if command -v docker-compose &> /dev/null; then
        echo -e "${CYAN}Docker Compose 已安装，跳过 Docker Compose 安装步骤。${NC}"
    else
        echo -e "${YELLOW}安装 Docker Compose...${NC}"
        sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
}

# 检查钱包余额是否足够
check_balance() {
    local infura_key=$1
    local wallet_address=$2

    balance=$(curl -s -X POST -H "Content-Type: application/json" \
      --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"$wallet_address\", \"latest\"],\"id\":1}" \
      https://sepolia.infura.io/v3/$infura_key | jq -r '.result')

    eth_balance=$(echo "scale=18; $((16#$balance)) / 10^18" | bc -l)
    echo -e "${GREEN}钱包余额：${eth_balance} ETH${NC}"
    if (( $(echo "$eth_balance < 0.1" | bc -l) )); then
        echo -e "${RED}余额不足，可能会导致注册失败。请确保钱包中至少有 0.1 ETH。${NC}"
    fi
}

# 安装和配置节点
install_node() {
    echo -e "${YELLOW}检查并获取 nwaku-compose 项目...${NC}"
    
    # 克隆或更新 nwaku-compose 项目
    if [ -d "nwaku-compose" ]; then
        echo -e "${CYAN}更新 nwaku-compose 项目...${NC}"
        cd nwaku-compose || exit
        git stash push --include-untracked
        git pull origin master
        cd ..
    else
        echo -e "${YELLOW}克隆 nwaku-compose 项目...${NC}"
        git clone https://github.com/waku-org/nwaku-compose
    fi

    cd nwaku-compose || exit
    cp .env.example .env

    # 提示用户输入 Infura 项目密钥和其他信息
    read -p "请输入您的 Infura 项目密钥（key）： " infura_key
    read -p "请输入您的测试网络私钥（不要0x开头）： " testnet_private_key
    read -p "请输入您的安全密钥存储密码： " keystore_password
    read -p "请输入您的钱包地址（用于检查余额）： " wallet_address

    # 检查余额
    check_balance "$infura_key" "$wallet_address"

    # 正确替换 .env 文件中的相关参数
    sed -i "s|<key>|$infura_key|g" .env
    sed -i "s|<YOUR_TESTNET_PRIVATE_KEY_HERE>|$testnet_private_key|g" .env
    sed -i "s|my_secure_keystore_password|$keystore_password|g" .env

    echo -e "${YELLOW}执行 register_rln.sh 脚本...${NC}"
    ./register_rln.sh

    echo -e "${YELLOW}启动 Docker Compose 服务...${NC}"
    docker-compose up -d
    echo -e "${CYAN}Docker Compose 服务启动完成。${NC}"
}

# 查看日志
view_logs() {
    echo -e "${YELLOW}正在查看节点日志...${NC}"
    cd nwaku-compose || exit
    docker-compose logs -f nwaku
    echo -e "${CYAN}按 Ctrl+C 退出日志查看。${NC}"
}

# 更新脚本
update_script() {
    echo -e "${YELLOW}更新并重启 nwaku-compose 项目...${NC}"
    cd nwaku-compose || exit
    docker-compose down
    git pull origin master
    docker-compose up -d
    echo -e "${CYAN}脚本更新完成。${NC}"
}

# 显示节点监控链接
show_monitoring_link() {
    SERVER_IP=$(curl -s http://checkip.amazonaws.com)
    echo -e "${GREEN}您的节点监控链接如下：${NC}"
    echo -e "${CYAN}http://$SERVER_IP:3000/d/yns_4vFVk/nwaku-monitoring${NC}"
    echo -e "${YELLOW}在浏览器中访问此链接以查看节点状态。${NC}"
}

# 主程序循环
while true; do
    show_menu
    read -p "请选择操作 [1-7]: " choice
    case $choice in
        1) install_dependencies ;;
        2) install_docker ;;
        3) install_node ;;
        4) view_logs ;;
        5) update_script ;;
        6) show_monitoring_link ;;
        7) echo -e "${RED}退出脚本。${NC}"; exit 0 ;;
        *) echo -e "${RED}无效选择，请重试。${NC}" ;;
    esac
    read -n 1 -s -r -p "按任意键返回主菜单..."
done
