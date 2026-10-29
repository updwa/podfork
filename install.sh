#!/bin/sh
# install.sh — установка Podkop с поддержкой подписок (Alpine-based OpenWrt)

set -e

REPO="https://github.com/updwa/podfork"
LATEST_URL="https://api.github.com/repos/updwa/podfork/releases/latest"

echo "📦 Установка Podkop с поддержкой подписок..."

if [ ! -f /etc/openwrt_release ]; then
    echo "❌ Этот скрипт предназначен для OpenWrt."
    exit 1
fi

# Зависимости (apk вместо opkg)
echo "🔧 Установка зависимостей..."
apk update
apk add sing-box curl jq coreutils-base64 bind-tools

# Скачиваем последний архив с файлами
echo "🔍 Поиск последнего релиза..."
ARCHIVE_URL="$(curl -s "$LATEST_URL" | jq -r '.assets[] | select(.name | endswith(".tar.gz")) | .browser_download_url' | head -n1)"

if [ -z "$ARCHIVE_URL" ]; then
    echo "❌ Не найден архив в последнем релизе."
    echo "   Доступные ассеты:"
    curl -s "$LATEST_URL" | jq -r '.assets[].name'
    exit 1
fi

echo "⬇️  Скачивание: $ARCHIVE_URL"
wget -O /tmp/podkop.tar.gz "$ARCHIVE_URL"

echo "📦 Распаковка файлов..."
cd /
tar -xzf /tmp/podkop.tar.gz
rm -f /tmp/podkop.tar.gz

echo "🚀 Запуск сервиса..."
/etc/init.d/podkop enable
/etc/init.d/podkop start

echo ""
echo "🎉 Установка завершена!"
echo ""
echo "Настройте подписку в /etc/config/podkop:"
echo "  config section 'my_subscription'"
echo "      option connection_type 'proxy'"
echo "      option proxy_config_type 'subscription'"
echo "      list subscription_url 'https://ваш-провайдер.com/api/sub'"
echo ""
echo "Затем обновите подписки:"
echo "  /usr/bin/podkop subscription_update"
echo ""
echo "Или проверьте пинг серверов:"
echo "  /usr/bin/podkop subscription_url_test my_subscription"
