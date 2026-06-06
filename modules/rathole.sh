#!/bin/bash

rathole_menu() {
    while true; do
        clear
        echo "==== RATHOLE MODULE CENTER ===="
        echo "1) Start Server Service (Iran)"
        echo "2) Start Client Service (Kharej)"
        echo "3) Stop Rathole Services"
        echo "4) Show Service Logs"
        echo "0) Back"
        read -p "Select: " rc
        case $rc in
            1) systemctl start khalifeh-rathole-server && echo "[+] Server started." && sleep 1;;
            2) systemctl start khalifeh-rathole-client && echo "[+] Client started." && sleep 1;;
            3) systemctl stop khalifeh-rathole-server khalifeh-rathole-client && echo "[+] Stopped." && sleep 1;;
            4) journalctl -u khalifeh-rathole-server -u khalifeh-rathole-client -n 25 --no-pager; read -p "Press Enter...";;
            0) break;;
        esac
    done
}
