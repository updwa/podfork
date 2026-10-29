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

# Скачиваем релизные данные один раз, чтобы не спамить в API GitHub
RELEASE_DATA="$(curl -s "$LATEST_URL")"

# Скачиваем архив с файлами podkop (бинарник + конфиги)
echo "⬇️  Скачивание podkop..."
PODKOP_URL="$(echo "$RELEASE_DATA" | jq -r '.assets[] | select(.name | test("^podkop-v.*\\.tar\\.gz$") and (contains("luci") | not)) | .browser_download_url' | head -n1)"

if [ -z "$PODKOP_URL" ] || [ "$PODKOP_URL" = "null" ]; then
    # Резервный поиск, если шаблон имени другой
    PODKOP_URL="$(echo "$RELEASE_DATA" | jq -r '.assets[] | select(.name | endswith(".tar.gz") and (contains("luci") | not)) | .browser_download_url' | head -n1)"
fi

wget -O /tmp/podkop.tar.gz "$PODKOP_URL"
tar -xzf /tmp/podkop.tar.gz -C /
rm -f /tmp/podkop.tar.gz

# Скачиваем архив с LuCI веб-интерфейсом
echo "⬇️  Скачивание LuCI интерфейса..."
LUCI_URL="$(echo "$RELEASE_DATA" | jq -r '.assets[] | select(.name | contains("luci") and endswith(".tar.gz")) | .browser_download_url' | head -n1)"

if [ -n "$LUCI_URL" ] && [ "$LUCI_URL" != "null" ]; then
    wget -O /tmp/podkop-luci.tar.gz "$LUCI_URL"
    tar -xzf /tmp/podkop-luci.tar.gz -C /
    rm -f /tmp/podkop-luci.tar.gz
fi

# Выставляем права на исполнение
chmod +x /etc/init.d/podkop 2>/dev/null || true
chmod +x /usr/bin/podkop 2>/dev/null || true

echo "🚀 Запуск сервиса..."
/etc/init.d/podkop enable
/etc/init.d/podkop start

echo ""
echo "🎉 Готово!"
echo ""
echo "Веб-интерфейс: http://<IP-роутера>/cgi-bin/luci/admin/services/podkop"
echo "Настройте подписку в /etc/config/podkop"
echo "Затем: /usr/bin/podkop subscription_update"
