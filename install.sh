#!/bin/sh
set -e

echo "📦 Установка Podkop..."

apk update 2>/dev/null || true
apk add sing-box curl jq coreutils-base64 bind-tools 2>/dev/null || true

mkdir -p /tmp/podkop-install
cd /tmp/podkop-install
wget -qO /tmp/podkop.tar.gz https://github.com/updwa/podfork/archive/refs/tags/v1.0.0.tar.gz
tar -xzf /tmp/podkop.tar.gz
cd podfork-*/
cp -r etc usr /
rm -rf /tmp/podkop-install /tmp/podkop.tar.gz

/etc/init.d/podkop enable
/etc/init.d/podkop start

echo "✅ Готово"
echo "Настройте /etc/config/podkop"
echo "Затем: /usr/bin/podkop subscription_update"
