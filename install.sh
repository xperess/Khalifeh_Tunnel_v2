#!/bin/bash

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

# ایجاد دقیق پوشه با نام درست و نهایی modules
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

echo "[*] Downloading stable binaries..."
curl -L "$R_URL" -o /tmp/rathole.zip && unzip -o /tmp/rathole.zip -d /tmp/ && cp /tmp/rathole "$BIN_DIR/"
curl -L "$F_URL" -o /tmp/frp.tar.gz && tar -xzf /tmp/frp.tar.gz -C /tmp/ && cp /tmp/frp*/frps /tmp/frp*/frpc "$BIN_DIR/"
curl -L "$H_URL" -o "$BIN_DIR/hysteria2"
chmod +x $BIN_DIR/*
rm -rf /tmp/rathole* /tmp/frp*

# ساخت اسکریپت‌های زیرمجموعه در پوشه یکتا و بدون غلط modules
echo "[*] Injecting modular structural codes..."

# [تزریق کدهای بخش ۱ الی ۷ به درون مسیر فایل‌های فیزیکی]
cat > "$MOD_DIR/rathole.sh" << 'EOF'
# (کدهای ماژول رتهول بخش ۲ به طور کامل اینجا قرار می‌گیرد)
EOF

cat > "$MOD_DIR/frp.sh" << 'EOF'
# (کدهای ماژول اف‌آرپی بخش ۳ به طور کامل اینجا قرار می‌گیرد)
EOF

cat > "$MOD_DIR/hysteria2.sh" << 'EOF'
# (کدهای ماژول هیستریا بخش ۴ به طور کامل اینجا قرار می‌گیرک)
EOF

cat > "$BASE_DIR/core.sh" << 'EOF'
# (کدهای بدنه اصلی بخش ۱ اینجا قرار می‌گیرد)
EOF

cat > "$BASE_DIR/failover.sh" << 'EOF'
# (کدهای مانیتورینگ بخش ۵ اینجا قرار می‌گیرد)
EOF

cat > "$WEB_DIR/app.py" << 'EOF'
# (کدهای بک‌اند پایتون بخش ۶ اینجا قرار می‌گیرد)
EOF

cat > "$WEB_DIR/templates/index.html" << 'EOF'
# (کدهای فرانت‌اند بخش ۷ اینجا قرار می‌گیرد)
EOF

chmod +x $BASE_DIR/*.sh
chmod +x $MOD_DIR/*.sh

# ایجاد لانچر ترمینال
cat > /usr/local/bin/khalifeh << 'LAUNCHER_EOF'
#!/bin/bash
source /opt/khalifeh/core.sh
main_menu
LAUNCHER_EOF
chmod +x /usr/local/bin/khalifeh

# راه‌اندازی سرویس‌های سیستمی مانیتورینگ و وب
cat > /etc/systemd/system/khalifeh-web.service << EOF
[Unit]
Description=Khalifeh Web Dashboard Daemon
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
Description=Khalifeh Intelligent Failover Core
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

# پیکربندی اختصاصی معماری شبکه بر اساس انتخاب کاربر
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
