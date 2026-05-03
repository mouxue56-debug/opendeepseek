#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
HOST_DIR="${1:-$HOME}"

if [[ ! -d "$HOST_DIR" ]]; then
  echo "ERR: host directory does not exist: $HOST_DIR" >&2
  exit 1
fi

cd "$ROOT_DIR"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERR: .env not found. Run ./setup.sh --web first." >&2
  exit 1
fi

set_env() {
  local key="$1"
  local value="$2"
  if grep -qE "^${key}=" "$ENV_FILE"; then
    perl -0pi -e "s#^${key}=.*#${key}=${value}#mg" "$ENV_FILE"
  else
    printf "\n%s=%s\n" "$key" "$value" >> "$ENV_FILE"
  fi
}

set_env HERMES_HOST_DIR "$HOST_DIR"

echo "Full Agent access enabled:"
echo "  host:      $HOST_DIR"
echo "  container: /host"
echo ""
echo "Restarting Hermes/Open WebUI so Docker remounts the directory..."
docker compose up -d hermes open-webui

echo ""
echo "Done. In Open WebUI, ask for paths under /host, for example:"
echo "  请列出 /host/Desktop 下的文件名。"
