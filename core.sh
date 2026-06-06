#!/bin/bash

BASE="/opt/khalifeh"
MOD="$BASE/modules"
CFG="$BASE/configs"

# لود کردن ایمن و هماهنگ ماژول‌ها از پوشه اصلاح شده modules
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
    echo -e "${CYAN}   KHALIFEH TUNNEL v2 (BUG FIXED VERSION)${NC}"
    echo -e "${MAGENTA}==========================================${NC}"
}

status_all() {
    banner
    echo -e "${YELLOW}[*] Overall Infrastructure Status:${NC}\n"
    for svc in khalifeh-rathole-server khalifeh-rathole-client frps frpc hysteria2 hysteria2-client khalifeh-web khalifeh-failover; do
        if systemctl list-units --full -all 2>/dev/null | grep -q "$svc"; then
            STATUS=$(systemctl is-active "$svc" 2>/dev/null)
            if [[ "$STATUS" == "active" ]]; then
                echo -e " ● $svc : ${GREEN}RUNNING${NC}"
            else
                echo -e " ● $svc : ${RED}STOPPED${NC}"
            fi
        else
            echo -e " ● $svc : ${YELLOW}NOT INSTALLED${NC}"
        fi
    done
    echo ""
    read -p "Press Enter to return..."
}

main_menu() {
    while true; do
        banner
        echo "1) Rathole Tunnel Manager"
        echo "2) FRP Tunnel Manager"
        echo "3) Hysteria2 Module Manager"
        echo "4) Real-time Nodes Status Overview"
        echo "0) Exit"
        echo "------------------------------------------"
        read -p "Select option: " choice
        case $choice in
            1) declare -f rathole_menu >/dev/null && rathole_menu || (echo "Rathole sub-module linkage error" && sleep 2);;
            2) declare -f frp_menu >/dev/null && frp_menu || (echo "FRP sub-module linkage error" && sleep 2);;
            3) declare -f hysteria_menu >/dev/null && hysteria_menu || (echo "Hysteria2 sub-module linkage error" && sleep 2);;
            4) status_all;;
            0) exit 0;;
            *) echo "Option outside range limits." && sleep 1;;
        esac
    done
}
