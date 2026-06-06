#!/bin/bash

check_svc() { systemctl is-active "$1" >/dev/null 2>&1; echo $?; }

echo "[*] Auto Failover Monitoring Agent Initialized..."

while true; do
    R_SERVER=$(check_svc khalifeh-rathole-server)
    R_CLIENT=$(check_svc khalifeh-rathole-client)
    
    # اگر مسیر اصلی (Rathole) متصل و بدون مشکل کار می‌کند
    if [[ $R_SERVER -eq 0 || $R_CLIENT -eq 0 ]]; then
        # لایه‌های فرعی بک‌آپ را خاموش نگه دار
        systemctl stop frps frpc hysteria2 hysteria2-client >/dev/null 2>&1
        sleep 8
        continue
    fi
    
    # اگر رتهول قطع شد، سوئیچ به اولویت دوم: FRP
    echo "[!] Primary Tunnel (Rathole) is offline! Escalating to Fallback Level 1 (FRP)..."
    if systemctl list-unit-files | grep -q "frps.service"; then
        [[ $(check_svc frps) -ne 0 ]] && systemctl start frps
    fi
    if systemctl list-unit-files | grep -q "frpc.service"; then
        [[ $(check_svc frpc) -ne 0 ]] && systemctl start frpc
    fi
    
    sleep 6
    
    # اگر FRP هم در دسترس نبود، سوئیچ به لایه نهایی: Hysteria2
    if [[ $(check_svc frps) -ne 0 && $(check_svc frpc) -ne 0 ]]; then
        echo "[!!] Fallback 1 Failed! Activating Last Resort Layer (Hysteria2)..."
        if systemctl list-unit-files | grep -q "hysteria2.service"; then
            [[ $(check_svc hysteria2) -ne 0 ]] && systemctl start hysteria2
        fi
        if systemctl list-unit-files | grep -q "hysteria2-client.service"; then
            [[ $(check_svc hysteria2-client) -ne 0 ]] && systemctl start hysteria2-client
        fi
    fi
    sleep 12
done
