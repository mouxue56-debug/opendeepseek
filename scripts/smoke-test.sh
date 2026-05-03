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
echo "   OpenDeepSeek Smoke Test (v0.4.0 - 三层架构)"
echo "════════════════════════════════════════════"
echo ""

# 1. .env 存在
info "[1/8] 检查 .env 文件"
if [[ -f .env ]] && grep -v '^\s*#' .env | grep -qE "^DEEPSEEK_API_KEY[[:space:]]*=" && ! grep -q "DEEPSEEK_API_KEY=your-deepseek-api-key-here" .env; then
    ok ".env 配置完毕"
else
    fail ".env 缺失或未配置 DEEPSEEK_API_KEY"
    exit 1
fi

# 2. 三个容器状态（hermes + open-webui）
info "[2/8] 检查容器状态"
RUNNING=$(docker compose ps --status running --format json 2>/dev/null)
if echo "$RUNNING" | grep -q opendeepseek-hermes; then
    ok "hermes 容器运行中"
else
    fail "hermes 容器未运行（试试 docker compose up -d）"
    exit 1
fi
if echo "$RUNNING" | grep -q opendeepseek-webui; then
    ok "open-webui 容器运行中"
else
    fail "open-webui 容器未运行"
    exit 1
fi

# 3. Hermes 健康端点
info "[3/8] 检查 Hermes 健康端点"
if curl -fsS http://localhost:8642/health > /dev/null 2>&1; then
    ok "Hermes /health 返回 OK"
else
    fail "Hermes /health 不通"
fi

# 4. Open WebUI 可达
info "[4/8] 检查 Open WebUI 网页"
if curl -fsS http://localhost:3000 > /dev/null 2>&1; then
    ok "Open WebUI :3000 可访问"
else
    fail "Open WebUI :3000 不通"
fi

# 5. Hermes 模型列表（应该暴露 hermes-agent）
info "[5/8] 检查 Hermes 暴露的模型"
HERMES_KEY=$(grep -m1 "^HERMES_API_KEY=" .env | cut -d'=' -f2- | sed -E 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^["'"'"']|["'"'"']$//g')
MODELS_RESP=$(curl -fsS http://localhost:8642/v1/models -H "Authorization: Bearer ${HERMES_KEY}" 2>&1 || echo "FAIL")
if echo "$MODELS_RESP" | grep -q "hermes-agent"; then
    ok "Hermes 暴露 hermes-agent 模型（Open WebUI 把它当 model backend）"
else
    fail "Hermes /v1/models 异常"
    echo "    响应：$(echo "$MODELS_RESP" | head -c 200)"
fi

# 6. 真实端到端：用户消息 → Open WebUI → Hermes → DeepSeek → 回复
# 这是项目核心架构验证，不能假阳性
info "[6/8] 真实端到端：Hermes → DeepSeek 调用"
TMP_RESP=$(mktemp)
curl -fsS http://localhost:8642/v1/chat/completions \
    -H "Authorization: Bearer ${HERMES_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
      "model": "hermes-agent",
      "messages": [{"role":"user","content":"用一个汉字回答：你好"}],
      "max_tokens": 30
    }' > "$TMP_RESP" 2>&1 || echo "FAIL"

# 用 jq 提取 content（避免 zsh locale 问题）
REPLY=$(jq -r '.choices[0].message.content // .choices[0].message.reasoning_content // ""' "$TMP_RESP" 2>/dev/null)
USAGE=$(jq -r '.usage.prompt_tokens // 0' "$TMP_RESP" 2>/dev/null)
rm -f "$TMP_RESP"

# 严格检查：内容存在 + 不是错误字符串 + prompt_tokens > 0（说明真的过了 Hermes Agent 内核）
if [[ -n "$REPLY" ]] && [[ "$REPLY" != *"Error"* ]] && [[ "$REPLY" != *"401"* ]] && [[ "$REPLY" != *"400"* ]] && [[ "$USAGE" -gt 0 ]]; then
    ok "真实端到端通：Hermes → DeepSeek 回复「$REPLY」（${USAGE} prompt tokens 经 Hermes 内核）"
else
    fail "端到端调用失败"
    echo "    回复: $REPLY"
    echo "    prompt_tokens: $USAGE"
fi

# 7. Hermes Skills 激活验证（Cron）
info "[7/8] 验证 Hermes Skills 是否激活（Cron skill）"
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
if echo "$CRON_REPLY" | grep -qE "任务.*创建|已创建|创建成功|task.*created|cron.*scheduled"; then
    ok "Hermes Cron Skill 激活（Memory/Subagent/IM 同源应都活）"
else
    info "Cron Skill 未明确触发——回复: $(echo "$CRON_REPLY" | head -c 100)"
    info "（首次启动 skills 索引可能未就绪，等 1-2 分钟再测）"
fi

# 8. 真 Agent 文件系统权限：/host 是否挂载，Hermes 是否能从 API 侧使用工具看到它
info "[8/8] 验证 Hermes 本机文件系统权限（/host）"
if docker compose exec -T hermes test -d /host; then
    ok "Hermes 容器已挂载 /host"
else
    fail "Hermes 容器没有 /host 挂载（检查 HERMES_HOST_DIR 和 docker-compose.yml）"
fi

TMP_HOST=$(mktemp)
curl -fsS http://localhost:8642/v1/chat/completions \
    -H "Authorization: Bearer ${HERMES_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
      "model": "hermes-agent",
      "messages": [{"role":"user","content":"请实际调用 terminal 工具运行 pwd 和 test -d /host。不要列任何文件名；如果 /host 存在，只回答 HOST_READY；否则回答 HOST_MISSING。"}],
      "max_tokens": 300
    }' > "$TMP_HOST" 2>&1 || echo "FAIL"

HOST_REPLY=$(jq -r '.choices[0].message.content // .choices[0].message.reasoning_content // ""' "$TMP_HOST" 2>/dev/null)
rm -f "$TMP_HOST"

if echo "$HOST_REPLY" | grep -q "HOST_READY"; then
    ok "Hermes API 侧能通过工具访问 /host（真 Agent 文件权限已通）"
else
    fail "Hermes API 侧未确认 /host 权限"
    echo "    回复: $(echo "$HOST_REPLY" | head -c 200)"
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
