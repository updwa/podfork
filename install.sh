#!/bin/sh
set -e

REPO="https://github.com/updwa/podfork"
LATEST_URL="https://api.github.com/repos/updwa/podfork/releases/latest"

echo "📦 Установка Podkop с LuCI и поддержкой подписок..."

if [ ! -f /etc/openwrt_release ]; then
    echo "❌ Этот скрипт предназначен для OpenWrt."
    exit 1
fi

# Зависимости
echo "🔧 Установка зависимостей..."
apk update
apk add sing-box curl jq coreutils-base64 bind-tools

# Скачиваем архив с файлами podkop (бинарник + конфиги)
echo "⬇️  Скачивание podkop..."
PODKOP_URL="$(curl -s "$LATEST_URL" | jq -r '.assets[] | select(.name | endswith(".tar.gz")) | .browser_download_url' | head -n1)"
wget -O /tmp/podkop.tar.gz "$PODKOP_URL"
cd /
tar -xzf /tmp/podkop.tar.gz --strip-components=1
rm -f /tmp/podkop.tar.gz

# Скачиваем архив с LuCI веб-интерфейсом
echo "⬇️  Скачивание LuCI интерфейса..."
LUCI_URL="$(curl -s "$LATEST_URL" | jq -r '.assets[] | select(.name | endswith("-luci.tar.gz")) | .browser_download_url' | head -n1)"
if [ -n "$LUCI_URL" ]; then
    wget -O /tmp/podkop-luci.tar.gz "$LUCI_URL"
    cd /
    tar -xzf /tmp/podkop-luci.tar.gz
    rm -f /tmp/podkop-luci.tar.gz
fi

echo "🚀 Запуск сервиса..."
/etc/init.d/podkop enable
/etc/init.d/podkop start

echo ""
echo "🎉 Готово!"
echo ""
echo "Веб-интерфейс: http://<IP-роутера>/cgi-bin/luci/admin/services/podkop"
echo "Настройте подписку в /etc/config/podkop"
echo "Затем: /usr/bin/podkop subscription_update"
