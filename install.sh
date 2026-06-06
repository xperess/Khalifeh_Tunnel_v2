#!/bin/bash

# =================================================================
#  KHALIFEH TUNNEL v2 (BUG-FIXED & ULTIMATE UNINSTALL EDITION)
# =================================================================

if [[ $EUID -ne 0 ]]; then
   echo "[-] Please run this script as root (sudo)." 
   exit 1
fi

BASE_DIR="/opt/khalifeh"
BIN_DIR="$BASE_DIR/bin"
CFG_DIR="$BASE_DIR/configs"
MOD_DIR="$BASE_DIR/modules"
WEB_DIR="$BASE_DIR/web"

# پاکسازی فضا و ایجاد ساختار پوشه‌ها با نام استاندارد modules
rm -rf "$BASE_DIR"
rm -f /usr/local/bin/khalifeh
mkdir -p "$BIN_DIR" "$CFG_DIR" "$MOD_DIR" "$WEB_DIR/templates"

echo "[*] Updating system and installing dependencies..."
apt update -y && apt install -y curl wget jq unzip openssl python3-flask python3-pip -y

ARCH=$(uname -m)

# 1. دانلود باینری‌ها
if [[ "$ARCH" == "x86_64" ]]; then
    R_URL="https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-x86_64-unknown-linux-gnu.zip"
    F_URL="https://github.com/fatedier/frp/releases/download/v0.61.2/frp_0.61.2_linux_amd64.tar.gz"
    H_URL="https://github.com/apernet/hysteria/releases/download/v2.6.1/hysteria-linux-amd64"
else
    R_URL="https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-aarch64-unknown-linux-gnu.zip"
    F_URL="https://github.com/fatedier/frp/releases/download/v0.61.2/frp_0.61.2_linux_arm64.tar.gz"
    H_URL="https://github.com/apernet/hysteria/releases/download/v2.6.1/hysteria-linux-arm64"
fi

echo "[*] Downloading binaries..."
curl -L "$R_URL" -o /tmp/rathole.zip && unzip -o /tmp/rathole.zip -d /tmp/ && cp /tmp/rathole "$BIN_DIR/"
curl -L "$F_URL" -o /tmp/frp.tar.gz && tar -xzf /tmp/frp.tar.gz -C /tmp/ && cp /tmp/frp*/frps /tmp/frp*/frpc "$BIN_DIR/"
curl -L "$H_URL" -o "$BIN_DIR/hysteria2"
chmod +x $BIN_DIR/*
rm -rf /tmp/rathole* /tmp/frp*

# =================================================================
# 2. تزریق کدهای ماژول‌ها بدون خطای سینتکس
# =================================================================

echo "[*] Deploying modules..."

# --- ماژول رتهول ---
cat > "$MOD_DIR/rathole.sh" << 'RATHOLE_EOF'
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

    IFS=' ' read -ra ADDR <<< "$(echo "$ports" | tr ',' ' ')"
    for p in "${ADDR[@]}"; do
        p=$(echo $p | xargs)
        cat <<EOF >> /opt/khalifeh/configs/rathole-server.toml
[server.services.port_$p]
bind_addr = "0.0.0.0:$p"
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

    IFS=' ' read -ra ADDR <<< "$(echo "$ports" | tr ',' ' ')"
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
    echo -e "${GREEN}[+] Rathole Client Connected and Started.${NC}"
    read -p "Press Enter..."
}
RATHOLE_EOF

# --- ماژول اف‌آرپی ---
cat > "$MOD_DIR/frp.sh" << 'FRP_EOF'
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
    systemctl daemon-reload && systemctl enable frps
    echo -e "${GREEN}[+] FRPS Installed (Controlled by Failover Engine)${NC}"
    read -p "Press Enter..."
}

frp_kharej() {
    read -p "Enter Iran Server IP: " ip
    read -p "Enter FRP Server Port [Default: 7000]: " port
    port=${port:-7000}
    read -p "Enter Token: " token
    read -p "Enter single port to forward (e.g. 443): " p

    cat <<EOF > /opt/khalifeh/configs/frpc.toml
serverAddr = "$ip"
serverPort = $port
auth.method = "token"
auth.token = "$token"

[[proxies]]
name = "proxy-$p"
type = "tcp"
localIP = "127.0.0.1"
localPort = $p
remotePort = $p
EOF

    cat <<EOF > /etc/systemd/system/frpc.service
[Unit]
Description=FRP Client
After=network.target

[Service]
ExecStart=/opt/khalifeh/bin/frpc -c /opt/khalifeh/configs/frpc.toml
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable frpc
    echo -e "${GREEN}[+] FRPC Installed (Controlled by Failover Engine)${NC}"
    read -p "Press Enter..."
}
FRP_EOF

# --- ماژول هیستریا ۲ ---
cat > "$MOD_DIR/hysteria2.sh" << 'HYSTERIA_EOF'
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
    echo -e "${YELLOW}[!] Password: $password${NC}"
    read -p "Press Enter..."
}

hy_client() {
    read -p "Enter Server IP: " ip
    read -p "Enter Server Port: " port
    read -p "Enter Password: " pass

    cat <<EOF > /opt/khalifeh/configs/hysteria-client.yaml
server: $ip:$port
auth: $pass
tls:
  insecure: true
bandwidth:
  up: 100 mbps
  down: 100 mbps
EOF

    cat <<EOF > /etc/systemd/system/hysteria2-client.service
[Unit]
Description=Hysteria2 Client
After=network.target

[Service]
ExecStart=/opt/khalifeh/bin/hysteria2 client -c /opt/khalifeh/configs/hysteria-client.yaml
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable --now hysteria2-client
    echo -e "${GREEN}[+] Hysteria2 Client configured.${NC}"
    read -p "Press Enter..."
}
HYSTERIA_EOF

# --- اسکریپت فیل‌اور خودکار ---
cat > "$BASE_DIR/failover.sh" << 'FAILOVER_EOF'
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
FAILOVER_EOF

# =================================================================
# 3. ساخت هسته اصلی منو (core.sh) به همراه گزینه کامپلت حذف پروژه
# =================================================================

cat > "$BASE_DIR/core.sh" << 'CORE_EOF'
#!/bin/bash

BASE="/opt/khalifeh"
MOD="$BASE/modules"
CFG="$BASE/configs"

# لود کردن کاملاً امن ماژول‌ها پس از رفع تداخل سینتکس
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
    echo -e "${CYAN}    KHALIFEH TUNNEL v2 (PRODUCTION)       ${NC}"
    echo -e "${MAGENTA}==========================================${NC}"
}

health_check() {
    banner
    echo -e "${YELLOW}[*] Checking System Services Status:${NC}\n"
    for svc in khalifeh-rathole-server khalifeh-rathole-client frps frpc hysteria2 hysteria2-client khalifeh-web khalifeh-failover; do
        if systemctl list-units --full -all 2>/dev/null | grep -q "$svc"; then
            STATUS=$(systemctl is-active "$svc" 2>/dev/null)
            if [[ "$STATUS" == "active" ]]; then
                echo -e " ● $svc : ${GREEN}RUNNING${NC}"
            else
                echo -e " ● $svc : ${RED}STOPPED${NC}"
            fi
        else
            echo -e " ● $svc : ${YELLOW}Not Configured${NC}"
        fi
    done
    read -p "Press Enter to return..."
}

sys_optimize() {
    banner
    echo -e "${GREEN}[*] Optimizing Linux Network Stack for Tunneling...${NC}"
    cat <<EOF > /etc/sysctl.d/99-khalifeh.conf
fs.file-max = 65535
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 10000
net.core.somaxconn = 4096
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_congestion_control = bbr
EOF
    sysctl --system >/dev/null 2>&1
    echo -e "${GREEN}[+] BBR and network limits optimized successfully.${NC}"
    read -p "Press Enter..."
}

uninstall_project() {
    banner
    echo -e "${RED}[!] WARNING: This will completely wipe the project, configs, and all services from this server.${NC}"
    read -p "Are you absolutely sure? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        echo "[*] Deactivating services..."
        for svc in khalifeh-rathole-server khalifeh-rathole-client frps frpc hysteria2 hysteria2-client khalifeh-web khalifeh-failover; do
            systemctl stop "$svc" >/dev/null 2>&1
            systemctl disable "$svc" >/dev/null 2>&1
            rm -f /etc/systemd/system/"$svc".service
        done
        systemctl daemon-reload
        
        echo "[*] Cleaning directory workspace..."
        rm -rf /opt/khalifeh
        rm -f /usr/local/bin/khalifeh
        rm -f /etc/sysctl.d/99-khalifeh.conf
        
        echo -e "${GREEN}[+] Khalifeh Tunnel infrastructure has been completely uninstalled.${NC}"
        exit 0
    else
        echo "[*] Uninstall aborted."
        sleep 1
    fi
}

main_menu() {
    while true; do
        banner
        echo -e "1) ${CYAN}Rathole Module (Primary Tunnel)${NC}"
        echo -e "2) ${CYAN}FRP Module (Backup Route)${NC}"
        echo -e "3) ${CYAN}Hysteria2 Module (Obfuscation UDP)${NC}"
        echo "4) Status All"
        echo "5) Health Check"
        echo "6) Network Optimize"
        echo -e "9) ${RED}Uninstall Infrastructure (Wipe All)${NC}"
        echo "0) Exit"
        echo "------------------------------------------"
        read -p "Select: " choice
        case $choice in
            1) declare -f rathole_menu >/dev/null && rathole_menu || (echo -e "${RED}Rathole module not loaded${NC}" && read -p "Press Enter...");;
            2) declare -f frp_menu >/dev/null && frp_menu || (echo -e "${RED}FRP module not loaded${NC}" && read -p "Press Enter...");;
            3) declare -f hysteria_menu >/dev/null && hysteria_menu || (echo -e "${RED}Hysteria2 module not loaded${NC}" && read -p "Press Enter...");;
            4) health_check ;;
            5) health_check ;;
            6) sys_optimize ;;
            9) uninstall_project ;;
            0) exit 0 ;;
            *) echo "Invalid option." && sleep 1 ;;
        esac
    done
}
CORE_EOF

# --- فایل‌های وب پنل ---
cat > "$WEB_DIR/app.py" << 'WEB_EOF'
from flask import Flask, jsonify, render_template, abort
import subprocess

app = Flask(__name__)
ALLOWED_SERVICES = ["khalifeh-rathole-server", "khalifeh-rathole-client", "frps", "frpc", "hysteria2", "hysteria2-client", "khalifeh-failover"]

def get_status(name):
    try:
        res = subprocess.run(["systemctl", "is-active", name], capture_output=True, text=True)
        return res.stdout.strip()
    except:
        return "inactive"

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/api/status")
def status():
    return jsonify({s: get_status(s) for s in ALLOWED_SERVICES})

@app.route("/api/<action>/<name>")
def manage(action, name):
    if name not in ALLOWED_SERVICES or action not in ["start", "stop", "restart"]:
        abort(400)
    try:
        subprocess.run(["systemctl", action, name], check=True)
        return jsonify({"status": "success", "service": name, "action": action})
    except:
        return jsonify({"status": "failed"}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
WEB_EOF

cat > "$WEB_DIR/templates/index.html" << 'HTML_EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Khalifeh Tunnel Panel</title>
    <style>
        body { background: #0c0f12; color: #4af626; font-family: 'Courier New', monospace; padding: 30px; }
        .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 20px; }
        .box { background: #131a22; border: 1px solid #1f2d3d; padding: 20px; border-radius: 6px; }
        .active { color: #00ff88; font-weight: bold; }
        .inactive { color: #ff3366; font-weight: bold; }
        button { background: #1a2432; color: #4af626; border: 1px solid #4af626; padding: 6px 12px; cursor: pointer; margin-right: 5px;}
    </style>
</head>
<body>
    <h2>🔥 KHALIFEH TUNNEL WEB DASHBOARD</h2>
    <div class="grid" id="container"></div>
    <script>
        async function fetchStatus() {
            let r = await fetch('/api/status');
            let data = await r.json();
            let html = '';
            for (let svc in data) {
                let cls = data[svc] === 'active' ? 'active' : 'inactive';
                html += `<div class="box">
                    <h3>📌 ${svc.replace('khalifeh-', '')}</h3>
                    <p>Status: <span class="${cls}">${data[svc].toUpperCase()}</span></p>
                    <button onclick="control('${svc}','start')">START</button>
                    <button onclick="control('${svc}','stop')">STOP</button>
                </div>`;
            }
            document.getElementById('container').innerHTML = html;
        }
        async function control(name, act) { await fetch(`/api/${act}/${name}`); fetchStatus(); }
        setInterval(fetchStatus, 4000); fetchStatus();
    </script>
</body>
</html>
HTML_EOF

# تنظیم دسترسی‌ها
chmod +x /opt/khalifeh/modules/*.sh
chmod +x /opt/khalifeh/failover.sh
chmod +x /opt/khalifeh/core.sh

# ایجاد لانچر خط فرمان
cat > /usr/local/bin/khalifeh << 'LAUNCHER_EOF'
#!/bin/bash
source /opt/khalifeh/core.sh
main_menu
LAUNCHER_EOF
chmod +x /usr/local/bin/khalifeh

# ساخت سرویس دیمن وب پنل و فیل‌اور
cat > /etc/systemd/system/khalifeh-web.service << EOF
[Unit]
Description=Khalifeh Web Dashboard
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
Description=Khalifeh Failover Engine
After=network.target
[Service]
ExecStart=/bin/bash $BASE_DIR/failover.sh
Restart=always
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now khalifeh-web khalifeh-failover

clear
echo -e "\033[0;32m[+] Installation Complete Successfully!\033[0m"
echo -e "[*] Type \033[1;36mkhalifeh\033[0m anywhere to launch the dashboard menu."
