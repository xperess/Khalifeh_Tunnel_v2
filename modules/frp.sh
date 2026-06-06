#!/bin/bash

frp_menu() {
    while true; do
        clear
        echo "==== FRP MODULE CENTER ===="
        echo "1) Start FRPS Server (Iran)"
        echo "2) Start FRPC Client (Kharej)"
        echo "3) Stop FRP Services"
        echo "4) Show Service Logs"
        echo "0) Back"
        read -p "Select: " fc
        case $fc in
            1) systemctl start frps && echo "[+] FRPS started." && sleep 1;;
            2) systemctl start frpc && echo "[+] FRPC started." && sleep 1;;
            3) systemctl stop frps frpc && echo "[+] FRP stopped." && sleep 1;;
            4) journalctl -u frps -u frpc -n 25 --no-pager; read -p "Press Enter...";;
            0) break;;
        esac
    done
}
