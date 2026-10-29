#!/bin/sh
set -e

echo "📦 Установка Podkop с поддержкой подписок..."

apk update
apk add sing-box curl jq coreutils-base64 bind-tools

mkdir -p /tmp/podkop-install
cd /tmp/podkop-install
wget -qO /tmp/podkop.tar.gz https://github.com/updwa/podfork/archive/refs/tags/v1.0.0.tar.gz
tar -xzf /tmp/podkop.tar.gz
cd podfork-*/
cp -r etc usr /
rm -rf /tmp/podkop-install /tmp/podkop.tar.gz

/etc/init.d/podkop enable
/etc/init.d/podkop start

echo "✅ Установка завершена"
echo "Настройте /etc/config/podkop"
echo "Затем выполните: /usr/bin/podkop subscription_update"
