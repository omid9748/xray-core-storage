#!/bin/bash

# رنگ‌ها برای قشنگ‌تر شدن خروجی ترمینال
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== به اسکریپت راه‌اندازی پروکسی سرور خوش آمدید ===${NC}"

# ۱. تعریف لینک دانلود هسته Xray (لینک گیت‌هاب خودت یا یک هاست آزاد را اینجا بذار)
# نکته: سرور ایران باید بتونه این لینک رو بدون تحریم دانلود کنه
XRAY_DOWNLOAD_URL="https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/Xray-linux-64.zip"

# ۲. ایجاد پوشه کاری و دانلود Xray
echo -e "${GREEN}[*] در حال ساخت پوشه‌ها و دانلود هسته Xray...${NC}"
mkdir -p /opt/xray
cd /opt/xray

# دانلود مستقیم فایل زیپ
wget -q --show-progress "$XRAY_DOWNLOAD_URL" -O xray.zip

if [ $? -ne 0 ]; then
    echo -e "${RED}[-] خطا در دانلود Xray! لطفاً لینک دانلود را بررسی کنید.${NC}"
    exit 1
fi

# استخراج فایل
apt-get install unzip -y &> /dev/null # تلاش برای نصب unzip، معمولا روی اوبونتو هست
unzip -o xray.zip &> /dev/null
rm xray.zip
chmod +x xray

# ۳. گرفتن کانفیگ JSON از کاربر
echo -e "${GREEN}[*] هسته Xray با موفقیت آماده شد.${NC}"
echo -e "${GREEN}[?] لطفاً کانفیگ کامل JSON خود را وارد کنید (بعد از چسباندن کد، CTRL+D را بزنید):${NC}"

# خواندن مالتی‌لاین کانفیگ JSON از ترمینال
USER_CONFIG=$(cat)

if [ -z "$USER_CONFIG" ]; then
    echo -e "${RED}[-] کانفیگ نمی‌تواند خالی باشد!${NC}"
    exit 1
fi

# ذخیره کانفیگ در مسیر مشخص
echo "$USER_CONFIG" > /opt/xray/config.json

# ۴. ساخت سرویس سیستمی (Systemd Service) برای اجرای پس‌زمینه Xray
echo -e "${GREEN}[*] در حال ساخت Service برای Xray...${NC}"

cat <<EOF > /etc/systemd/system/xray.service
[Unit]
Description=Xray Service by Me
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

# فعال‌سازی و استارت سرویس
systemctl daemon-reload
systemctl enable xray &> /dev/null
systemctl start xray

if systemctl is-active --quiet xray; then
    echo -e "${GREEN}[+] هسته Xray با موفقیت فعال شد و در پس‌زمینه در حال اجراست.${NC}"
else
    echo -e "${RED}[-] مشکلی در اجرای Xray پیش آمد. سرویس استارت نشد.${NC}"
    exit 1
fi

# ۵. ست کردن پروکسی روی کل سیستم (System-wide) و APT
echo -e "${GREEN}[*] در حال هدایت ترافیک سیستم و APT به سمت پروکسی...${NC}"

# فرض می‌کنیم پورت اینباند کانفیگ شما روی حالت HTTP و پورت 10809 تنظیم شده است.
# اگر پورت کانفیگت چیز دیگری است، این بخش را تغییر بده.
PROXY_HTTP="http://127.0.0.1:10809"

# تنظیم برای APT (دستور apt update و apt install)
echo "Acquire::http::Proxy \"$PROXY_HTTP\";" > /etc/apt/apt.conf.d/99proxy
echo "Acquire::https::Proxy \"$PROXY_HTTP\";" >> /etc/apt/apt.conf.d/99proxy

# تنظیم برای کل محیط ترمینال (Bash)
if ! grep -q "http_proxy" /etc/environment; then
    echo "export http_proxy=\"$PROXY_HTTP\"" >> /etc/environment
    echo "export https_proxy=\"$PROXY_HTTP\"" >> /etc/environment
fi

echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}[+] کار تمام است! سیستم و دستور apt اکنون از پروکسی رد می‌شوند.${NC}"
echo -e "${GREEN}[*] یک بار سرور را Reboot کنید یا دستور 'source /etc/environment' را بزنید.${NC}"
echo -e "${GREEN}==================================================${NC}"
