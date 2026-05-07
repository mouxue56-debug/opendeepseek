#!/usr/bin/env bash
# China network diagnostics for OpenDeepSeek CN.

set -u
set -o pipefail

PASS=0
FAIL=0
WARN=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TIMEOUT="${OPDS_CN_NET_TIMEOUT:-8}"
STRICT="${OPDS_CN_STRICT:-false}"

ok() {
  echo -e "${GREEN}✅ $1${NC}"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}❌ $1${NC}"
  FAIL=$((FAIL + 1))
}

warn() {
  echo -e "${YELLOW}⚠️  $1${NC}"
  WARN=$((WARN + 1))
}

info() {
  echo -e "${BLUE}ℹ️  $1${NC}"
}

probe_url() {
  local label="$1"
  local url="$2"
  local code
  code="$(curl -sSIL --connect-timeout "${TIMEOUT}" --max-time "${TIMEOUT}" -o /dev/null -w '%{http_code}' "${url}" 2>/dev/null || true)"
  case "${code}" in
    2*|3*|401|403)
      ok "${label} 可达：${url} (HTTP ${code})"
      ;;
    *)
      warn "${label} 不可达或超时：${url} (HTTP ${code:-000})"
      ;;
  esac
}

probe_git() {
  local label="$1"
  local repo="$2"
  local refs=""
  if [[ "${label}" == "GitCode" && "${OPDS_CN_CHECK_GITCODE:-false}" != "true" ]]; then
    info "跳过 GitCode Git 深度探测；如需检查，设置 OPDS_CN_CHECK_GITCODE=true。"
    return 0
  fi
  if command -v git >/dev/null 2>&1; then
    refs="$(GIT_TERMINAL_PROMPT=0 git \
      -c http.lowSpeedLimit=1 \
      -c "http.lowSpeedTime=${OPDS_CN_GIT_TIMEOUT:-10}" \
      ls-remote --heads "${repo}" main master 2>/dev/null || true)"
  fi
  if [[ -n "${refs}" ]]; then
    ok "${label} Git 仓库可达：${repo}"
  else
    warn "${label} Git 仓库不可达：${repo}"
  fi
}

probe_registry() {
  local registry="${1:-registry.cn-hangzhou.aliyuncs.com/opendeepseek}"
  local url="https://${registry%/*}/v2/"
  local code
  code="$(curl -sS --connect-timeout "${TIMEOUT}" --max-time "${TIMEOUT}" -o /dev/null -w '%{http_code}' "${url}" 2>/dev/null || true)"
  case "${code}" in
    200|401|403)
      ok "容器镜像仓库可达：${url} (HTTP ${code})"
      ;;
    *)
      warn "容器镜像仓库不可达或超时：${url} (HTTP ${code:-000})"
      ;;
  esac
}

echo "OpenDeepSeek CN 网络体检"
echo "timeout: ${TIMEOUT}s"
echo

probe_url "DeepSeek API" "${DEEPSEEK_API_BASE:-https://api.deepseek.com}"
probe_url "Gitee raw" "${OPDS_CN_GITEE_RAW:-https://gitee.com/luoxueai/opendeepseek/raw/main/install-cn.sh}"
probe_url "GitCode raw" "${OPDS_CN_GITCODE_RAW:-https://gitcode.com/mouxue56-debug/opendeepseek/raw/main/install-cn.sh}"
probe_url "阿里云 OSS release manifest" "${OPDS_CN_OSS_MANIFEST:-https://opendeepseek-cn.oss-cn-hangzhou.aliyuncs.com/releases/release-cn.json}"
probe_url "腾讯云 COS release manifest" "${OPDS_CN_COS_MANIFEST:-https://opendeepseek-cn.cos.ap-shanghai.myqcloud.com/releases/release-cn.json}"
probe_url "Docker Hub Registry" "${OPDS_DOCKER_HUB_REGISTRY:-https://registry-1.docker.io/v2/}"
if [[ -n "${OPDS_IMAGE_REGISTRY:-}" ]]; then
  probe_registry "${OPDS_IMAGE_REGISTRY}"
else
  info "未设置 OPDS_IMAGE_REGISTRY；当前 CN compose 默认使用已公开上游镜像，国内 ACR/CCR 发布后再切换。"
fi
probe_url "清华 PyPI 镜像" "${PIP_INDEX_URL:-https://pypi.tuna.tsinghua.edu.cn/simple}"
probe_url "npmmirror" "${NPM_CONFIG_REGISTRY:-https://registry.npmmirror.com}"

probe_git "Gitee" "${OPDS_CN_GITEE_REPO:-https://gitee.com/luoxueai/opendeepseek.git}"
probe_git "GitCode" "${OPDS_CN_GITCODE_REPO:-https://gitcode.com/mouxue56-debug/opendeepseek.git}"

if curl -fsSL --connect-timeout 2 --max-time 2 -o /dev/null http://localhost:3000/health 2>/dev/null; then
  ok "Open WebUI 本地健康检查可达"
else
  warn "Open WebUI 本地健康检查不可达（服务可能未启动）"
fi

if curl -fsSL --connect-timeout 2 --max-time 2 -o /dev/null http://localhost:8642/health 2>/dev/null; then
  ok "Hermes 本地健康检查可达"
else
  warn "Hermes 本地健康检查不可达（CN compose 默认不暴露该端口）"
fi

echo
echo "结果：${PASS} 可达，${WARN} 警告，${FAIL} 失败"

if [[ "${STRICT}" == "true" && "${WARN}" -ne 0 ]]; then
  exit 1
fi

exit 0
