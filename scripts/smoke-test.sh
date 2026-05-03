#!/bin/bash
# OpenDeepSeek Smoke Test — 验证一键部署的端到端联调
# 用法：./scripts/smoke-test.sh
# 前提：./setup.sh 已经跑过且 .env 配置完毕

set -e

# 确保在项目根目录执行（含 docker-compose.yml）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.." || { echo "ERR: cannot cd to project root"; exit 1; }
[[ -f "docker-compose.yml" ]] || { echo "ERR: docker-compose.yml not found in $(pwd)"; exit 1; }

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0

ok()   { echo -e "${GREEN}✅ $1${NC}"; PASS=$((PASS+1)); }
fail() { echo -e "${RED}❌ $1${NC}"; FAIL=$((FAIL+1)); }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

echo "════════════════════════════════════════════"
echo "   OpenDeepSeek Smoke Test"
echo "════════════════════════════════════════════"
echo ""

# 1. .env 存在
info "[1/7] 检查 .env 文件"
if [[ -f .env ]] && grep -v '^\s*#' .env | grep -qE "^DEEPSEEK_API_KEY[[:space:]]*=" && ! grep -q "DEEPSEEK_API_KEY=your-deepseek-api-key-here" .env; then
    ok ".env 配置完毕"
else
    fail ".env 缺失或未配置 DEEPSEEK_API_KEY"
    exit 1
fi

# 2. 容器状态
info "[2/7] 检查 Docker 容器"
if docker compose ps --status running --format json 2>/dev/null | grep -q opendeepseek-hermes; then
    ok "hermes 容器运行中"
else
    fail "hermes 容器未运行（试试 docker compose up -d）"
fi

if docker compose ps --status running --format json 2>/dev/null | grep -q opendeepseek-webui; then
    ok "open-webui 容器运行中"
else
    fail "open-webui 容器未运行"
fi

# 3. Hermes 健康端点
info "[3/7] 检查 Hermes 健康端点"
if curl -fsS http://localhost:8642/health > /dev/null 2>&1; then
    ok "Hermes /health 返回 OK"
else
    fail "Hermes /health 不通（http://localhost:8642/health）"
fi

# 4. Open WebUI 可达
info "[4/7] 检查 Open WebUI 网页"
if curl -fsS http://localhost:3000 > /dev/null 2>&1; then
    ok "Open WebUI :3000 可访问"
else
    fail "Open WebUI :3000 不通"
fi

# 5. Hermes OpenAI-compat /v1/models
info "[5/7] 检查 Hermes OpenAI 兼容接口"
HERMES_KEY=$(grep -m1 "^HERMES_API_KEY=" .env | cut -d'=' -f2- | sed -E 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^["'"'"']|["'"'"']$//g')
MODELS_RESP=$(curl -fsS http://localhost:8642/v1/models -H "Authorization: Bearer ${HERMES_KEY}" 2>&1 || echo "FAIL")
# Hermes exposes itself as "hermes-agent" model ID (proxy to DeepSeek); check for valid OpenAI-compat list
if echo "$MODELS_RESP" | grep -q '"object".*"list"' || echo "$MODELS_RESP" | grep -q '"data"'; then
    ok "Hermes /v1/models 返回 OpenAI 兼容模型列表（hermes-agent proxy）"
else
    fail "Hermes /v1/models 异常：$MODELS_RESP"
fi

# 6. 端到端：通过 Hermes 调 DeepSeek 一次最简单的请求
info "[6/7] 端到端：Hermes → DeepSeek 测试"
CHAT_RESP=$(curl -fsS http://localhost:8642/v1/chat/completions \
    -H "Authorization: Bearer ${HERMES_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
      "model": "deepseek-v4-flash",
      "messages": [{"role":"user","content":"用一个汉字回答：你是谁？"}],
      "max_tokens": 10
    }' 2>&1 || echo "FAIL")
if echo "$CHAT_RESP" | grep -q '"content"'; then
    ok "端到端调用成功（Hermes → DeepSeek 返回内容）"
    echo "    回复片段：$(echo "$CHAT_RESP" | head -c 200)..."
else
    fail "端到端调用失败"
    echo "    响应：$(echo $CHAT_RESP | head -c 300)"
fi

# 7. Open WebUI → Hermes 桥接（OPENAI_API_BASE_URL 是否生效）
info "[7/7] 检查 Open WebUI 是否能看到 Hermes 模型"
WEBUI_MODELS=$(curl -fsS http://localhost:3000/api/models 2>&1 || echo "FAIL")
if echo "$WEBUI_MODELS" | grep -q "deepseek"; then
    ok "Open WebUI 已桥接 Hermes，模型列表正常"
else
    info "Open WebUI /api/models 需要登录 token，跳过自动验证"
    info "请手动访问 http://localhost:3000 → Admin → Connections 查看"
fi

echo ""
echo "════════════════════════════════════════════"
echo "   测试结果"
echo "════════════════════════════════════════════"
echo -e "  通过：${GREEN}${PASS}${NC}"
echo -e "  失败：${RED}${FAIL}${NC}"
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}🎉 全部 PASS — 可以开始使用 OpenDeepSeek！${NC}"
    echo "   访问 http://localhost:3000"
    exit 0
else
    echo -e "${RED}⚠️  有 ${FAIL} 项失败 — 请查看 docker compose logs${NC}"
    exit 1
fi
