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

# رنگ‌ها برای زیبایی منو
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m'

# ۱. دانلود باینری رتهول متناسب با معماری سرور
install_rathole() {
    if [ -f "$BIN_DIR/rathole" ]; then
        return
    fi
    echo -e "${YELLOW}[*] Installing dependencies and Rathole core...${NC}"
    rm -f /etc/apt/sources.list.d/cloudflare*.list >/dev/null 2>&1
    apt update -y && apt install -y curl unzip wget jq net-tools sshpass < /dev/null
    
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

# ۲. پیکربندی سرور ایران + ایجاد دالان پروکسی از سرور خارج
setup_iran() {
    install_rathole
    clear
    echo -e "${CYAN}=== CONFIGURING IRAN SERVER (SERVER MODE + FIX PING) ===${NC}"
    
    # الف) ایجاد دالان پروکسی معکوس به سمت سرور خارج
    echo -e "${YELLOW}[*] Enter KHAREJ server details to route tunnel core through it:${NC}"
    read -p "Enter KHAREJ Server IP: " kharej_ip
    read -p "Enter KHAREJ SSH Port [Default: 22]: " kharej_ssh_port
    kharej_ssh_port=${kharej_ssh_port:-22}
    read -p "Enter KHAREJ Root Password: " kharej_pass

    # ذخیره مشخصات به صورت امن
    cat <<EOT > "$CFG_DIR/ssh_creds.conf"
KHAREJ_IP="$kharej_ip"
KHAREJ_PORT="$kharej_ssh_port"
KHAREJ_PASS="$kharej_pass"
EOT
    chmod 600 "$CFG_DIR/ssh_creds.conf"

    # ساخت رانر پروکسی سوکس۵ روی پورت ۱۰۸۰ سرور ایران
    cat << 'RUNNER' > "$BIN_DIR/proxy_runner.sh"
#!/bin/bash
source /opt/khalifeh_tunnel/configs/ssh_creds.conf
exec /usr/bin/sshpass -p "$KHAREJ_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -N -D 127.0.0.1:1080 root@$KHAREJ_IP -p $KHAREJ_PORT
RUNNER
    chmod +x "$BIN_DIR/proxy_runner.sh"

    # سرویس سیستمی دالان پروکسی
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

    # متغیرهای محیطی پروکسی برای استفاده اختصاصی دیمن رتهول ایران
    cat <<EOT > "$CFG_DIR/proxy_env.conf"
http_proxy=socks5://127.0.0.1:1080
https_proxy=socks5://127.0.0.1:1080
all_proxy=socks5://127.0.0.1:1080
HTTP_PROXY=socks5://127.0.0.1:1080
HTTPS_PROXY=socks5://127.0.0.1:1080
EOT

    # ب) بخش تنظیمات رتهول سرور (ایران)
    echo -e "\n${CYAN}--------------------------------------------------------${NC}"
    read -p "Enter a Port for Tunnel Connection [Default: 2333]: " bind_port
    bind_port=${bind_port:-2333}
    
    echo -e "${YELLOW}[*] Enter X-UI Inbound Ports (separated by comma, e.g., 443,8080):${NC}"
    read -p "Ports: " ports_input
    
    token=$(openssl rand -hex 16)
    
    cat <<EOT > "$CFG_DIR/rathole-server.toml"
[server]
bind_addr = "0.0.0.0:$bind_port"
default_token = "$token"

[server.transport]
type = "tcp"
EOT

    IFS=' ' read -r -a ports_array <<< "$(echo "$ports_input" | tr ',' ' ')"
    for p in "${ports_array[@]}"; do
        p=$(echo $p | xargs)
        cat <<EOT >> "$CFG_DIR/rathole-server.toml"

[server.services.port_$p]
bind_addr = "0.0.0.0:$p"
EOT
    done

    # دیمن سیستم دی رتهول متصل به دالان پروکسی
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

    clear
    echo -e "${GREEN}[+] Iran Server Deployed, Fix-Ping Proxy Enabled & Tunnel Active!${NC}"
    echo -e "--------------------------------------------------------"
    echo -e "${CYAN}👉 DATA FOR YOUR KHAREJ SERVER CONFIGURATION:${NC}"
    echo -e "${YELLOW}Iran Tunnel Bind Port:${NC}  $bind_port"
    echo -e "${YELLOW}Secure Token:${NC}          $token"
    echo -e "${YELLOW}Ports to Forward:${
