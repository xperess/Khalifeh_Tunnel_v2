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
    echo -e "${GREEN}[+] Rathole Client Configured and Connected.${NC}"
    read -p "Press Enter..."
}