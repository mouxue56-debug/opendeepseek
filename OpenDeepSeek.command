#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

chmod +x ./setup.sh 2>/dev/null || true

if ! command -v docker >/dev/null 2>&1; then
  echo "未找到 docker 命令。请先安装 OrbStack 或 Docker Desktop。"
  echo "https://orbstack.dev/"
  read -r -p "按回车退出..."
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "正在启动 OrbStack / Docker..."
  osascript -e 'tell application "OrbStack" to activate' >/dev/null 2>&1 || open -a OrbStack >/dev/null 2>&1 || open -a Docker >/dev/null 2>&1 || true
  echo "等待 Docker daemon 就绪..."
  for _ in {1..30}; do
    if docker info >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon 仍未就绪。请手动打开 OrbStack/Docker Desktop 后再双击。"
  read -r -p "按回车退出..."
  exit 1
fi

if [[ ! -f .env ]]; then
  echo "首次使用需要先填写 API Key，正在打开配置向导..."
  ./setup.sh --web
else
  echo "启动 OpenDeepSeek 轻量核心服务..."
  ./setup.sh start
  sleep 3
  open http://localhost:3000
fi
