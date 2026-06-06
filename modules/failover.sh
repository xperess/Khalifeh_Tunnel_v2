#!/bin/bash
check_svc() {
    systemctl is-active "$1" >/dev/null 2>&1
    echo $?
}

echo "[*] Auto Failover Engine Initialized..."
while true; do
    R_SERVER=$(check_svc khalifeh-rathole-server)
    R_CLIENT=$(check_svc khalifeh-rathole-client)
    
    if [[ $R_SERVER -eq 0 || $R_CLIENT -eq 0 ]]; then
        if [[ $(check_svc frps) -eq 0 || $(check_svc frpc) -eq 0 ]]; then
            echo "[▲] Primary route (Rathole) is back online. Stopping backup routes..."
            systemctl stop frps frpc >/dev/null 2>&1
        fi
    else
        if [[ $(check_svc frps) -ne 0 && $(check_svc frpc) -ne 0 ]]; then
            echo "[▼] Primary route down! Activating FRP Backup Route..."
            systemctl start frps frpc >/dev/null 2>&1
        fi
    fi
    sleep 5
done
