#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

chmod +x ./setup.sh 2>/dev/null || true
./setup.sh --web
