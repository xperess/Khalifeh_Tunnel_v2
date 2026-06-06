#!/bin/bash
# =================================================================
#  KHALIFEH TUNNEL CORE CLI LAYER
# =================================================================

BASE="/opt/khalifeh"
MOD="$BASE/modules"
CFG="$BASE/configs"

# لود کردن ماژول‌ها از دایرکتوری ثابت و صحیح سیستم
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
    echo -e "${CYAN}    KHALIFEH TUNNEL v2 (BUG-FREE MASTER)   ${NC}"
    echo -e "${MAGENTA}==========================================${NC}"
}

health_check() {
    banner
    echo -e "${YELLOW}[*] Node Framework Telemetry Status:${NC}\n"
    for svc in khalifeh-rathole-server khalifeh-rathole-client frps frpc hysteria2 hysteria2-client khalifeh-web khalifeh-failover; do
        if systemctl list-units --full -all 2>/dev/null | grep -q "$svc"; then
            STATUS=$(systemctl is-active "$svc" 2>/dev/null)
            if [[ "$STATUS" == "active" ]]; then
                echo -e " ● $svc : ${GREEN}ACTIVE (RUNNING)${NC}"
            else
                echo -e " ● $svc : ${RED}INACTIVE (STOPPED)${NC}"
            fi
        else
            echo -e " ● $svc : ${YELLOW}UNCONFIGURED${NC}"
        fi
    done
    read -p "Press Enter to return..."
}

sys_optimize() {
    banner
    echo -e "${GREEN}[*] Injecting High-Performance Linux Network Stack Metrics...${NC}"
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
    echo -e "${GREEN}[+] Network optimization and BBR congestion limits applied.${NC}"
    read -p "Press Enter..."
}

uninstall_project() {
    banner
    echo -e "${RED}[!] CRITICAL WARNING: This action will permanently remove all configs, binaries, and services!${NC}"
    read -p "Are you completely sure you want to completely uninstall? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        echo "[*] Dismantling system services..."
        for svc in khalifeh-rathole-server khalifeh-rathole-client frps frpc hysteria2 hysteria2-client khalifeh-web khalifeh-failover; do
            systemctl stop "$svc" >/dev/null 2>&1
            systemctl disable "$svc" >/dev/null 2>&1
            rm -f /etc/systemd/system/"$svc".service
        done
        systemctl daemon-reload
        
        echo "[*] Scrubbing file structures from disk..."
        rm -rf /opt/khalifeh
        rm -f /usr/local/bin/khalifeh
        rm -f /etc/sysctl.d/99-khalifeh.conf
        
        echo -e "${GREEN}[+] Project files and core configurations uninstalled successfully.${NC}"
        exit 0
    else
        echo "[*] Uninstall canceled."
        sleep 1
    fi
}

main_menu() {
    while true; do
        banner
        echo -e "1) ${CYAN}Rathole Module Terminal (Primary)${NC}"
        echo -e "2) ${CYAN}FRP Module Terminal (Failover Route)${NC}"
        echo -e "3) ${CYAN}Hysteria2 Module Terminal (UDP Obfuscation)${NC}"
        echo "4) Status Overview"
        echo "5) Framework Diagnostics"
        echo "6) Server Traffic Optimization"
        echo -e "9) ${RED}Uninstall Project (Wipe All Files & Services)${NC}"
        echo "0) Exit Session"
        echo "------------------------------------------"
        read -p "Select Menu Entry: " choice
        case $choice in
            1) declare -f rathole_menu >/dev/null && rathole_menu || (echo -e "${RED}[- ] Error: Rathole module not loaded. File linking fault.${NC}" && read -p "Press Enter...");;
            2) declare -f frp_menu >/dev/null && frp_menu || (echo -e "${RED}[-] Error: FRP module not loaded. File linking fault.${NC}" && read -p "Press Enter...");;
            3) declare -f hysteria_menu >/dev/null && hysteria_menu || (echo -e "${RED}[-] Error: Hysteria2 module not loaded. File linking fault.${NC}" && read -p "Press Enter...");;
            4|5) health_check ;;
            6) sys_optimize ;;
            9) uninstall_project ;;
            0) exit 0 ;;
            *) echo "Invalid workspace selection." && sleep 1 ;;
        esac
    done
}
EOF
