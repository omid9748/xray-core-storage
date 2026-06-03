#!/bin/bash

# رنگ‌ها برای خروجی ترمینال
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== اسکریپت راه‌اندازی سریع پروکسی روی اوبونتو ===${NC}"

# ۱. ساخت پوشه کاری
mkdir -p /opt/xray
cd /opt/xray

# ۲. بررسی وجود فایل زیپ در پوشه
if [ ! -f /opt/xray/xray.zip ]; then
    echo -e "${RED}[-] فایل xray.zip در مسیر /opt/xray/ پیدا نشد!${NC}"
    echo -e "${GREEN}[*] راهنمایی: ابتدا فایل Xray-linux-64.zip را دستی دانلود کرده و با نام xray.zip در مسیر /opt/xray/ آپلود کنید، سپس این اسکریپت را اجرا کنید.${NC}"
    exit 1
fi

# ۳. استخراج فایل با پایتون (مخصوص سرورهای ایران بدون نیاز به ابزار آنلاین)
echo -e "${GREEN}[*] در حال استخراج هسته Xray...${NC}"
python3 -m zipfile -e xray.zip .

# جابجایی فایل‌ها از پوشه داخلی گیت‌هاب به مسیر اصلی
if [ -d /opt/xray/Xray-linux-64 ]; then
    mv /opt/xray/Xray-linux-64/* /opt/xray/
    rm -rf /opt/xray/Xray-linux-64 /opt/xray/__MACOSX
fi

rm -f xray.zip
chmod +x /opt/xray/xray 2> /dev/null

# ۴. دریافت کانفیگ از کاربر
echo -e "${GREEN}[?] لطفاً کانفیگ کامل JSON خود را وارد کنید:${NC}"
echo -e "${RED}(نکته: کانفیگ را پیست کنید، Enter بزنید و سپس کلیدهای CTRL+D را فشار دهید)${NC}"

USER_CONFIG=$(cat)

if [ -z "$USER_CONFIG" ]; then
    echo -e "${RED}[-] کانفیگ نمی‌تواند خالی باشد!${NC}"
    exit 1
fi

echo "$USER_CONFIG" > /opt/xray/config.json

# ۵. ساخت سرویس سیستمی (Systemd)
echo -e "${GREEN}[*] در حال ساخت سرویس سیستمی Xray...${NC}"

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
    echo -e "${GREEN}[+] هسته Xray با موفقیت فعال شد.${NC}"
else
    echo -e "${RED}[-] مشکلی در اجرای Xray پیش آمد. کانفیگ JSON را بررسی کنید.${NC}"
    exit 1
fi

# ۶. ست کردن پروکسی پورت ۲۰۸۰۹ روی کل سیستم و APT
echo -e "${GREEN}[*] در حال تنظیم پروکسی سیستم و APT...${NC}"
PROXY_HTTP="http://127.0.0.1:20809"

echo "Acquire::http::Proxy \"$PROXY_HTTP\";" > /etc/apt/apt.conf.d/99proxy
echo "Acquire::https::Proxy \"$PROXY_HTTP\";" >> /etc/apt/apt.conf.d/99proxy

if ! grep -q "http_proxy" /etc/environment; then
    echo "export http_proxy=\"$PROXY_HTTP\"" >> /etc/environment
    echo "export https_proxy=\"$PROXY_HTTP\"" >> /etc/environment
fi

echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}[+] کار تمام است! سیستم و دستور apt اکنون از پروکسی رد می‌شوند.${NC}"
echo -e "${GREEN}[*] یک بار سرور را با دستور 'sudo reboot' ریستارت کنید.${NC}"
echo -e "${GREEN}==================================================${NC}"
