#!/bin/bash

# ==========================================
#  KHALIFEH TUNNEL v2 (PRODUCTION READY)
# ==========================================

# بررسی دسترسی روت
if [[ $EUID -ne 0 ]]; then
   echo "[-] Please run this script as root (sudo)." 
   exit 1
fi

BASE_DIR="/opt/khalifeh"
BIN_DIR="$BASE_DIR/bin"
CFG_DIR="$BASE_DIR/configs"
WEB_DIR="$BASE_DIR/web"

# پاکسازی و ایجاد ساختار پوشه‌ها
mkdir -p "$BIN_DIR" "$CFG_DIR" "$WEB_DIR/templates" "$BASE_DIR/modules"

echo "[*] Updating system and installing dependencies..."
apt update -y && apt install -y curl wget jq unzip openssl python3-flask python3-pip -y

ARCH=$(uname -m)

# ==========================================
# 1. بخش دانلود و نصب ابزارها
# ==========================================
install_binaries() {
    # نصب Rathole
    if [[ "$ARCH" == "x86_64" ]]; then
        R_URL="https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-x86_64-unknown-linux-gnu.zip"
        F_URL="https://github.com/fatedier/frp/releases/download/v0.61.2/frp_0.61.2_linux_amd64.tar.gz"
        H_URL="https://github.com/apernet/hysteria/releases/download/v2.6.1/hysteria-linux-amd64"
    else
        R_URL="https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-aarch64-unknown-linux-gnu.zip"
        F_URL="https://github.com/fatedier/frp/releases/download/v0.61.2/frp_0.61.2_linux_arm64.tar.gz"
        H_URL="https://github.com/apernet/hysteria/releases/download/v2.6.1/hysteria-linux-arm64"
    fi

    echo "[*] Downloading Rathole, FRP, and Hysteria2..."
    # Rathole
    curl -L "$R_URL" -o /tmp/rathole.zip && unzip -o /tmp/rathole.zip -d /tmp/ && cp /tmp/rathole "$BIN_DIR/"
    # FRP
    curl -L "$F_URL" -o /tmp/frp.tar.gz && tar -xzf /tmp/frp.tar.gz -C /tmp/ && cp /tmp/frp*/frps /tmp/frp*/frpc "$BIN_DIR/"
    # Hysteria2
    curl -L "$H_URL" -o "$BIN_DIR/hysteria2"
    
    chmod +x $BIN_DIR/*
    rm -rf /tmp/rathole* /tmp/frp*
    echo "[+] All binaries installed successfully."
}

# ==========================================
# 2. تولید اسکریپت لایه مانیتورینگ و Failover خودکار
# ==========================================
create_failover_engine() {
cat > "$BASE_DIR/failover.sh" << 'EOF'
#!/bin/bash
check_svc() { systemctl is-active "$1" >/dev/null 2>&1; echo $?; }

echo "[*] Starting Auto Failover Engine..."
while true; do
    # بررسی وضعیت روت اصلی (Rathole)
    R_SERVER=$(check_svc khalifeh-rathole-server)
    R_CLIENT=$(check_svc khalifeh-rathole-client)
    
    if [[ $R_SERVER -eq 0 || $R_CLIENT -eq 0 ]]; then
        # اگر مسیر اصلی وصل است، مسیرهای فرعی را خاموش کن تا پهنای باند هدر نرود
        systemctl stop frps frpc hysteria2 hysteria2-client >/dev/null 2>&1
        sleep 10
        continue
    fi
    
    # اگر مسیر اصلی قطع شد، سوئیچ به FRP
    if [[ $(systemctl list-units --full -all | grep -q "frp") ]]; then
        if [[ $(check_svc frps) -ne 0 && $(check_svc frpc) -ne 0 ]]; then
            echo "[!] Rathole DOWN. Activating FRP Backup..."
            systemctl start frps frpc >/dev/null 2>&1
        fi
    fi
    sleep 5
done
EOF
chmod +x "$BASE_DIR/failover.sh"
}

# ==========================================
# 3. توسعه پنل وب ایمن (Flask)
# ==========================================
create_web_panel() {
# ایجاد فایل پایتون بک‌اند به صورت ایمن
cat > "$WEB_DIR/app.py" << 'EOF'
from flask import Flask, jsonify, render_template, abort
import subprocess
import re

app = Flask(__name__)
ALLOWED_SERVICES = ["khalifeh-rathole-server", "khalifeh-rathole-client", "frps", "frpc", "hysteria2", "hysteria2-client"]

def get_status(name):
    try:
        output = subprocess.check_output(["systemctl", "is-active", name], stderr=subprocess.STDOUT).decode().strip()
        return output
    except:
        return "inactive"

@app.route("/")
def index(): return render_template("index.html")

@app.route("/api/status")
def status():
    return jsonify({s: get_status(s) for s in ALLOWED_SERVICES})

@app.route("/api/<action>/<name>")
def manage_service(action, name):
    if name not in ALLOWED_SERVICES or action not in ["start", "stop", "restart"]:
        abort(400, "Invalid Action or Service Name")
    
    # اجرای کاملا ایمن بدون آسیب‌پذیری Command Injection
    try:
        subprocess.run(["systemctl", action, name], check=True)
        return jsonify({"status": f"{action}ed", "service": name})
    except subprocess.CalledProcessError:
        return jsonify({"status": "failed", "service": name}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
EOF

# فرانت‌اند پنل مدیریت
cat > "$WEB_DIR/templates/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Khalifeh Tunnel Panel</title>
    <style>
        body { background:#111; color:#0f0; font-family:monospace; padding:20px; }
        .box { padding:15px; border:1px solid #0f0; margin:10px 0; background:#1a1a1a; }
        button { background:#222; color:#0f0; border:1px solid #0f0; padding:5px 10px; cursor:pointer; margin-right:5px;}
        button:hover { background:#0f0; color:#111; }
        .active { color: #00ff00; font-weight: bold; }
        .inactive { color: #ff0000; font-weight: bold; }
    </style>
</head>
<body>
<h2>🔥 Khalifeh Tunnel Control Panel</h2>
<div id="status">Loading services status...</div>
<script>
async function loadStatus() {
    let res = await fetch('/api/status');
    let data = await res.json();
    let html = "";
    for (let k in data) {
        let statusClass = data[k] === "active" ? "active" : "inactive";
        html += `
        <div class="box">
            <b>${k}</b> : <span class="${statusClass}">${data[k]}</span>
            <br><br>
            <button onclick="control('${k}', 'start')">Start</button>
            <button onclick="control('${k}', 'stop')">Stop</button>
            <button onclick="control('${k}', 'restart')">Restart</button>
        </div>`;
    }
    document.getElementById("status").innerHTML = html;
}
async function control(name, action) {
    await fetch(`/api/${action}/${name}`);
    loadStatus();
}
setInterval(loadStatus, 3000);
loadStatus();
</script>
</body>
</html>
EOF
}

# ==========================================
# 4. ساخت سرویس‌های Systemd
# ==========================================
create_systemd_services() {
    # سرویس پنل وب
    cat > /etc/systemd/system/khalifeh-web.service << EOF
[Unit]
Description=Khalifeh Web Dashboard
After=network.target
[Service]
WorkingDirectory=$WEB_DIR
ExecStart=/usr/bin/python3 app.py
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

    # سرویس فیل‌اور خودکار
    cat > /etc/systemd/system/khalifeh-failover.service << EOF
[Unit]
Description=Khalifeh Failover Engine
After=network.target
[Service]
ExecStart=/bin/bash $BASE_DIR/failover.sh
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable khalifeh-web.service khalifeh-failover.service
    systemctl start khalifeh-web.service khalifeh-failover.service
}

# ==========================================
# 5. پیکربندی هوشمند نقش سرور (ایران / خارج)
# ==========================================
configure_role() {
    echo "------------------------------------------"
    echo "Select the role of this server:"
    echo "1) IRAN (Server / Destination)"
    echo "2) KHAREJ (Client / Origin)"
    read -p "Choice [1-2]: " ROLE
    
    if [[ "$ROLE" == "1" ]]; then
        # کانفیگ ایران (Rathole Server & FRPS)
        read -p "Enter Tunnel Port [default 2333]: " TPORT
        TPORT=${TPORT:-2333}
        read -p "Enter Service Ports to open in Iran (comma-separated, e.g 443,80): " PORTS
        
        TOKEN=$(openssl rand -hex 16)
        
        # Rathole Server Config
        cat > "$CFG_DIR/rathole-server.toml" << EOF
[server]
bind_addr = "0.0.0.0:$TPORT"
default_token = "$TOKEN"
[server.transport]
type = "tcp"
EOF
        IFS=',' read -ra ADDR <<< "$PORTS"
        for p in "${ADDR[@]}"; do
            p=$(echo $p | xargs)
            cat >> "$CFG_DIR/rathole-server.toml" << EOF
[server.services.port$p]
bind_addr = "0.0.0.0:$p"
EOF
        done

        # FRPS Config (نسخه جدید سازگار با v0.61.2)
        cat > "$CFG_DIR/frps.toml" << EOF
bindPort = $((TPORT+1))
auth.method = "token"
auth.token = "$TOKEN"
EOF

        # ایجاد سرویس‌های لایه ایران
        cat > /etc/systemd/system/khalifeh-rathole-server.service << EOF
[Unit]
Description=Rathole Server
After=network.target
[Service]
ExecStart=$BIN_DIR/rathole $CFG_DIR/rathole-server.toml
Restart=always
[Install]
WantedBy=multi-user.target
EOF

        cat > /etc/systemd/system/frps.service << EOF
[Unit]
Description=FRP Server
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
        
        echo "=================================================="
        echo "[+] IRAN Server configured successfully!"
        echo "[!] Rathole Port: $TPORT | FRP Port: $((TPORT+1))"
        echo "[!] YOUR TOKEN: $TOKEN"
        echo "=================================================="

    elif [[ "$ROLE" == "2" ]]; then
        # کانفیگ خارج (Rathole Client & FRPC)
        read -p "Enter IRAN Server IP: " IRAN_IP
        read -p "Enter Iran Tunnel Port [default 2333]: " TPORT
        TPORT=${TPORT:-2333}
        read -p "Enter Token from Iran server: " TOKEN
        read -p "Enter local ports to forward (comma-separated, e.g 443,80): " PORTS
        
        # Rathole Client Config
        cat > "$CFG_DIR/rathole-client.toml" << EOF
[client]
remote_addr = "$IRAN_IP:$TPORT"
default_token = "$TOKEN"
[client.transport]
type = "tcp"
EOF
        IFS=',' read -ra ADDR <<< "$PORTS"
        for p in "${ADDR[@]}"; do
            p=$(echo $p | xargs)
            cat >> "$CFG_DIR/rathole-client.toml" << EOF
[client.services.port$p]
local_addr = "127.0.0.1:$p"
EOF
        done

        # FRPC Config (نسخه جدید سازگار با v0.61.2)
        cat > "$CFG_DIR/frpc.toml" << EOF
serverAddr = "$IRAN_IP"
serverPort = $((TPORT+1))
auth.method = "token"
auth.token = "$TOKEN"
EOF
        for p in "${ADDR[@]}"; do
            p=$(echo $p | xargs)
            cat >> "$CFG_DIR/frpc.toml" << EOF
[[proxies]]
name = "proxy-$p"
type = "tcp"
localIP = "127.0.0.1"
localPort = $p
remotePort = $p
EOF
        done

        # ایجاد سرویس‌های لایه خارج
        cat > /etc/systemd/system/khalifeh-rathole-client.service << EOF
[Unit]
Description=Rathole Client
After=network.target
[Service]
ExecStart=$BIN_DIR/rathole $CFG_DIR/rathole-client.toml
Restart=always
[Install]
WantedBy=multi-user.target
EOF

        cat > /etc/systemd/system/frpc.service << EOF
[Unit]
Description=FRP Client
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

        echo "=================================================="
        echo "[+] KHAREJ Client configured and started!"
        echo "=================================================="
    else
        echo "Invalid Selection."
        exit 1
    fi
}

# اجرای کل پروسه نصب
install_binaries
create_failover_engine
create_web_panel
create_systemd_services
configure_role

echo "[*] Web Panel Link: http://YOUR_SERVER_IP:8080"