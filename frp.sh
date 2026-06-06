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
name = "failover-tcp"
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
    echo -e "${GREEN}[+] FRPC Configured.${NC}"
    read -p "Press Enter..."
}