#!/bin/bash

BASE="/opt/khalifeh"
MOD="$BASE/modules"
CFG="$BASE/configs"

# لود کردن ماژول‌ها به صورت امن
[[ -f "$MOD/rathole.sh" ]] && source "$MOD/rathole.sh"
[[ -f "$MOD/frp.sh" ]] && source "$MOD/frp.sh"
[[ -f "$MOD/hysteria2.sh" ]] && source "$MOD/hysteria2.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
MAGENTA='\033[0;35m'
NC='\033[0m'

banner() {
    clear
    echo -e "${MAGENTA}==========================================${NC}"
    echo -e "${CYAN}    KHALIFEH TUNNEL v2 (PRODUCTION)       ${NC}"
    echo -e "${MAGENTA}==========================================${NC}"
}

health_check() {
    banner
    echo -e "${YELLOW}[*] Checking System Services Status:${NC}\n"
    for svc in khalifeh-rathole-server khalifeh-rathole-client frps frpc hysteria2 hysteria2-client khalifeh-web khalifeh-failover; do
        if systemctl list-units --full -all 2>/dev/null | grep -q "$svc"; then
            STATUS=$(systemctl is-active "$svc" 2>/dev/null)
            if [[ "$STATUS" == "active" ]]; then
                echo -e "$svc : ${GREEN}● ACTIVE${NC}"
            else
                echo -e "$svc : ${RED}○ INACTIVE${NC}"
            fi
        else
            echo -e "$svc : ${YELLOW}Not Configured${NC}"
        fi
    done
    read -p "Press Enter to return..."
}

sys_optimize() {
    banner
    echo -e "${GREEN}[*] Optimizing Linux Network Stack for Tunneling...${NC}"
    cat <<EOF > /etc/sysctl.d/99-khalifeh.conf
fs.file-max = 65535
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 10000
net.core.somaxconn = 4096
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_congestion_control = bbr
EOF
    sysctl --system >/dev/null 2>&1
    echo -e "${GREEN}[+] BBR and network limits optimized successfully.${NC}"
    read -p "Press Enter..."
}

main_menu() {
    while true; do
        banner
        echo -e "1) ${CYAN}Rathole Module (Primary Tunnel)${NC}"
        echo -e "2) ${CYAN}FRP Module (Backup Tunnel)${NC}"
        echo -e "3) ${CYAN}Hysteria2 Module (Proxy/Tunnel)${NC}"
        echo -e "4) ${YELLOW}System Health Check${NC}"
        echo -e "5) ${GREEN}Network Optimize (BBR)${NC}"
        echo -e "0) Exit"
        echo "------------------------------------------"
        read -p "Select an option: " opt
        case $opt in
            1) rathole_menu ;;
            2) frp_menu ;;
            3) hysteria_menu ;;
            4) health_check ;;
            5) sys_optimize ;;
            0) exit 0 ;;
            *) echo "Invalid option"; sleep 1 ;;
        esac
    done
}