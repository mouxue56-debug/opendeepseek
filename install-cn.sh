#!/usr/bin/env bash
# OpenDeepSeek CN smart installer.
#
# This installer is designed for the future China-ready distribution path.
# It can run from a mirrored repo or from raw script, prefers domestic sources,
# and falls back with clear offline-bundle instructions.

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}ℹ️  $1${NC}"; }
ok() { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
die() { echo -e "${RED}❌ $1${NC}"; exit 1; }

INSTALL_DIR="${OPDS_INSTALL_DIR:-${HOME}/opendeepseek-cn}"
GITEE_REPO="${OPDS_CN_GITEE_REPO:-https://gitee.com/luoxueai/opendeepseek.git}"
GITCODE_REPO="${OPDS_CN_GITCODE_REPO:-https://gitcode.com/mouxue56-debug/opendeepseek.git}"
GITHUB_REPO="${OPDS_GITHUB_REPO:-https://github.com/mouxue56-debug/opendeepseek.git}"

usage() {
  cat <<'EOF'
OpenDeepSeek CN installer

Usage:
  bash install-cn.sh
  OPDS_INSTALL_DIR=~/opendeepseek-cn bash install-cn.sh
  OPDS_CN_OFFLINE=/path/to/opendeepseek-images-cn-amd64.tar.zst bash install-cn.sh

Environment:
  OPDS_CN_GITEE_REPO     Gitee mirror repo URL
  OPDS_CN_GITCODE_REPO   GitCode mirror repo URL
  OPDS_GITHUB_REPO       GitHub fallback repo URL
  OPDS_INSTALL_DIR       install directory, default ~/opendeepseek-cn
  OPDS_CN_OFFLINE        optional image tar.zst to docker load
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

detect_platform() {
  local os arch
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"
  case "${arch}" in
    x86_64|amd64) arch="amd64" ;;
    arm64|aarch64) arch="arm64" ;;
    *) warn "未知 CPU 架构：${arch}" ;;
  esac
  echo "${os}-${arch}"
}

rand_hex() {
  if command_exists openssl; then
    openssl rand -hex 32
  else
    od -An -N32 -tx1 /dev/urandom | tr -d ' \n'
  fi
}

set_env_value() {
  local file="$1"
  local key="$2"
  local value="$3"
  if grep -qE "^${key}=" "${file}"; then
    sed -i.bak -E "s|^${key}=.*|${key}=${value}|" "${file}"
    rm -f "${file}.bak"
  else
    printf '%s=%s\n' "${key}" "${value}" >>"${file}"
  fi
}

repo_reachable() {
  local repo="$1"
  git ls-remote --heads "${repo}" HEAD >/dev/null 2>&1
}

choose_repo() {
  local repos=("${GITEE_REPO}" "${GITCODE_REPO}" "${GITHUB_REPO}")
  local names=("Gitee" "GitCode" "GitHub fallback")
  local i
  for i in "${!repos[@]}"; do
    log "检测 ${names[$i]}：${repos[$i]}" >&2
    if repo_reachable "${repos[$i]}"; then
      ok "选择 ${names[$i]}" >&2
      echo "${repos[$i]}"
      return 0
    fi
  done
  return 1
}

ensure_tools() {
  command_exists curl || die "缺少 curl。请先安装 curl。"
  command_exists git || die "缺少 git。请先安装 git。"
  command_exists docker || die "缺少 Docker。请先安装并启动 Docker Desktop。"
  docker compose version >/dev/null 2>&1 || die "缺少 docker compose v2。"
}

ensure_repo() {
  if [[ -f setup.sh && -f docker-compose.cn.yml ]]; then
    ok "当前目录已是 OpenDeepSeek 仓库"
    return 0
  fi

  if [[ -d "${INSTALL_DIR}/.git" ]]; then
    log "进入已有安装目录：${INSTALL_DIR}"
    cd "${INSTALL_DIR}"
    return 0
  fi

  local repo
  repo="$(choose_repo)" || die "Gitee/GitCode/GitHub 都不可达。请下载 OpenDeepSeek CN 离线包。"
  mkdir -p "$(dirname "${INSTALL_DIR}")"
  git clone "${repo}" "${INSTALL_DIR}"
  cd "${INSTALL_DIR}"
}

ensure_env() {
  if [[ ! -f .env ]]; then
    cp .env.example.cn .env
    ok "已创建 .env（来自 .env.example.cn）"
  fi

  if grep -q 'your-deepseek-api-key-here' .env; then
    echo
    read -r -p "请输入 DeepSeek API Key（输入时会显示，确认周围无人）： " key
    [[ -n "${key}" ]] || die "DeepSeek API Key 不能为空"
    set_env_value .env DEEPSEEK_API_KEY "${key}"
  fi

  if grep -q 'auto-generated-by-install-cn' .env; then
    set_env_value .env HERMES_API_KEY "$(rand_hex)"
    set_env_value .env WEBUI_SECRET_KEY "$(rand_hex)"
    ok "已生成本机随机 HERMES_API_KEY / WEBUI_SECRET_KEY"
  fi

  mkdir -p "${HOME}/OpenDeepSeek-Agent/OpenDeepSeek-Inputs" \
    "${HOME}/OpenDeepSeek-Agent/OpenDeepSeek-Outputs" \
    "${HOME}/OpenDeepSeek-Agent/OpenDeepSeek-Memory"
  set_env_value .env HERMES_HOST_DIR "${HOME}/OpenDeepSeek-Agent"
  set_env_value .env OPDS_HOST_DISPLAY_PREFIX "${HOME}/OpenDeepSeek-Agent"
}

load_offline_images() {
  local offline="${OPDS_CN_OFFLINE:-}"
  [[ -n "${offline}" ]] || return 0
  [[ -f "${offline}" ]] || die "离线镜像包不存在：${offline}"
  command_exists zstd || die "加载 .tar.zst 需要 zstd。请先安装 zstd。"
  log "加载离线镜像包：${offline}"
  zstd -d "${offline}" -c | docker load
}

start_stack() {
  if ! docker info >/dev/null 2>&1; then
    die "Docker daemon 未启动。请先打开 Docker Desktop / OrbStack。"
  fi

  log "启动 OpenDeepSeek CN（只默认暴露 http://localhost:3000）"
  if docker compose -f docker-compose.cn.yml up -d; then
    ok "OpenDeepSeek CN 已启动"
    echo
    echo "访问：http://localhost:3000"
  else
    warn "国内镜像拉取或启动失败。"
    echo
    echo "可选处理："
    echo "1. 检查国内镜像是否已发布到 OPDS_IMAGE_REGISTRY。"
    echo "2. 使用离线包：OPDS_CN_OFFLINE=/path/images.tar.zst bash install-cn.sh"
    echo "3. 临时使用国际版：./setup.sh --web"
    exit 1
  fi
}

main() {
  echo "OpenDeepSeek CN installer"
  echo "platform: $(detect_platform)"
  echo
  ensure_tools
  ensure_repo
  bash scripts/check-network-cn.sh || true
  ensure_env
  load_offline_images
  start_stack
}

main "$@"
