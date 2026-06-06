#!/bin/bash

# =================================================================
#        KHALIFEH TUNNEL v2 (OFFICIAL ALL-IN-ONE FIX)
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

mkdir -p "$BIN_DIR" "$CFG_DIR" "$MOD_DIR" "$WEB_DIR/templates"

echo "[*] Installing system package dependencies..."
apt update -y && apt install -y curl wget jq unzip openssl python3-flask python3-pip -y

ARCH=$(uname -m)
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

echo "[*] Deploying full modular source code layers..."

# --- ۱. ساخت ماژول رتهول با بدنه کامل تابع ---
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

# --- ۲. ساخت ماژول اف‌آرپی با بدنه کامل تابع ---
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

# --- ۳. ساخت ماژول هیستریا با بدنه کامل تابع ---
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

# --- ۴. ساخت فایل بدنه اصلی منو core.sh ---
cat > "$BASE_DIR/core.sh" << 'CORE_EOF'
#!/bin/bash
BASE="/opt/khalifeh"
MOD="$BASE/modules"

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
    for svc in khalifeh-rathole-server khalifeh-rathole-client frps frpc hysteria2 hysteria2-client; do
        if systemctl list-units --full -all 2>/dev/null | grep -q "$svc"; then
            STATUS=$(systemctl is-active "$svc" 2>/dev/null)
            if [[ "$STATUS" == "active" ]]; then
                echo -e " ● $svc : ${GREEN}RUNNING (ONLINE)${NC}"
            else
                echo -e " ● $svc : ${RED}STOPPED (OFFLINE)${NC}"
            fi
        else
            echo -e " ● $svc : ${YELLOW}NOT INSTALLED${NC}"
        fi
    done
    read -p "Press Enter to return..."
}

main_menu() {
    while true; do
        banner
        echo "1) Rathole Module"
        echo "2) FRP Module"
        echo "3) Hysteria2 Module"
        echo "4) Status All"
        echo "0) Exit"
        echo "------------------------------------------"
        read -p "Select: " choice
        case $choice in
            1) declare -f rathole_menu >/dev/null && rathole_menu || (echo "Rathole module not loaded" && sleep 2);;
            2) declare -f frp_menu >/dev/null && frp_menu || (echo "FRP module not loaded" && sleep 2);;
            3) declare -f hysteria_menu >/dev/null && hysteria_menu || (echo "Hysteria2 module not loaded" && sleep 2);;
            4) status_all;;
            0) exit 0;;
            *) echo "Invalid option." && sleep 1;;
        esac
    done
}
CORE_EOF

chmod +x $BASE_DIR/*.sh
chmod +x $MOD_DIR/*.sh

# ایجاد لانچر خط فرمان گلوبال
cat > /usr/local/bin/khalifeh << 'LAUNCHER_EOF'
#!/bin/bash
source /opt/khalifeh/core.sh
main_menu
LAUNCHER_EOF
chmod +x /usr/local/bin/khalifeh

# بخش هوشمند تفکیک نقش معماری شبکه
echo "------------------------------------------------------"
echo "Select deployment role architecture for this machine:"
echo "1) IRAN Node (Server Endpoint Ingress)"
echo "2) KHAREJ Node (Client Tunnel Egress Destination)"
read -p "Role Assignment Selection [1-2]: " DeploymentRole

TOKEN=$(openssl rand -hex 16)

if [[ "$DeploymentRole" == "1" ]]; then
    read -p "Primary Tunnel Ingress Port [default 2333]: " TPORT
    TPORT=${TPORT:-2333}
    read -p "Target application ports to bridge (space separated, e.g., 443 80): " PORTS

    cat > "$CFG_DIR/frps.toml" << EOF
bindPort = $((TPORT+1))
auth.method = "token"
auth.token = "$TOKEN"
EOF

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

    systemctl daemon-reload
    systemctl enable khalifeh-rathole-server
    systemctl start khalifeh-rathole-server
    
    clear
    echo "=========================================================="
    echo -e "\033[0;32m[+] IRAN TUNNEL INSTANCE READY\033[0m"
    echo "Rathole Core Ingress Port: $TPORT"
    echo "Generated Security Token: $TOKEN"
    echo "=========================================================="
else
    # کانفیگ سمت خارج
    read -p "Enter Target Remote IRAN IP: " IRAN_IP
    read -p "Enter Iran Ingress Port [default 2333]: " TPORT
    TPORT=${TPORT:-2333}
    read -p "Enter Security Token copied from Iran Server: " TOKEN
    read -p "Local ports to route and map (space separated, e.g., 443 80): " PORTS

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

    systemctl daemon-reload
    systemctl enable khalifeh-rathole-client
    systemctl start khalifeh-rathole-client
    
    clear
    echo "=========================================================="
    echo -e "\033[0;32m[+] KHAREJ TUNNEL INSTANCE CONNECTED\033[0m"
    echo "=========================================================="
fi

hash -r
echo "[*] Type 'khalifeh' anywhere in your terminal to start management panel."
