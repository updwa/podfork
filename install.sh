#!/bin/sh
# install.sh — установка Podkop с поддержкой подписок через GitHub Releases

set -e

# Определяем архитектуру OpenWrt
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)   ARCH_SLUG="x86_64" ;;
    aarch64)  ARCH_SLUG="aarch64_cortex-a53" ;;
    armv7l)   ARCH_SLUG="arm_cortex-a7_vfpv3" ;;
    mips)     ARCH_SLUG="mips_24kc" ;;
    mipsel)   ARCH_SLUG="mipsel_24kc" ;;
    *)        ARCH_SLUG="$ARCH" ;;
esac

REPO="https://github.com/updwa/podfork"
LATEST_URL="https://api.github.com/repos/updwa/podfork/releases/latest"

echo "📦 Установка Podkop с поддержкой подписок..."

if [ ! -f /etc/openwrt_release ]; then
    echo "❌ Этот скрипт предназначен для OpenWrt."
    exit 1
fi

# Зависимости
echo "🔧 Установка зависимостей..."
opkg update
opkg install sing-box curl jq coreutils-base64 bind-dig

# Получаем ссылку на последний .ipk для нашей архитектуры
echo "🔍 Поиск последней версии для архитектуры $ARCH_SLUG..."
IPK_URL="$(curl -s "$LATEST_URL" | jq -r --arch "$ARCH_SLUG" '.assets[] | select(.name | test("'"$ARCH_SLUG"'")) | .browser_download_url' | head -n1)"

if [ -z "$IPK_URL" ]; then
    echo "❌ Не найден .ipk для архитектуры $ARCH_SLUG в последнем релизе."
    echo "   Доступные ассеты:"
    curl -s "$LATEST_URL" | jq -r '.assets[].name'
    exit 1
fi

echo "⬇️  Скачивание: $IPK_URL"
wget -O /tmp/podkop.ipk "$IPK_URL"

echo "📦 Установка пакета..."
opkg install /tmp/podkop.ipk
rm -f /tmp/podkop.ipk

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
