#!/bin/sh
# First-time setup. Safe to run again: it never replaces existing settings or your saved login.
cd "$(dirname "$0")" || exit 1
command -v docker >/dev/null || { echo "Install Docker first (see README)."; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "Docker Compose is missing (see README)."; exit 1; }
command -v python3 >/dev/null || { echo "Install Python 3 first."; exit 1; }

if [ ! -f .env ]; then
  case "$(uname -m)" in
    arm64|aarch64) IMAGE=devlikeapro/waha:arm ;;
    *) IMAGE=devlikeapro/waha:latest ;;
  esac
  umask 077
  cat > .env <<SETTINGS
COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-whatsapp-bridge}
WAHA_IMAGE=$IMAGE
WAHA_PORT=${WAHA_PORT:-3000}
HOOK_PORT=${HOOK_PORT:-8787}
WAHA_API_KEY=$(openssl rand -hex 32)
HOOK_TOKEN=$(openssl rand -hex 16)
SETTINGS
  umask 022
  echo "Created .env with new private keys."
fi

mkdir -p data/sessions data/qr
chmod 700 data
exec sh start.sh
