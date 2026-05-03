#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
STAMP="$(date +%Y%m%d-%H%M)"
PACKAGE_NAME="OpenDeepSeek-${STAMP}"
WORK_DIR="$(mktemp -d)"
PACKAGE_DIR="${WORK_DIR}/${PACKAGE_NAME}"
ZIP_PATH="${DIST_DIR}/${PACKAGE_NAME}.zip"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$DIST_DIR"
mkdir -p "$PACKAGE_DIR"

rsync -a "$ROOT_DIR/" "$PACKAGE_DIR/" \
  --exclude '.git' \
  --exclude '.env' \
  --exclude '.claude' \
  --exclude '.planning' \
  --exclude 'dist' \
  --exclude 'benchmark-results' \
  --exclude 'agent-files/*' \
  --exclude 'debug-log.md' \
  --exclude 'debug-summary.md' \
  --exclude '.DS_Store' \
  --exclude '__pycache__' \
  --exclude '*.pyc' \
  --exclude '*.bak' \
  --exclude '*.tmp'

chmod +x "$PACKAGE_DIR/setup.sh" "$PACKAGE_DIR/install.sh" "$PACKAGE_DIR/OpenDeepSeek.command"
find "$PACKAGE_DIR/scripts" -type f -name '*.sh' -exec chmod +x {} \;

(
  cd "$WORK_DIR"
  zip -qr "$ZIP_PATH" "$PACKAGE_NAME"
)

if command -v shasum >/dev/null 2>&1; then
  SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
elif command -v sha256sum >/dev/null 2>&1; then
  SHA256="$(sha256sum "$ZIP_PATH" | awk '{print $1}')"
else
  SHA256="未计算：系统缺少 shasum/sha256sum"
fi

printf "Package: %s\n" "$ZIP_PATH"
printf "SHA256:  %s\n" "$SHA256"
