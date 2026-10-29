#!/bin/sh
# install.sh — одна команда, без костылей (Alpine-based OpenWrt)

set -e

REPO="https://github.com/updwa/podfork"
LATEST_URL="https://api.github.com/repos/updwa/podfork/releases/latest"

echo "📦 Установка Podkop с поддержкой подписок..."

if [ ! -f /etc/openwrt_release ]; then
    echo "❌ Этот скрипт предназначен для OpenWrt."
    exit 1
fi

# Зависимости
echo "🔧 Установка зависимостей..."
apk update
apk add sing-box curl jq coreutils-base64 bind-tools

# Получаем тег последнего релиза
echo "🔍 Поиск последнего реLEASE..."
TAG_NAME="$(curl -s "$LATEST_URL" | jq -r '.tag_name')"

if [ -z "$TAG_NAME" ] || [ "$TAG_NAME" = "null" ]; then
    echo "❌ Не найден последний релиз."
    exit 1
fi

echo "🏷️  Тег релиза: $TAG_NAME"

# Скачиваем исходный код релиза (GitHub авто-архив tar.gz)
ARCHIVE_URL="https://github.com/updwa/podfork/archive/refs/tags/${TAG_NAME}.tar.gz"

echo "⬇️  Скачивание: $ARCHIVE_URL"
wget -O /tmp/podkop.tar.gz "$ARCHIVE_URL"

echo "📦 Распаковка в корень..."
cd /
tar -xzf /tmp/podkop.tar.gz --strip-components=1
rm -f /tmp/podkop.tar.gz

echo "🚀 Запуск сервиса..."
/etc/init.d/podkop enable
/etc/init.d/podkop start

echo ""
echo "🎉 Готово!"
echo ""
echo "Настройте подписку в /etc/config/podkop:"
echo "  config section 'my_subscription'"
echo "      option connection_type 'proxy'"
echo "      option proxy_config_type 'subscription'"
echo "      list subscription_url 'https://ваш-провайдер.com/api/sub'"
echo ""
echo "Затем: /usr/bin/podkop subscription_update"
echo ""
echo "Или проверьте пинг: /usr/bin/podkop subscription_url_test my_subscription"
