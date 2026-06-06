#!/bin/bash

# =================================================================
#        KHALIFEH TUNNEL v2 (OFFICIAL PREMIUM FULL BUILD)
# =================================================================

if [[ $EUID -ne 0 ]]; then
   echo "[-] This script must be run as root (sudo)." 
   exit 1
fi

echo "[*] Cleaning old workspace..."
rm -rf /opt/khalifeh
rm -f /usr/local/bin/khalifeh

BASE_DIR="/opt/khalifeh"
BIN_DIR="$BASE_DIR/bin"
CFG_DIR="$BASE_DIR/configs"
MOD_DIR="$BASE_DIR/modules"
WEB_DIR="$BASE_DIR/web"

# ایجاد پوشه‌های ساختاری پروژه
mkdir -p "$BIN_DIR" "$CFG_DIR" "$MOD_DIR" "$WEB_DIR/templates" "$BASE_DIR/backup"

echo "[*] Installing system package dependencies..."
apt update -y && apt install -y curl wget jq unzip openssl python3-flask python3-pip -y

ARCH=$(uname -m)

# ۱. دانلود باینری‌های پایدار بر اساس معماری پردازنده سرور
if [[ "$ARCH" == "x86_64" ]]; then
    R_URL="https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-x86_64-unknown-linux-gnu.zip"
    F_URL="https://github.com/fatedier/frp/releases/download/v0.61.2/frp_0.61.2_linux_amd64.tar.gz"
    H_URL="https://github.com/apernet/hysteria/releases/download/v2.6.1/hysteria-linux-amd64"
else
    R_URL="https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-aarch64-unknown-linux-gnu.zip"
    F_URL="https://github.com/fatedier/frp/releases/download/v0.61.2/frp_0.61.2_linux_arm64.tar.gz"
    H_URL="https://github.com/apernet/hysteria/releases/download/v2.6.1/hysteria-linux-arm64"
fi

echo "[*] Fetching core engine binaries..."
curl -L "$R_URL" -o /tmp/rathole.zip && unzip -o /tmp/rathole.zip -d /tmp/ && cp /tmp/rathole "$BIN_DIR/"
curl -L "$F_URL" -o /tmp/frp.tar.gz && tar -xzf /tmp/frp.tar.gz -C /tmp/ && cp /tmp/frp*/frps /tmp/frp*/frpc "$BIN_DIR/"
curl -L "$H_URL" -o "$BIN_DIR/hysteria2"
chmod +x $BIN_DIR/*
rm -rf /tmp/rathole* /tmp/frp*

# ۲. ساخت فایل ماژول رتهول (modules/rathole.sh)
cat > "$MOD_DIR/rathole.sh" << 'RATHOLE_EOF'
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
RATHOLE_EOF

# ۳. ساخت فایل ماژول اف‌آرپی (modules/frp.sh)
cat > "$MOD_DIR/frp.sh" << 'FRP_EOF'
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
FRP_EOF

# ۴. ساخت فایل ماژول هیستریا (modules/hysteria2.sh)
cat > "$MOD_DIR/hysteria2.sh" << 'HY_EOF'
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
HY_EOF

# ۵. ساخت فایل هسته اصلی پنل ترمینال (core.sh)
cat > "$BASE_DIR/core.sh" << 'CORE_EOF'
#!/bin/bash
BASE="/opt/khalifeh"
MOD="$BASE/modules"
CFG="$BASE/configs"

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
    echo -e "${CYAN}   KHALIFEH TUNNEL v2 (STABLE ENTERPRISE)${NC}"
    echo -e "${MAGENTA}==========================================${NC}"
}

status_all() {
    banner
    echo -e "${YELLOW}[*] Overall Infrastructure Status:${NC}\n"
    for svc in khalifeh-rathole-server khalifeh-rathole-client frps frpc hysteria2 hysteria2-client khalifeh-web khalifeh-failover; do
        if systemctl list-units --full -all 2>/dev/null | grep -q "$svc"; then
            STATUS=$(systemctl is-active "$svc" 2>/dev/null)
            if [[ "$STATUS" == "active" ]]; then
                echo -e " ● $svc : ${GREEN}RUNNING (ONLINE)${NC}"
            else
                echo -e " ● $svc : ${RED}STOPPED (OFFLINE)${NC}"
            fi
        else
            echo -e " ● $svc : ${YELLOW}NOT INSTALLED / DEPLOYED${NC}"
        fi
    done
    echo ""
    read -p "Press Enter to return..."
}

optimize_network() {
    echo "[*] Fine-tuning Linux Network Kernel for Tunnels (BBR)..."
    if ! grep -q "KHALIFEH OPTIMIZATION" /etc/sysctl.conf; then
        cat >> /etc/sysctl.conf << SYSCTL_EOF

# KHALIFEH OPTIMIZATION TUNING
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
SYSCTL_EOF
        sysctl -p >/dev/null 2>&1
    fi
    echo "[+] Network Kernel Optimization complete."
    read -p "Press Enter..."
}

backup() {
    TS=$(date +%Y%m%d_%H%M%S)
    BK="/opt/khalifeh/backup/backup_$TS.tar.gz"
    tar --exclude='/opt/khalifeh/backup' -czf "$BK" /opt/khalifeh
    echo "[+] Backup file created successfully at: $BK"
    read -p "Press Enter..."
}

restore() {
    ls /opt/khalifeh/backup/backup_*.tar.gz 2>/dev/null
    echo "Paste the full path of the targeted backup archive:"
    read FILE
    if [[ -f "$FILE" ]]; then
        tar -xzf "$FILE" -C /
        echo "[+] Restore successful. Refreshing components..."
        systemctl daemon-reload
    else
        echo "[-] Selected path reference is invalid."
    fi
    read -p "Press Enter..."
}

main_menu() {
    while true; do
        banner
        echo "1) Rathole Tunnel Manager"
        echo "2) FRP Tunnel Manager (v0.61+ TOML Structure)"
        echo "3) Hysteria2 Module Manager"
        echo "4) Real-time Nodes Status Overview"
        echo "5) Run Network Speed/Buffer BBR Optimizations"
        echo "6) Take Workspace Configuration Backup"
        echo "7) Restore Configuration Archive"
        echo "0) Safe Termination (Exit)"
        echo "------------------------------------------"
        read -p "Action Menu Target: " choice
        case $choice in
            1) declare -f rathole_menu >/dev/null && rathole_menu || (echo "Rathole sub-module linkage error" && sleep 2);;
            2) declare -f frp_menu >/dev/null && frp_menu || (echo "FRP sub-module linkage error" && sleep 2);;
            3) declare -f hysteria_menu >/dev/null && hysteria_menu || (echo "Hysteria2 sub-module linkage error" && sleep 2);;
            4) status_all;;
            5) optimize_network;;
            6) backup;;
            7) restore;;
            0) exit 0;;
            *) echo "Option outside range limits." && sleep 1;;
        esac
    done
}
CORE_EOF

# ۶. ساخت موتور هوشمند فیل‌اور خودکار (failover.sh)
cat > "$BASE_DIR/failover.sh" << 'FAIL_EOF'
#!/bin/bash
check_svc() { systemctl is-active "$1" >/dev/null 2>&1; echo $?; }

echo "[*] Auto Failover Monitoring Agent Initialized..."
while true; do
    R_SERVER=$(check_svc khalifeh-rathole-server)
    R_CLIENT=$(check_svc khalifeh-rathole-client)
    
    # مکانیزم بازگشت هوشمند: اگر مسیر اصلی (Rathole) متصل و آنلاین شد
    if [[ $R_SERVER -eq 0 || $R_CLIENT -eq 0 ]]; then
        # تمام لایه‌های فرعی پشتیبان را قطع کن تا آی‌پی‌ها لو نروند و منابع مصرف نشوند
        systemctl stop frps frpc hysteria2 hysteria2-client >/dev/null 2>&1
        sleep 8
        continue
    fi
    
    # اگر رتهول قطع شد، فورا به سراغ لایه پشتیبان اول (FRP) برو
    echo "[!] Primary Tunnel (Rathole) is offline! Escalating to Fallback Level 1 (FRP)..."
    if systemctl list-unit-files | grep -q "frps.service"; then
        [[ $(check_svc frps) -ne 0 ]] && systemctl start frps
    fi
    if systemctl list-unit-files | grep -q "frpc.service"; then
        [[ $(check_svc frpc) -ne 0 ]] && systemctl start frpc
    fi
    
    sleep 6
    
    # اگر لایه دوم (FRP) هم قطع بود، سیستم را به دژ پایانی (Hysteria2) منتقل کن
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
FAIL_EOF

# ۷. ایجاد بک‌اندهای وب پنل ایمن (app.py) بدون باگ تزریق دستور
cat > "$WEB_DIR/app.py" << 'APP_EOF'
from flask import Flask, jsonify, render_template, abort
import subprocess

app = Flask(__name__)
ALLOWED_SERVICES = ["khalifeh-rathole-server", "khalifeh-rathole-client", "frps", "frpc", "hysteria2", "hysteria2-client"]

def get_status(name):
    try:
        output = subprocess.check_output(["systemctl", "is-active", name], stderr=subprocess.STDOUT).decode().strip()
        return output
    except Exception:
        return "inactive"

@app.route("/")
def index(): return render_template("index.html")

@app.route("/api/status")
def status():
    return jsonify({s: get_status(s) for s in ALLOWED_SERVICES})

@app.route("/api/<action>/<name>")
def manage_service(action, name):
    if name not in ALLOWED_SERVICES or action not in ["start", "stop", "restart"]:
        abort(400, "Operation not allowed due to system policy restrictions.")
    try:
        subprocess.run(["systemctl", action, name], check=True)
        return jsonify({"status": f"{action}ed", "service": name})
    except subprocess.CalledProcessError:
        return jsonify({"status": "failed", "service": name}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
APP_EOF

# ۸. ایجاد فرانت‌اند وب داشبورد (index.html)
cat > "$WEB_DIR/templates/index.html" << 'HTML_EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Khalifeh Tunnel Panel</title>
    <style>
        body { background:#0d0d0d; color:#00ff33; font-family:monospace; padding:30px; }
        .box { padding:18px; border:1px solid #00ff33; margin:12px 0; background:#141414; border-radius:4px; }
        button { background:#222; color:#00ff33; border:1px solid #00ff33; padding:6px 14px; cursor:pointer; margin-right:6px; font-family:monospace; font-weight:bold;}
        button:hover { background:#00ff33; color:#111; }
        .active { color: #00ff00; font-weight: bold; text-shadow: 0 0 5px #00ff00; }
        .inactive { color: #ff0000; font-weight: bold; text-shadow: 0 0 5px #ff0000; }
    </style>
</head>
<body>
<h2>🔥 Khalifeh Tunnel Secure Infrastructure Panel</h2>
<div id="status">Syncing metrics with local nodes...</div>
<script>
async function loadStatus() {
    try {
        let res = await fetch('/api/status');
        let data = await res.json();
        let html = "";
        for (let k in data) {
            let statusClass = data[k] === "active" ? "active" : "inactive";
            html += `
            <div class="box">
                <b>[Component Node]</b> ${k} : <span class="${statusClass}">${data[k].toUpperCase()}</span>
                <br><br>
                <button onclick="control('${k}', 'start')">START</button>
                <button onclick="control('${k}', 'stop')">STOP</button>
                <button onclick="control('${k}', 'restart')">RESTART</button>
            </div>`;
        }
        document.getElementById("status").innerHTML = html;
    } catch (e) {
        document.getElementById("status").innerHTML = "<span class='inactive'>Failed to sync web panel state.</span>";
    }
}
async function control(name, action) {
    await fetch(`/api/${action}/${name}`);
    loadStatus();
}
setInterval(loadStatus, 4000);
loadStatus();
</script>
</body>
</html>
HTML_EOF

# دسترسی‌دهی اصولی به فایل‌های سیستم جهت اجرا
chmod +x $BASE_DIR/*.sh
chmod +x $MOD_DIR/*.sh

# ایجاد لانچر خط فرمان گلوبال ترمینال (دستور khalifeh)
cat > /usr/local/bin/khalifeh << 'LAUNCHER_EOF'
#!/bin/bash
source /opt/khalifeh/core.sh
main_menu
LAUNCHER_EOF
chmod +x /usr/local/bin/khalifeh

# ۹. ثبت سرویس‌های مانیتورینگ و پنل تحت وب در لینوکس
cat > /etc/systemd/system/khalifeh-web.service << EOF
[Unit]
Description=Khalifeh Web Dashboard Daemon Ingress
After=network.target
[Service]
WorkingDirectory=$WEB_DIR
ExecStart=/usr/bin/python3 app.py
Restart=always
[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/khalifeh-failover.service << EOF
[Unit]
Description=Khalifeh Intelligent Failover Engine Core
After=network.target
[Service]
ExecStart=/bin/bash $BASE_DIR/failover.sh
Restart=always
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable khalifeh-web.service khalifeh-failover.service
systemctl start khalifeh-web.service khalifeh-failover.service

# ۱۰. بخش هوشمند تفکیک نقش معماری شبکه (ایران / خارج)
echo "------------------------------------------------------"
echo "Select deployment role architecture for this machine:"
echo "1) IRAN Node (Server Endpoint Ingress)"
echo "2) KHAREJ Node (Client Tunnel Egress Destination)"
read -p "Role Assignment Selection [1-2]: " DeploymentRole

TOKEN=$(openssl rand -hex 16)

if [[ "$DeploymentRole" == "1" ]]; then
    # --- پیکربندی کامل سرور ایران ---
    read -p "Primary Tunnel Ingress Port [default 2333]: " TPORT
    TPORT=${TPORT:-2333}
    read -p "Target application ports to bridge (space separated, e.g., 443 80 8080): " PORTS

    # پیاده‌سازی فرمت کانفیگ مدرن و جدید برای FRPS نسخه 0.61.2
    cat > "$CFG_DIR/frps.toml" << EOF
bindPort = $((TPORT+1))
auth.method = "token"
auth.token = "$TOKEN"
EOF

    # کانفیگ سرور لایه رتهول
    cat > "$CFG_DIR/rathole-server.toml" << EOF
[server]
bind_addr = "0.0.0.0:$TPORT"
default_token = "$TOKEN"
[server.transport]
type = "tcp"
EOF
    for p in $PORTS; do
        cat >> "$CFG_DIR/rathole-server.toml" << EOF
[server.services.port$p]
bind_addr = "0.0.0.0:$p"
EOF
    done

    # ایجاد سرویس‌های سیستم‌دی ایران نود
    cat > /etc/systemd/system/khalifeh-rathole-server.service << EOF
[Unit]
Description=Rathole Server Component
After=network.target
[Service]
ExecStart=$BIN_DIR/rathole $CFG_DIR/rathole-server.toml
Restart=always
[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/frps.service << EOF
[Unit]
Description=FRP Modern Server Engine
After=network.target
[Service]
ExecStart=$BIN_DIR/frps -c $CFG_DIR/frps.toml
Restart=always
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable khalifeh-rathole-server frps
    systemctl start khalifeh-rathole-server
    
    clear
    echo "=========================================================="
    echo -e "\033[0;32m[+] IRAN TUNNEL INSTANCE READY\033[0m"
    echo "Rathole Core Ingress Port: $TPORT"
    echo "FRP Core Ingress Port:    $((TPORT+1))"
    echo "Generated Security Token: $TOKEN"
    echo "=========================================================="

else
    # --- پیکربندی کامل سرور خارج ---
    read -p "Enter Target Remote IRAN IP: " IRAN_IP
    read -p "Enter Iran Ingress Port [default 2333]: " TPORT
    TPORT=${TPORT:-2333}
    read -p "Enter Security Token copied from Iran Server: " TOKEN
    read -p "Local ports to route and map (space separated, e.g., 443 80 8080): " PORTS

    # کانفیگ کلاینت لایه رتهول
    cat > "$CFG_DIR/rathole-client.toml" << EOF
[client]
remote_addr = "$IRAN_IP:$TPORT"
default_token = "$TOKEN"
[client.transport]
type = "tcp"
EOF
    for p in $PORTS; do
        cat >> "$CFG_DIR/rathole-client.toml" << EOF
[client.services.port$p]
local_addr = "127.0.0.1:$p"
EOF
    done

    # پیاده‌سازی فرمت کانفیگ مدرن و جدید برای FRPC کلاینت نسخه 0.61.2
    cat > "$CFG_DIR/frpc.toml" << EOF
serverAddr = "$IRAN_IP"
serverPort = $((TPORT+1))
auth.method = "token"
auth.token = "$TOKEN"
EOF
    for p in $PORTS; do
        cat >> "$CFG_DIR/frpc.toml" << EOF
[[proxies]]
name = "tunnel-proxy-port-$p"
type = "tcp"
localIP = "127.0.0.1"
localPort = $p
remotePort = $p
EOF
    done

    # ایجاد سرویس‌های سیستم‌دی خارج نود
    cat > /etc/systemd/system/khalifeh-rathole-client.service << EOF
[Unit]
Description=Rathole Client Tunnel Endpoint
After=network.target
[Service]
ExecStart=$BIN_DIR/rathole $CFG_DIR/rathole-client.toml
Restart=always
[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/frpc.service << EOF
[Unit]
Description=FRP Client Node Infrastructure
After=network.target
[Service]
ExecStart=$BIN_DIR/frpc -c $CFG_DIR/frpc.toml
Restart=always
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable khalifeh-rathole-client frpc
    systemctl start khalifeh-rathole-client
    
    clear
    echo "=========================================================="
    echo -e "\033[0;32m[+] KHAREJ TUNNEL INSTANCE CONNECTED\033[0m"
    echo "=========================================================="
fi

echo "[*] Web Dashboard Link: http://YOUR_SERVER_IP:8080"
echo "[*] Type 'khalifeh' anywhere in your terminal to start management panel."
