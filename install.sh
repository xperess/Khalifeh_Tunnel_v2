#!/bin/bash
# =================================================================
#  KHALIFEH TUNNEL v2 - MASTER INSTALLER (GITHUB READY)
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

# پاکسازی محیط‌های قدیمی برای جلوگیری از تداخل کدهای خراب قبلی
rm -rf "$BASE_DIR"
rm -f /usr/local/bin/khalifeh

# ایجاد ساختار پوشه‌ای استاندارد
mkdir -p "$BIN_DIR" "$CFG_DIR" "$MOD_DIR" "$WEB_DIR/templates"

echo "[*] Updating system packages and installing core dependencies..."
apt update -y && apt install -y curl wget jq unzip openssl python3-flask python3-pip -y

ARCH=$(uname -m)

# دانلود باینری‌های پایدار متناسب با معماری سیستم
echo "[*] Downloading core tunnel binaries..."
if [[ "$ARCH" == "x86_64" ]]; then
    R_URL="https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-x86_64-unknown-linux-gnu.zip"
    F_URL="https://github.com/fatedier/frp/releases/download/v0.61.2/frp_0.61.2_linux_amd64.tar.gz"
    H_URL="https://github.com/apernet/hysteria/releases/download/v2.6.1/hysteria-linux-amd64"
else
    R_URL="https://github.com/rapiz1/rathole/releases/download/v0.5.0/rathole-aarch64-unknown-linux-gnu.zip"
    F_URL="https://github.com/fatedier/frp/releases/download/v0.61.2/frp_0.61.2_linux_arm64.tar.gz"
    H_URL="https://github.com/apernet/hysteria/releases/download/v2.6.1/hysteria-linux-arm64"
fi

curl -L "$R_URL" -o /tmp/rathole.zip && unzip -o /tmp/rathole.zip -d /tmp/ && cp /tmp/rathole "$BIN_DIR/"
curl -L "$F_URL" -o /tmp/frp.tar.gz && tar -xzf /tmp/frp.tar.gz -C /tmp/ && cp /tmp/frp*/frps /tmp/frp*/frpc "$BIN_DIR/"
curl -L "$H_URL" -o "$BIN_DIR/hysteria2"
chmod +x $BIN_DIR/*
rm -rf /tmp/rathole* /tmp/frp*

# کپی کردن فایل‌های پروژه از دایرکتوری جاری به پوشه سرور
# (اگر فایل‌ها در پوشه جاری موجود باشند کپی می‌شوند؛ در غیر این صورت فیلدها دانلود/تولید می‌شوند)
if [ -d "./modules" ]; then
    cp -r ./modules/* "$MOD_DIR/"
    cp ./core.sh "$BASE_DIR/"
    cp ./failover.sh "$BASE_DIR/"
    cp ./app.py "$WEB_DIR/"
    cp ./templates/index.html "$WEB_DIR/templates/" 2>/dev/null || cp ./index.html "$WEB_DIR/templates/"
else
    echo "[-] Local project files not found. Please run this inside the extracted project folder."
    exit 1
fi

# تنظیم پرمیشن‌های دسترسی لینوکس
chmod +x "$BASE_DIR/core.sh"
chmod +x "$BASE_DIR/failover.sh"
chmod +x "$MOD_DIR"/*.sh

# ساخت شورت‌کات سراسری دستور khalifeh
cat > /usr/local/bin/khalifeh << 'EOF'
#!/bin/bash
source /opt/khalifeh/core.sh
main_menu
EOF
chmod +x /usr/local/bin/khalifeh

# ساخت سرویس‌های دیمن وب‌پنل و فیل‌اور خودکار
cat > /etc/systemd/system/khalifeh-web.service << EOF
[Unit]
Description=Khalifeh Tunnel Web Panel Service
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
Description=Khalifeh Tunnel Smart Failover Monitor Engine
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
echo -e "\033[0;32m[+] Framework Deployed cleanly!\033[0m"
echo -e "[*] Type \033[1;36mkhalifeh\033[0m to launch the panel dashboard."
