#!/bin/bash
# =================================================================
#  KHALIFEH RATHOLE TUNNEL FOR X-UI (IRAN <-> KHAREJ WITH FIX PING)
# =================================================================

# بررسی دسترسی روت
if [[ $EUID -ne 0 ]]; then
   echo -e "\033[0;31m[-] Please run this script as root (sudo).\033[0m" 
   exit 1
fi

BASE_DIR="/opt/khalifeh_tunnel"
BIN_DIR="$BASE_DIR/bin"
CFG_DIR="$BASE_DIR/configs"

mkdir -p "$BIN_DIR" "$CFG_DIR"

# رنگ‌ها برای منو
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m'

# رفع تداخل فایروال اوبونتو ۲۴ و نصب ابزارها
install_dependencies() {
    echo -e "${YELLOW}[*] Installing system dependencies...${NC}"
    rm -f /etc/apt/sources.list.d/cloudflare*.list >/dev/null 2>&1
    apt update -y && apt install -y curl unzip wget jq net-tools sshpass ufw < /dev/null
}

# دانلود باینری رتهول متناسب با معماری
install_rathole() {
    if [ -f "$BIN_DIR/rathole" ]; then
        return
    fi
    install_dependencies
    echo -e "${YELLOW}[*] Downloading Rathole core...${NC}"
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then
        URL="https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-x86_64-unknown-linux-gnu.zip"
    else
        URL="https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-aarch64-unknown-linux-gnu.zip"
    fi
    
    curl -L "$URL" -o /tmp/rathole.zip
    unzip -o /tmp/rathole.zip -d /tmp/
    cp /tmp/rathole "$BIN_DIR/rathole"
    chmod +x "$BIN_DIR/rathole"
    rm -f /tmp/rathole.zip /tmp/rathole
}

# تابع کمکی برای پاک‌سازی تداخل پورت‌ها قبل از استارت سرویس جدید
clear_port_clash() {
    local target_port=$1
    local pid=$(netstat -lntp 2>/dev/null | grep ":$target_port " | awk '{print $7}' | cut -d'/' -f1)
    if [ ! -z "$pid" ]; then
        echo -e "${RED}[!] Port $target_port was busy by PID $pid. Killing it...${NC}"
        kill -9 $pid >/dev/null 2>&1
    fi
}

# ۱. پیکربندی سرور ایران (سرور ملو + دالان سوکس۵)
setup_iran() {
    install_rathole
    clear
    echo -e "${CYAN}=== CONFIGURING IRAN SERVER (SERVER MODE + FIX PING) ===${NC}"
    
    echo -e "${YELLOW}[*] Enter KHAREJ server details to establish the Fix-Ping Proxy corridor:${NC}"
    read -p "Enter KHAREJ Server IP: " kharej_ip
    read -p "Enter KHAREJ SSH Port [Default: 22]: " kharej_ssh_port
    kharej_ssh_port=${kharej_ssh_port:-22}
    read -p "Enter KHAREJ Root Password: " kharej_pass

    # ذخیره مشخصات ورود خارج برای پایداری پس از ریستارت ایران
    cat <<EOT > "$CFG_DIR/ssh_creds.conf"
KHAREJ_IP="$kharej_ip"
KHAREJ_PORT="$kharej_ssh_port"
KHAREJ_PASS="$kharej_pass"
EOT
    chmod 600 "$CFG_DIR/ssh_creds.conf"

    # ساخت رانر تونل SOCKS5 معکوس
    cat << 'RUNNER' > "$BIN_DIR/proxy_runner.sh"
#!/bin/bash
source /opt/khalifeh_tunnel/configs/ssh_creds.conf
exec /usr/bin/sshpass -p "$KHAREJ_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -N -D 127.0.0.1:1080 root@$KHAREJ_IP -p $KHAREJ_PORT
RUNNER
    chmod +x "$BIN_DIR/proxy_runner.sh"

    # ساخت سرویس سیستمی دالان پروکسی
    cat <<EOT > /etc/systemd/system/khalifeh-proxy.service
[Unit]
Description=Khalifeh Fix-Ping Proxy Corridor
After=network.target

[Service]
ExecStart=/bin/bash $BIN_DIR/proxy_runner.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOT

    systemctl daemon-reload
    systemctl enable --now khalifeh-proxy.service
    sleep 2

    # ایجاد فایل محیطی پروکسی برای رتهول سرور ایران
    cat <<EOT > "$CFG_DIR/proxy_env.conf"
http_proxy=socks5://127.0.0.1:1080
https_proxy=socks5://127.0.0.1:1080
all_proxy=socks5://127.0.0.1:1080
HTTP_PROXY=socks5://127.0.0.1:1080
HTTPS_PROXY=socks5://127.0.0.1:1080
EOT

    echo -e "\n${CYAN}--------------------------------------------------------${NC}"
    read -p "Enter a Port for Tunnel Connection [Default: 2333]: " bind_port
    bind_port=${bind_port:-2333}
    
    # باز کردن پورت بایند اصلی در فایروال ایران
    ufw allow $bind_port/tcp >/dev/null 2>&1
    clear_port_clash $bind_port

    echo -e "${YELLOW}[*] Enter X-UI Inbound Ports (separated by comma, e.g., 8443,46701):${NC}"
    read -p "Ports: " ports_input
    
    token=$(openssl rand -hex 16)
    
    cat <<EOT > "$CFG_DIR/rathole-server.toml"
[server]
bind_addr = "0.0.0.0:$bind_port"
default_token = "$token"

[server.transport]
type = "tcp"
EOT

    # حل باینگ حلقه فور و ایجاد خدمات رتهول
    IFS=' ' read -r -a ports_array <<< "$(echo "$ports_input" | tr ',' ' ')"
    for p in "${ports_array[@]}"; do
        p=$(echo $p | xargs)
        if [ ! -z "$p" ]; then
            ufw allow $p/tcp >/dev/null 2>&1
            clear_port_clash $p
            cat <<EOT >> "$CFG_DIR/rathole-server.toml"

[server.services.port_$p]
bind_addr = "0.0.0.0:$p"
EOT
        fi
    done

    # ایجاد سرویس سیستمی رتهول ایران
    cat <<EOT > /etc/systemd/system/khalifeh-tunnel.service
[Unit]
Description=Khalifeh Rathole Tunnel Server (IRAN)
After=network.target khalifeh-proxy.service

[Service]
EnvironmentFile=-/opt/khalifeh_tunnel/configs/proxy_env.conf
ExecStart=$BIN_DIR/rathole $CFG_DIR/rathole-server.toml
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOT

    systemctl daemon-reload
    systemctl enable --now khalifeh-tunnel.service
    ufw reload >/dev/null 2>&1

    clear
    echo -e "${GREEN}[+] Iran Server Configured & Tunnel Started!${NC}"
    echo -e "--------------------------------------------------------"
    echo -e "${CYAN}👉 CRITICAL DATA FOR YOUR KHAREJ SERVER:${NC}"
    echo -e "${YELLOW}Iran Bind Port:${NC}  $bind_port"
    echo -e "${YELLOW}Secure Token:${NC}    $token"
    echo -e "${YELLOW}Ports Copied:${NC}    $ports_input"
    echo -e "--------------------------------------------------------"
    read -p "Copy these details, then press Enter to return to menu..."
}

# ۲. پیکربندی سرور خارج (کلاینت مود)
setup_kharej() {
    install_rathole
    clear
    echo -e "${CYAN}=== CONFIGURING KHAREJ SERVER (CLIENT MODE) ===${NC}"
    read -p "Enter Iran Server IP: " iran_ip
    read -p "Enter Iran Tunnel Bind Port [Default: 2333]: " bind_port
    bind_port=${bind_port:-2333}
    read -p "Enter Secure Token (generated on Iran Server): " token
    
    echo -e "${YELLOW}[*] Enter the EXACT same Inbound Ports you entered on Iran Server (separated by comma):${NC}"
    read -p "Ports: " ports_input

    # فایروال خارج برای پورت ارتباطی تانل
    ufw allow $bind_port/tcp >/dev/null 2>&1

    cat <<EOT > "$CFG_DIR/rathole-client.toml"
[client]
remote_addr = "$iran_ip:$bind_port"
default_token = "$token"

[client.transport]
type = "tcp"
EOT

    IFS=' ' read -r -a ports_array <<< "$(echo "$ports_input" | tr ',' ' ')"
    for p in "${ports_array[@]}"; do
        p=$(echo $p | xargs)
        if [ ! -z "$p" ]; then
            ufw allow $p/tcp >/dev/null 2>&1
            cat <<EOT >> "$CFG_DIR/rathole-client.toml"

[client.services.port_$p]
local_addr = "127.0.0.1:$p"
EOT
        fi
    done

    cat <<EOT > /etc/systemd/system/khalifeh-tunnel.service
[Unit]
Description=Khalifeh Rathole Tunnel Client (KHAREJ)
After=network.target

[Service]
ExecStart=$BIN_DIR/rathole $CFG_DIR/rathole-client.toml
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOT

    systemctl daemon-reload
    systemctl enable --now khalifeh-tunnel.service
    ufw reload >/dev/null 2>&1

    clear
    echo -e "${GREEN}[+] Kharej Server Tunnel Deployed and Connected Successfully!${NC}"
    read -p "Press Enter to return..."
}

# ۳. ویرایش و تغییر مشخصات پورت‌ها / تونل‌های قبلی
edit_tunnel() {
    clear
    echo -e "${YELLOW}=== EDIT/RECONFIGURE EXISTING TUNNEL ===${NC}"
    echo "This will stop current services and let you enter new ports/configs."
    read -p "Are you sure you want to reconfigure? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        systemctl stop khalifeh-tunnel.service khalifeh-proxy.service >/dev/null 2>&1
        echo -e "${GREEN}[*] Previous sessions stopped. Please choose Option 1 or 2 from main menu to overwrite.${NC}"
    else
        echo -e "${RED}[*] Cancelled.${NC}"
    fi
    sleep 2
}

# پاک‌سازی کامل سرویس‌ها
stop_all() {
    systemctl stop khalifeh-tunnel.service khalifeh-proxy.service >/dev/null 2>&1
    systemctl disable khalifeh-tunnel.service khalifeh-proxy.service >/dev/null 2>&1
    rm -f /etc/systemd/system/khalifeh-tunnel.service /etc/systemd/system/khalifeh-proxy.service
    systemctl daemon-reload
    echo -e "${RED}[-] All Khalifeh Tunnel services uninstalled completely.${NC}"
    sleep 2
}

# منوی اصلی اسکریپت
while true; do
    clear
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${GREEN}      KHALIFEH RATHOLE TUNNEL (WITH PROXY CORRIDOR)  ${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo "1) Setup IRAN Server (Tunnel Server + Fix Ping via Kharej)"
    echo "2) Setup KHAREJ Server (Tunnel Client Mode)"
    echo "3) Edit / Reconfigure Existing Tunnel Ports"
    echo "4) Check Tunnel Live Status / Logs"
    echo "5) Completely Wipe/Stop All Services"
    echo "0) Exit"
    echo "--------------------------------------------------"
    read -p "Please select an option: " opt
    
    case $opt in
        1) setup_iran ;;
        2) setup_kharej ;;
        3) edit_tunnel ;;
        4) clear; echo "=== RATHOLE LOGS ==="; journalctl -u khalifeh-tunnel.service -n 25 --no-pager; echo -e "\n=== PROXY LOGS ==="; journalctl -u khalifeh-proxy.service -n 15 --no-pager; read -p "Press Enter..." ;;
        5) stop_all ;;
        0) exit 0 ;;
        *) echo "Invalid option!" && sleep 1 ;;
    esac
done
