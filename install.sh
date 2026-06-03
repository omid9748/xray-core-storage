#!/bin/bash

# Colors for terminal output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Ubuntu System-wide Proxy Installer ===${NC}"

# 1. Create directory
mkdir -p /opt/xray
cd /opt/xray

# 2. Check for xray.zip
if [ ! -f /opt/xray/xray.zip ]; then
    echo -e "${RED}[-] Error: xray.zip not found in /opt/xray/${NC}"
    echo -e "${GREEN}[*] Please upload Xray-linux-64.zip as 'xray.zip' to /opt/xray/ first.${NC}"
    exit 1
fi

# 3. Extract core using Python
echo -e "${GREEN}[*] Extracting Xray core...${NC}"
python3 -m zipfile -e xray.zip .

# Move files if extracted into a subfolder
if [ -d /opt/xray/Xray-linux-64 ]; then
    mv /opt/xray/Xray-linux-64/* /opt/xray/
    rm -rf /opt/xray/Xray-linux-64 /opt/xray/__MACOSX
fi

rm -f xray.zip
chmod +x /opt/xray/xray 2> /dev/null

# 4. Get JSON config from user
echo -e "${GREEN}[?] Please paste your complete Xray JSON config below:${NC}"
echo -e "${RED}(Note: Paste the JSON, press Enter, then press CTRL+D to save)${NC}"

USER_CONFIG=$(cat)

if [ -z "$USER_CONFIG" ]; then
    echo -e "${RED}[-] Error: Config cannot be empty!${NC}"
    exit 1
fi

echo "$USER_CONFIG" > /opt/xray/config.json

# 5. Create Systemd Service
echo -e "${GREEN}[*] Creating Xray systemd service...${NC}"

cat <<EOF > /etc/systemd/system/xray.service
[Unit]
Description=Xray System-wide Proxy Service
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/opt/xray/xray run -config /opt/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xray &> /dev/null
systemctl start xray

if systemctl is-active --quiet xray; then
    echo -e "${GREEN}[+] Xray service started successfully!${NC}"
else
    echo -e "${RED}[-] Error: Failed to start Xray service. Check your JSON syntax.${NC}"
    exit 1
fi

# 6. Configure System and APT Proxy
echo -e "${GREEN}[*] Configuring APT and Environment Proxies...${NC}"
PROXY_HTTP="http://127.0.0.1:20809"

echo "Acquire::http::Proxy \"$PROXY_HTTP\";" > /etc/apt/apt.conf.d/99proxy
echo "Acquire::https::Proxy \"$PROXY_HTTP\";" >> /etc/apt/apt.conf.d/99proxy

if ! grep -q "http_proxy" /etc/environment; then
    echo "export http_proxy=\"$PROXY_HTTP\"" >> /etc/environment
    echo "export https_proxy=\"$PROXY_HTTP\"" >> /etc/environment
fi

echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}[+] Done! APT and System traffic are now proxied.${NC}"
echo -e "${GREEN}[*] Please restart your server using: 'sudo reboot'${NC}"
echo -e "${GREEN}==================================================${NC}"
