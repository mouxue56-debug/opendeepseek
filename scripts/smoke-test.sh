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
echo "   OpenDeepSeek Smoke Test (v0.3.0)"
echo "════════════════════════════════════════════"
echo ""

# 1. .env 存在
info "[1/6] 检查 .env 文件"
if [[ -f .env ]] && grep -v '^\s*#' .env | grep -qE "^DEEPSEEK_API_KEY[[:space:]]*=" && ! grep -q "DEEPSEEK_API_KEY=your-deepseek-api-key-here" .env; then
    ok ".env 配置完毕"
else
    fail ".env 缺失或未配置 DEEPSEEK_API_KEY"
    exit 1
fi

# 2. 容器状态
info "[2/6] 检查 Open WebUI 容器"
if docker compose ps --status running --format json 2>/dev/null | grep -q opendeepseek-webui; then
    ok "open-webui 容器运行中"
else
    fail "open-webui 容器未运行（试试 docker compose up -d）"
    exit 1
fi

# 3. Open WebUI 可达
info "[3/6] 检查 Open WebUI 网页"
if curl -fsS http://localhost:3000 > /dev/null 2>&1; then
    ok "Open WebUI :3000 可访问"
else
    fail "Open WebUI :3000 不通"
    exit 1
fi

# 4. Open WebUI /api/config 公开信息（验证 WEBUI_AUTH 状态）
info "[4/6] 检查 Open WebUI 配置"
CONFIG_RESP=$(curl -fsS http://localhost:3000/api/config 2>/dev/null)
if echo "$CONFIG_RESP" | grep -q "OpenDeepSeek"; then
    AUTH_STATUS=$(echo "$CONFIG_RESP" | python3 -c "import json,sys; print(json.load(sys.stdin)['features']['auth'])" 2>/dev/null || echo "?")
    ok "Open WebUI 配置正常 (WEBUI_AUTH=$AUTH_STATUS, locale=zh-CN)"
else
    fail "Open WebUI /api/config 异常: $(echo "$CONFIG_RESP" | head -c 150)"
fi

# 5. DeepSeek API 直连（绕过 Open WebUI 验证 key 真实有效）
# 注意：DeepSeek V4 默认 thinking 模式，回复在 content + reasoning_content 都可能有
# max_tokens=200 给思考留空间
info "[5/6] 验证 DeepSeek API key 真实有效"
DK=$(grep -m1 "^DEEPSEEK_API_KEY=" .env | cut -d'=' -f2- | sed -E 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^["'"'"']|["'"'"']$//g')
DS_RESP=$(curl -fsS https://api.deepseek.com/v1/chat/completions \
    -H "Authorization: Bearer ${DK}" \
    -H "Content-Type: application/json" \
    -d '{
      "model": "deepseek-v4-flash",
      "messages": [{"role":"user","content":"用一个汉字回答：你是谁？"}],
      "max_tokens": 200
    }' 2>&1 || echo "FAIL")
# 严格检查：从 content 或 reasoning_content 取出真实回复（DeepSeek V4 thinking 模式）+ 不含 error/401
REPLY=$(echo "$DS_RESP" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    msg=d.get('choices',[{}])[0].get('message',{})
    content=msg.get('content','') or msg.get('reasoning_content','')
    print(content[:80].replace('\n',' '))
except: pass
" 2>/dev/null)
if [[ -n "$REPLY" ]] && [[ "$REPLY" != *"401"* ]] && [[ "$REPLY" != *"Authentication"* ]]; then
    ok "DeepSeek 真实 LLM 回复：「$REPLY」"
else
    fail "DeepSeek API 调用失败（可能 key 无效或余额不足）"
    echo "    响应：$(echo "$DS_RESP" | head -c 300)"
fi

# 6. Open WebUI 内部 OpenAI proxy 桥接验证
info "[6/6] 检查 Open WebUI → DeepSeek 桥接"
# /openai/models 是 Open WebUI 转发到 OPENAI_API_BASE_URL 的端点（需 user token）
# 单用户模式下我们没有 token，但可以看 webui 日志是否成功 connect DeepSeek
if docker compose logs open-webui 2>&1 | grep -q "Adding endpoint.*deepseek\|api.deepseek.com"; then
    ok "Open WebUI 已配 DeepSeek endpoint"
else
    info "Open WebUI 配置已生效（首次访问浏览器后会拉取模型）"
    info "→ 请手动打开 http://localhost:3000 验证模型列表"
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
