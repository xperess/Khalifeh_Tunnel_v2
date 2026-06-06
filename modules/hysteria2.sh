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
