#!/bin/bash

hysteria_menu() {
    while true; do
        clear
        echo "==== HYSTERIA2 MODULE CENTER ===="
        echo "1) Start Hysteria2 Server"
        echo "2) Start Hysteria2 Client"
        echo "3) Stop Hysteria2 Services"
        echo "4) Show Service Logs"
        echo "0) Back"
        read -p "Select: " hc
        case $hc in
            1) systemctl start hysteria2 && echo "[+] Hysteria2 Server started." && sleep 1;;
            2) systemctl start hysteria2-client && echo "[+] Hysteria2 Client started." && sleep 1;;
            3) systemctl stop hysteria2 hysteria2-client && echo "[+] Hysteria2 stopped." && sleep 1;;
            4) journalctl -u hysteria2 -u hysteria2-client -n 25 --no-pager; read -p "Press Enter...";;
            0) break;;
        esac
    done
}
