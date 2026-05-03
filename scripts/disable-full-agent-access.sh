#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SAFE_DIR="${ROOT_DIR}/agent-files"
ENV_FILE="${ROOT_DIR}/.env"

cd "$ROOT_DIR"
mkdir -p "$SAFE_DIR"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERR: .env not found. Run ./setup.sh --web first." >&2
  exit 1
fi

if grep -qE '^HERMES_HOST_DIR=' "$ENV_FILE"; then
  perl -0pi -e "s#^HERMES_HOST_DIR=.*#HERMES_HOST_DIR=${SAFE_DIR}#mg" "$ENV_FILE"
else
  printf "\nHERMES_HOST_DIR=%s\n" "$SAFE_DIR" >> "$ENV_FILE"
fi

echo "Full Agent access disabled:"
echo "  /host now points to $SAFE_DIR"
echo ""
docker compose up -d hermes open-webui
