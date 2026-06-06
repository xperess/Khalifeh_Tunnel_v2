#!/bin/bash
# =================================================================
#  KHALIFEH TUNNEL v2 - AUTOMATED GITHUB MASTER INSTALLER
# =================================================================

# ۱. بررسی دسترسی روت
if [[ $EUID -ne 0 ]]; then
   echo -e "\033[0;31m[-] Please run this script as root (sudo).\033[0m" 
   exit 1
fi

BASE_DIR="/opt/khalifeh"
BIN_DIR="$BASE_DIR/bin"
CFG_DIR="$BASE_DIR/configs"
MOD_DIR="$BASE_DIR/modules"
WEB_DIR="$BASE_DIR/web"

# ۲. پاک‌سازی کامل آثار نصب خراب قبلی برای جلوگیری از تداخل
echo "[*] Cleaning up any previous installation..."
systemctl stop khalifeh-web khalifeh-failover >/dev/null 2>&1
rm -rf "$BASE_DIR"
rm -f /usr/local/bin/khalifeh

# ۳. ایجاد دایرکتوری‌های استاندارد سیستم
echo "[*] Creating system directory architecture..."
mkdir -p "$BIN_DIR" "$CFG_DIR" "$MOD_DIR" "$WEB_DIR/templates"

# ۴. نصب وابستگی‌های پکیج لینوکس
echo "[*] Installing required system packages..."
apt update -y && apt install -y curl wget jq unzip openssl python3-flask python3-pip -y

echo "[*] Deploying system framework components..."

# =================================================================
# الف) ساخت خودکار ماژول rathole.sh
# =================================================================
cat << 'EOF' > "$MOD_DIR/rathole.sh"
#!/bin/bash
rathole_menu() {
    while true; do
        banner
        echo -e "${CYAN}=== Rathole Config Module ===${NC}"
        echo "1) Configure as IRAN (Server)"
        echo "2) Configure as KHAREJ (Client)"
        echo "3) Service Logs"
        echo "0) Back to Main Menu"
        read -p "Choice: " c
        case $c in
            1) rathole_iran ;;
            2) rathole_kharej ;;
            3) journalctl -u khalifeh-rathole-server -u khalifeh-rathole-client -n 50 --no-pager; read -p "Press Enter..." ;;
            0) break ;;
        esac
    done
}
rathole_iran() {
    read -p "Enter Bind Port [Default: 2333]: " port
    port=${port:-2333}
    read -p "Enter Ports to forward (comma separated, e.g. 80,443): " ports
    token=$(openssl rand -hex 16)
    cat <<EOF > /opt/khalifeh/configs/rathole-server.toml
[server]
bind_addr = "0.0.0.0:$port"
default_token = "$token"
[server.transport]
type = "tcp"
EOF
    IFS=',' read -ra ADDR <<< "$ports"
    for p in "${ADDR[@]}"; do
        p=$(echo $p | xargs)
        cat <<EOF >> /opt/khalifeh/configs/rathole-server.toml
[server.services.port_$p]
bind_addr = "127.0.0.1:$p"
EOF
    done
    cat <<EOF > /etc/systemd/system/khalifeh-rathole-server.service
[Unit]
Description=Khalifeh Rathole Server
After=network.target
[Service]
ExecStart=/opt/khalifeh/bin/rathole /opt/khalifeh/configs/rathole-server.toml
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable --now khalifeh-rathole-server
    echo -e "${GREEN}[+] Rathole Server Started on port $port.${NC}"
    echo -e "${YELLOW}[!] Share this token with Client: $token${NC}"
    read -p "Press Enter..."
}
rathole_kharej() {
    read -p "Enter Iran Server IP: " ip
    read -p "Enter Iran Bind Port [Default: 2333]: " port
    port=${port:-2333}
    read -p "Enter Token: " token
    read -p "Enter local ports to map (comma separated, e.g. 80,443): " ports
    cat <<EOF > /opt/khalifeh/configs/rathole-client.toml
[client]
remote_addr = "$ip:$port"
default_token = "$token"
[client.transport]
type = "tcp"
EOF
    IFS=',' read -ra ADDR <<< "$ports"
    for p in "${ADDR[@]}"; do
        p=$(echo $p | xargs)
        cat <<EOF >> /opt/khalifeh/configs/rathole-client.toml
[client.services.port_$p]
local_addr = "127.0.0.1:$p"
EOF
    done
    cat <<EOF > /etc/systemd/system/khalifeh-rathole-client.service
[Unit]
Description=Khalifeh Rathole Client
After=network.target
[Service]
ExecStart=/opt/khalifeh/bin/rathole /opt/khalifeh/configs/rathole-client.toml
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable --now khalifeh-rathole-client
    echo -e "${GREEN}[+] Rathole Client Service Deployed.${NC}"
    read -p "Press Enter..."
}
EOF

# =================================================================
# ب) ساخت خودکار ماژول frp.sh
# =================================================================
cat << 'EOF' > "$MOD_DIR/frp.sh"
#!/bin/bash
frp_menu() {
    while true; do
        banner
        echo -e "${CYAN}=== FRP v0.61.2 Module (Backup Route) ===${NC}"
        echo "1) Configure FRPS (Iran)"
        echo "2) Configure FRPC (Kharej)"
        echo "0) Back"
        read -p "Choice: " c
        case $c in
            1) frp_iran ;;
            2) frp_kharej ;;
            0) break ;;
        esac
    done
}
frp_iran() {
    read -p "Enter FRP Bind Port [Default: 7000]: " port
    port=${port:-7000}
    read -p "Enter Token: " token
    cat <<EOF > /opt/khalifeh/configs/frps.toml
bindPort = $port
auth.method = "token"
auth.token = "$token"
EOF
    cat <<EOF > /etc/systemd/system/frps.service
[Unit]
Description=FRP Server
After=network.target
[Service]
ExecStart=/opt/khalifeh/bin/frps -c /opt/khalifeh/configs/frps.toml
Restart=always
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable --now frps
    echo -e "${GREEN}[+] FRPS Installed successfully.${NC}"
    read -p "Press Enter..."
}
frp_kharej() {
    echo "FRP Client helper stub active."
    read -p "Press Enter..."
}
EOF

# =================================================================
# ج) ساخت خودکار ماژول hysteria2.sh
# =================================================================
cat << 'EOF' > "$MOD_DIR/hysteria2.sh"
#!/bin/bash
hysteria_menu() {
    while true; do
        banner
        echo -e "${CYAN}=== Hysteria2 Config Module ===${NC}"
        echo "1) Setup Hysteria2 Server"
        echo "2) Setup Hysteria2 Client"
        echo "0) Back"
        read -p "Choice: " c
        case $c in
            1) hy_server ;;
            2) hy_client ;;
            0) break ;;
        esac
    done
}
hy_server() {
    read -p "Enter Port [Default: 443]: " port
    port=${port:-443}
    password=$(openssl rand -base64 12)
    mkdir -p /etc/ssl/khalifeh
    openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
      -keyout /etc/ssl/khalifeh/key.pem -out /etc/ssl/khalifeh/cert.pem \
      -days 3650 -subj "/CN=localhost" 2>/dev/null
    cat <<EOF > /opt/khalifeh/configs/hysteria-server.yaml
listen: :$port
tls:
  cert: /etc/ssl/khalifeh/cert.pem
  key: /etc/ssl/khalifeh/key.pem
auth:
  type: password
  password: "$password"
EOF
    cat <<EOF > /etc/systemd/system/hysteria2.service
[Unit]
Description=Hysteria2 Server
After=network.target
[Service]
ExecStart=/opt/khalifeh/bin/hysteria2 server -c /opt/khalifeh/configs/hysteria-server.yaml
Restart=always
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable --now hysteria2
    echo -e "${GREEN}[+] Hysteria2 Server active on UDP:$port${NC}"
    read -p "Press Enter..."
}
hy_client() {
    echo "Hysteria2 Client configuration stub."
    read -p "Press Enter..."
}
EOF

# =================================================================
# د) ساخت خودکار هسته اسکریپت کنترل پنل (core.sh)
# =================================================================
cat << 'EOF' > "$BASE_DIR/core.sh"
#!/bin/bash
BASE="/opt/khalifeh"
MOD="$BASE/modules"
CFG="$BASE/configs"

source "$MOD/rathole.sh" 2>/dev/null
source "$MOD/frp.sh" 2>/dev/null
source "$MOD/hysteria2.sh" 2>/dev/null

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
MAGENTA='\033[0;35m'
NC='\033[0m'

banner() {
    clear
    echo -e "${MAGENTA}==========================================${NC}"
    echo -e "${CYAN}    KHALIFEH TUNNEL v2 (AUTOMATED CORE)   ${NC}"
    echo -e "${MAGENTA}==========================================${NC}"
}

main_menu() {
    while true; do
        banner
        echo -e "1) ${CYAN}Rathole Module Terminal (Primary)${NC}"
        echo -e "2) ${CYAN}FRP Module Terminal (Failover Route)${NC}"
        echo -e "3) ${CYAN}Hysteria2 Module Terminal (UDP Obfuscation)${NC}"
        echo "0) Exit Session"
        echo "------------------------------------------"
        read -p "Select Menu Entry: " choice
        case $choice in
            1) declare -f rathole_menu >/dev/null && rathole_menu || (echo -e "${RED}[-] Error: Function rathole_menu missing from memory.${NC}" && read -p "Press Enter...");;
            2) declare -f frp_menu >/dev/null && frp_menu || (echo -e "${RED}[-] Error: Function frp_menu missing from memory.${NC}" && read -p "Press Enter...");;
            3) declare -f hysteria_menu >/dev/null && hysteria_menu || (echo -e "${RED}[-] Error: Function hysteria_menu missing from memory.${NC}" && read -p "Press Enter...");;
            0) exit 0 ;;
            *) echo "Invalid selection." && sleep 1 ;;
        esac
    done
}
EOF

# =================================================================
# ه) ساخت خودکار موتور پایش و تعویض مسیر خودکار (failover.sh)
# =================================================================
cat << 'EOF' > "$BASE_DIR/failover.sh"
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
            systemctl stop frps frpc >/dev/null 2>&1
        fi
    else
        if [[ $(check_svc frps) -ne 0 && $(check_svc frpc) -ne 0 ]]; then
            systemctl start frps frpc >/dev/null 2>&1
        fi
    fi
    sleep 5
done
EOF

# =================================================================
# و) ساخت خودکار کدهای بک‌اند پنل وب (app.py)
# =================================================================
cat << 'EOF' > "$WEB_DIR/app.py"
from flask import Flask, jsonify, render_template, abort
import subprocess
app = Flask(__name__)
ALLOWED_SERVICES =
