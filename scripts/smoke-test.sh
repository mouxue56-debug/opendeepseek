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
echo "   OpenDeepSeek Smoke Test (v0.4.3 - Smart Bridge 架构)"
echo "════════════════════════════════════════════"
echo ""

info "[0/11] 离线路由回归（不消耗 API）"
if python3 scripts/benchmark_routing.py > /tmp/opds-routing-benchmark.txt 2>&1; then
    ok "离线路由回归通过"
else
    fail "离线路由回归失败"
    cat /tmp/opds-routing-benchmark.txt
fi

# 1. .env 存在
info "[1/11] 检查 .env 文件"
if [[ -f .env ]] && grep -v '^\s*#' .env | grep -qE "^DEEPSEEK_API_KEY[[:space:]]*=" && ! grep -q "DEEPSEEK_API_KEY=your-deepseek-api-key-here" .env; then
    ok ".env 配置完毕"
else
    fail ".env 缺失或未配置 DEEPSEEK_API_KEY"
    exit 1
fi

if grep -qE "^HERMES_AGENT_MAX_TOKENS=([3-9][2-9][0-9]{3}|[1-9][0-9]{5,})" .env; then
    ok "Hermes Artifact 输出预算保持高位"
else
    fail "HERMES_AGENT_MAX_TOKENS 过低，网页/PPT/长文件任务可能截断"
fi

# 2. 三个容器状态（hermes + hermes-bridge + open-webui）
info "[2/11] 检查容器状态"
RUNNING=$(docker compose ps --status running --format json 2>/dev/null)
if echo "$RUNNING" | grep -q opendeepseek-hermes; then
    ok "hermes 容器运行中"
else
    fail "hermes 容器未运行（试试 docker compose up -d）"
    exit 1
fi
if echo "$RUNNING" | grep -q opendeepseek-hermes-bridge; then
    ok "hermes-bridge 容器运行中（图片 OCR + 智能路由）"
else
    fail "hermes-bridge 容器未运行"
    exit 1
fi
if echo "$RUNNING" | grep -q opendeepseek-webui; then
    ok "open-webui 容器运行中"
else
    fail "open-webui 容器未运行"
    exit 1
fi

# 3. Hermes 健康端点
info "[3/11] 检查 Hermes 健康端点"
if curl -fsS http://localhost:8642/health > /dev/null 2>&1; then
    ok "Hermes /health 返回 OK"
else
    fail "Hermes /health 不通"
fi

# 4. Smart Bridge 健康端点
info "[4/11] 检查 Hermes Smart Bridge 健康端点"
if docker compose exec -T hermes-bridge python -c "import urllib.request; urllib.request.urlopen('http://localhost:8765/health')" > /dev/null 2>&1; then
    ok "hermes-bridge /health 返回 OK"
else
    fail "hermes-bridge /health 不通"
fi

# 5. Open WebUI 可达
info "[5/11] 检查 Open WebUI 网页"
if curl -fsS http://localhost:3000 > /dev/null 2>&1; then
    ok "Open WebUI :3000 可访问"
else
    fail "Open WebUI :3000 不通"
fi

# 6. Hermes 模型列表（应该暴露 hermes-agent）
info "[6/11] 检查 Hermes 暴露的模型"
HERMES_KEY=$(grep -m1 "^HERMES_API_KEY=" .env | cut -d'=' -f2- | sed -E 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^["'"'"']|["'"'"']$//g')
MODELS_RESP=$(curl -fsS http://localhost:8642/v1/models -H "Authorization: Bearer ${HERMES_KEY}" 2>&1 || echo "FAIL")
if echo "$MODELS_RESP" | grep -q "hermes-agent"; then
    ok "Hermes 暴露 hermes-agent 模型（Open WebUI 把它当 model backend）"
else
    fail "Hermes /v1/models 异常"
    echo "    响应：$(echo "$MODELS_RESP" | head -c 200)"
fi

# 7. 真实端到端：普通问答 → Bridge → DeepSeek 轻量路径
# 这是项目核心架构验证，不能假阳性
info "[7/11] 真实端到端：Smart Bridge → DeepSeek 轻量问答"
TMP_RESP=$(mktemp)
docker compose exec -T -e HERMES_KEY="${HERMES_KEY}" hermes-bridge python - <<'PY' > "$TMP_RESP" 2>&1 || echo "FAIL"
import json
import os
import urllib.request

payload = {
      "model": "deepseek-v4-flash",
      "messages": [{"role":"user","content":"Output exactly these two ASCII letters and nothing else: OK"}],
      "max_tokens": 30
}
req = urllib.request.Request(
    "http://localhost:8765/v1/chat/completions",
    data=json.dumps(payload).encode("utf-8"),
    headers={
        "Authorization": "Bearer " + os.environ["HERMES_KEY"],
        "Content-Type": "application/json",
    },
)
with urllib.request.urlopen(req, timeout=180) as resp:
    print(resp.read().decode("utf-8"))
PY

# 用 jq 提取 content（避免 zsh locale 问题）
REPLY=$(jq -r '.choices[0].message.content // .choices[0].message.reasoning_content // ""' "$TMP_RESP" 2>/dev/null)
USAGE=$(jq -r '.usage.prompt_tokens // 0' "$TMP_RESP" 2>/dev/null)
rm -f "$TMP_RESP"
REPLY_COMPACT=$(echo "$REPLY" | tr -d '[:space:]')

# 严格检查：内容存在 + 不是错误字符串 + prompt_tokens 合理偏小（说明普通问答没有背 Hermes 工具上下文）
if [[ "$REPLY_COMPACT" == "OK" ]] && [[ "$USAGE" -gt 0 ]] && [[ "$USAGE" -lt 1000 ]]; then
    ok "轻量问答链路通：Bridge → DeepSeek 返回严格 OK（${USAGE} prompt tokens）"
else
    fail "轻量问答链路失败或误走完整 Hermes 上下文"
    echo "    回复: $REPLY"
    echo "    prompt_tokens: $USAGE"
fi

# 8. Open WebUI 入口 → Bridge → DeepSeek。防止压缩响应或模型代理问题导致前端显示 Server Connection Error。
info "[8/11] 真实端到端：Open WebUI → Smart Bridge → DeepSeek"
WEBUI_AUTH_MODE=$(grep -m1 "^WEBUI_AUTH=" .env | cut -d'=' -f2- | tr -d '[:space:]"'"'"'' || true)
if [[ "${WEBUI_AUTH_MODE:-false}" == "false" ]]; then
    WEBUI_TOKEN=$(curl -fsS -X POST http://localhost:3000/api/v1/auths/signin \
        -H "Content-Type: application/json" \
        -d '{"email":"admin@localhost","password":"admin"}' | jq -r '.token // ""' 2>/dev/null || true)
    if [[ -z "$WEBUI_TOKEN" ]]; then
        fail "Open WebUI no-auth 会话获取失败"
    else
        TMP_WEBUI=$(mktemp)
        curl -fsS http://localhost:3000/openai/chat/completions \
            -H "Authorization: Bearer ${WEBUI_TOKEN}" \
            -H "Content-Type: application/json" \
            -d '{
              "model": "hermes-agent",
              "messages": [{"role":"user","content":"Output exactly WEBUI_OK and nothing else."}],
              "max_tokens": 40,
              "stream": false
            }' > "$TMP_WEBUI" 2>&1 || echo "FAIL" > "$TMP_WEBUI"
        WEBUI_REPLY=$(jq -r '.choices[0].message.content // .detail // .error.message // ""' "$TMP_WEBUI" 2>/dev/null)
        rm -f "$TMP_WEBUI"
        if [[ "$(echo "$WEBUI_REPLY" | tr -d '[:space:]')" == "WEBUI_OK" ]]; then
            ok "Open WebUI 入口普通问答链路通（不是 Server Connection Error）"
        else
            fail "Open WebUI 入口普通问答失败"
            echo "    回复: $(echo "$WEBUI_REPLY" | head -c 300)"
        fi
    fi
else
    info "WEBUI_AUTH=true，跳过默认 admin no-auth 入口测试"
fi

# 9. 实时资讯 / 搜索类请求必须进 Hermes，并先给用户进度提示
info "[9/11] 验证实时资讯类请求路由到 Hermes，并先返回进度提示"
TMP_ROUTE=$(mktemp)
docker compose exec -T -e HERMES_KEY="${HERMES_KEY}" hermes-bridge python - <<'PY' > "$TMP_ROUTE" 2>&1 || echo "FAIL"
import json
import os
import urllib.request

payload = {
    "model": "hermes-agent",
    "messages": [{"role":"user","content":"给我做个今天 AI 圈的早报整理一下信息。烟测只验证路由，不要展开新闻，只回复 ROUTED_OK。"}],
    "max_tokens": 400,
    "stream": True,
}
req = urllib.request.Request(
    "http://localhost:8765/v1/chat/completions",
    data=json.dumps(payload).encode("utf-8"),
    headers={
        "Authorization": "Bearer " + os.environ["HERMES_KEY"],
        "Content-Type": "application/json",
    },
)
with urllib.request.urlopen(req, timeout=240) as resp:
    print(resp.read().decode("utf-8"))
PY

ROUTE_REPLY=$(cat "$TMP_ROUTE")
rm -f "$TMP_ROUTE"

if echo "$ROUTE_REPLY" | grep -Fq "识别为：实时资讯/资料整理任务" \
    && echo "$ROUTE_REPLY" | grep -Fq "ROUTED_OK"; then
    ok "实时资讯/早报请求会切到 Hermes，并先返回请稍等进度提示"
else
    fail "实时资讯/早报请求没有正确走 Hermes 进度流"
    echo "    响应: $(echo "$ROUTE_REPLY" | head -c 500)"
fi

# 10. Hermes Skills 激活验证（Cron）
info "[10/11] 验证 Hermes Skills 是否激活（Cron skill）"
TMP_CRON=$(mktemp)
curl -fsS http://localhost:8642/v1/chat/completions \
    -H "Authorization: Bearer ${HERMES_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
      "model": "hermes-agent",
      "messages": [{"role":"user","content":"用 cron 工具创建一个 1 小时后的提醒：测试任务。请实际调用 cron 工具。"}],
      "max_tokens": 400
    }' > "$TMP_CRON" 2>&1 || echo "FAIL"

CRON_REPLY=$(jq -r '.choices[0].message.content // .choices[0].message.reasoning_content // ""' "$TMP_CRON" 2>/dev/null)
rm -f "$TMP_CRON"

# 检查回复是否包含任务创建标志（任务 ID / "已创建" / "创建成功"）
if echo "$CRON_REPLY" | grep -qE "任务.*创建|已创建|已成功创建|创建成功|task.*created|cron.*scheduled"; then
    ok "Hermes Cron Skill 激活（Memory/Subagent/IM 同源应都活）"
else
    info "Cron Skill 未明确触发——回复: $(echo "$CRON_REPLY" | head -c 100)"
    info "（首次启动 skills 索引可能未就绪，等 1-2 分钟再测）"
fi

# 11. 真 Agent 文件系统权限：/host 是否挂载，Bridge 是否能把任务路由到 Hermes 并实际写文件
info "[11/11] 验证 Smart Bridge → Hermes 本机文件系统权限（/host）"
if docker compose exec -T hermes test -d /host; then
    ok "Hermes 容器已挂载 /host"
else
    fail "Hermes 容器没有 /host 挂载（检查 HERMES_HOST_DIR 和 docker-compose.yml）"
fi

TMP_HOST=$(mktemp)
docker compose exec -T -e HERMES_KEY="${HERMES_KEY}" hermes-bridge python - <<'PY' > "$TMP_HOST" 2>&1 || echo "FAIL"
import json
import os
import urllib.request

payload = {
      "model": "deepseek-v4-flash",
      "messages": [{"role":"user","content":"请用 Hermes agent 在 /host/OpenDeepSeek-Outputs/smoke-agent-route.txt 写入 HOST_READY，只回复文件路径。"}],
      "max_tokens": 500
}
req = urllib.request.Request(
    "http://localhost:8765/v1/chat/completions",
    data=json.dumps(payload).encode("utf-8"),
    headers={
        "Authorization": "Bearer " + os.environ["HERMES_KEY"],
        "Content-Type": "application/json",
    },
)
with urllib.request.urlopen(req, timeout=240) as resp:
    print(resp.read().decode("utf-8"))
PY

HOST_REPLY=$(jq -r '.choices[0].message.content // .choices[0].message.reasoning_content // ""' "$TMP_HOST" 2>/dev/null)
rm -f "$TMP_HOST"

if docker compose exec -T hermes test -f /host/OpenDeepSeek-Outputs/smoke-agent-route.txt \
    && docker compose exec -T hermes grep -q "HOST_READY" /host/OpenDeepSeek-Outputs/smoke-agent-route.txt; then
    ok "Bridge 已把真任务路由到 Hermes，且 Hermes 实际写入 /host 文件"
else
    fail "Hermes Agent 未实际写入 /host 文件"
    echo "    回复: $(echo "$HOST_REPLY" | head -c 200)"
fi

HOST_DISPLAY_PREFIX=$(grep -m1 "^OPDS_HOST_DISPLAY_PREFIX=" .env | cut -d'=' -f2- | sed -E 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^["'"'"']|["'"'"']$//g')
if [[ -n "$HOST_DISPLAY_PREFIX" ]] && [[ "$HOST_DISPLAY_PREFIX" != "/host" ]]; then
    if echo "$HOST_REPLY" | grep -Fq "$HOST_DISPLAY_PREFIX/OpenDeepSeek-Outputs/smoke-agent-route.txt"; then
        ok "Hermes 回复包含用户本机可找路径（不只给 /host 容器路径）"
    else
        fail "Hermes 回复没有包含本机路径提示"
        echo "    期望包含: $HOST_DISPLAY_PREFIX/OpenDeepSeek-Outputs/smoke-agent-route.txt"
        echo "    回复: $(echo "$HOST_REPLY" | head -c 300)"
    fi
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
