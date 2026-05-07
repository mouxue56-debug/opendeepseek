#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

RECORD=false
if [[ "${1:-}" == "--record" ]]; then
  RECORD=true
elif [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
OpenDeepSeek Creator Demo Self-Check

Usage:
  ./scripts/creator-demo.sh
  ./scripts/creator-demo.sh --record
EOF
  exit 0
fi

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TOTAL=8
STEP=0
PORTAL_PID=""
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/opds-creator-demo.XXXXXX")"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
DEMO_CONTAINER_FILE="/host/OpenDeepSeek-Outputs/_demo-check-${TIMESTAMP}.txt"
DEMO_LOCAL_FILE=""
CRON_BEFORE=""
CRON_AFTER=""
CRON_NEW_ID=""

cleanup() {
  if [[ -n "$PORTAL_PID" ]]; then
    kill "$PORTAL_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$DEMO_LOCAL_FILE" && -f "$DEMO_LOCAL_FILE" ]]; then
    rm -f "$DEMO_LOCAL_FILE" || true
  fi
  if [[ -n "$CRON_NEW_ID" ]]; then
    docker compose exec -T hermes python3 - "$CRON_NEW_ID" <<'PY' >/dev/null 2>&1 || true
import json, sys
from pathlib import Path
job_id = sys.argv[1]
paths = [Path("/opt/data/cron/jobs.json"), Path("/opt/data/cron_jobs.json")]
for path in paths:
    if not path.exists():
        continue
    try:
        data = json.loads(path.read_text())
    except Exception:
        continue
    if isinstance(data, list):
        data = [item for item in data if not (isinstance(item, dict) and str(item.get("id")) == job_id)]
    elif isinstance(data, dict):
        data.pop(job_id, None)
        for key in list(data):
            value = data[key]
            if isinstance(value, dict) and str(value.get("id")) == job_id:
                data.pop(key, None)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2))
PY
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

env_value() {
  local key="$1"
  [[ -f .env ]] || return 0
  grep -m1 -E "^${key}=" .env | cut -d'=' -f2- | sed 's/^"//; s/"$//' || true
}

next_step() {
  STEP=$((STEP + 1))
  printf "[%d/%d] %-22s" "$STEP" "$TOTAL" "$1"
}

pass() {
  echo -e "${GREEN}✅ $1${NC}"
}

fail() {
  echo -e "${RED}❌ $1${NC}"
  echo -e "${YELLOW}修复建议：$2${NC}"
  exit 1
}

warn_note() {
  echo -e "${YELLOW}提示：$1${NC}"
}

http_code() {
  curl -L -sS -o /dev/null -w "%{http_code}" --connect-timeout 8 --max-time 20 "$1" 2>/dev/null || true
}

container_status() {
  docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$1" 2>/dev/null || true
}

chat_completion() {
  local model="$1"
  local prompt="$2"
  local out="$3"
  local headers="$4"
  local key
  key="$(env_value HERMES_API_KEY)"
  [[ -n "$key" ]] || fail "缺少 HERMES_API_KEY" "运行 ./setup.sh --web 或 ./setup.sh fix 生成 .env。"
  curl -sS \
    -D "$headers" \
    -o "$out" \
    -H "Authorization: Bearer ${key}" \
    -H "Content-Type: application/json" \
    --connect-timeout 8 \
    --max-time 240 \
    http://127.0.0.1:8770/v1/chat/completions \
    -d "$(python3 - "$model" "$prompt" <<'PY'
import json, sys
model, prompt = sys.argv[1], sys.argv[2]
print(json.dumps({
    "model": model,
    "stream": False,
    "messages": [{"role": "user", "content": prompt}],
}, ensure_ascii=False))
PY
)"
}

json_has_content() {
  python3 - "$1" <<'PY'
import json, sys
try:
    payload = json.load(open(sys.argv[1], encoding="utf-8"))
    text = payload["choices"][0]["message"].get("content") or payload["choices"][0]["message"].get("reasoning_content")
    raise SystemExit(0 if text and str(text).strip() else 1)
except Exception:
    raise SystemExit(1)
PY
}

record_step() {
  local name="$1"
  if [[ "$RECORD" != "true" ]]; then
    return
  fi
  mkdir -p demo/screenshots
  cat > "demo/screenshots/${name}.txt" <<EOF
OpenDeepSeek Creator Demo self-check placeholder
Step: ${name}
Time: $(date '+%Y-%m-%d %H:%M:%S')

No screenshot endpoint is exposed by OpenDeepSeek yet, so this record mode stores a text proof file.
EOF
}

cron_snapshot() {
  docker compose exec -T hermes python3 - <<'PY' 2>/dev/null || true
import json
from pathlib import Path
paths = [Path("/opt/data/cron/jobs.json"), Path("/opt/data/cron_jobs.json")]
for path in paths:
    if path.exists():
        try:
            data = json.loads(path.read_text())
        except Exception:
            data = path.read_text(errors="replace")
        print(json.dumps(data, ensure_ascii=False, sort_keys=True) if not isinstance(data, str) else data)
        break
PY
}

new_cron_id() {
  python3 - "$1" "$2" <<'PY'
import json, sys
before_raw, after_raw = sys.argv[1], sys.argv[2]
def ids(raw):
    try:
        data = json.loads(raw) if raw else None
    except Exception:
        return set()
    found = set()
    def walk(value):
        if isinstance(value, dict):
            if value.get("id"):
                found.add(str(value["id"]))
            for child in value.values():
                walk(child)
        elif isinstance(value, list):
            for child in value:
                walk(child)
    walk(data)
    return found
diff = ids(after_raw) - ids(before_raw)
print(sorted(diff)[0] if diff else "")
PY
}

echo "🎬 OpenDeepSeek Creator Demo Self-Check"
echo

next_step "Git 同步"
git fetch origin >/dev/null 2>&1 || fail "git fetch 失败" "检查网络或 GitHub 权限。"
if [[ -n "$(git log --oneline HEAD..origin/main)" ]]; then
  fail "远端 main 比本地更新" "先检查 git log HEAD..origin/main，不要覆盖用户未确认的远端提交。"
fi
if [[ -n "$(git log --oneline origin/main..HEAD)" ]]; then
  fail "本地提交还没推到 main" "运行 git push origin HEAD:main，或确认当前分支已同步到 GitHub main。"
fi
pass "HEAD = origin/main"
record_step "01-git-sync"

next_step "Gitee 镜像"
GITEE_URL="${OPDS_GITEE_PROJECT_URL:-https://gitee.com/luoxueai/opendeepseek}"
code="$(http_code "$GITEE_URL")"
case "$code" in
  200|301|302) pass "HTTP ${code}" ;;
  *) fail "Gitee 镜像不可达：HTTP ${code:-000}" "去 https://gitee.com/projects/import/url 创建/同步 luoxueai/opendeepseek，或临时设置 OPDS_GITEE_PROJECT_URL。" ;;
esac
record_step "02-gitee"

next_step "Docker stack"
if ! docker info >/dev/null 2>&1; then
  fail "Docker daemon 未运行" "启动 OrbStack/Docker Desktop 后运行 ./setup.sh start。"
fi
missing=()
for container in opendeepseek-hermes opendeepseek-hermes-bridge opendeepseek-webui; do
  status="$(container_status "$container")"
  if [[ "$status" != "healthy" && "$status" != "running" ]]; then
    missing+=("${container}:${status:-missing}")
  fi
done
if [[ "${#missing[@]}" -ne 0 ]]; then
  fail "容器未健康：${missing[*]}" "运行 ./setup.sh start，等待 1-2 分钟后再跑本脚本。"
fi
pass "3 容器 healthy/running"
record_step "03-docker"

next_step "DeepSeek API"
deepseek_key="$(env_value DEEPSEEK_API_KEY)"
[[ -n "$deepseek_key" && "$deepseek_key" != "your-deepseek-api-key-here" ]] || fail "DeepSeek Key 未配置" "运行 ./setup.sh --web 填写 Key。"
deepseek_body="$TMP_DIR/deepseek.json"
deepseek_code="$(curl -sS -o "$deepseek_body" -w "%{http_code}" \
  -H "Authorization: Bearer ${deepseek_key}" \
  -H "Content-Type: application/json" \
  --connect-timeout 8 \
  --max-time 60 \
  "${DEEPSEEK_API_BASE:-https://api.deepseek.com}/v1/chat/completions" \
  -d '{"model":"deepseek-v4-flash","messages":[{"role":"user","content":"只回复一个字：好"}],"stream":false}' 2>/dev/null || true)"
if [[ "$deepseek_code" != "200" ]] || ! json_has_content "$deepseek_body"; then
  fail "DeepSeek API 未返回有效内容（HTTP ${deepseek_code:-000}）" "检查 Key、余额、网络和 DEEPSEEK_API_BASE。错误摘要：$(head -c 240 "$deepseek_body" 2>/dev/null)"
fi
pass "真返回 content"
record_step "04-deepseek"

next_step "Fast 路由"
fast_body="$TMP_DIR/fast.json"
fast_headers="$TMP_DIR/fast.headers"
chat_completion "opendeepseek-fast" "你好，只回复：fast-ok" "$fast_body" "$fast_headers" || fail "Bridge fast 请求失败" "确认 http://127.0.0.1:8770/v1/chat/completions 可达。"
route="$(grep -i '^X-OpenDeepSeek-Route:' "$fast_headers" | tail -1 | tr -d '\r' | awk -F': ' '{print $2}')"
if [[ "$route" != *"lite"* && "$route" != "deepseek-lite" && "$route" != "deepseek-lite"* && "$route" != "custom-lite"* ]]; then
  fail "Fast 路由不是轻量路径：${route:-<missing>}" "检查 Bridge 模型路由和 X-OpenDeepSeek-Route header。"
fi
pass "X-OpenDeepSeek-Route: ${route}"
record_step "05-fast-route"

next_step "Agent 写文件"
host_dir="$(env_value HERMES_HOST_DIR)"
host_dir="${host_dir:-$HOME}"
DEMO_LOCAL_FILE="${host_dir%/}/OpenDeepSeek-Outputs/_demo-check-${TIMESTAMP}.txt"
agent_body="$TMP_DIR/agent-file.json"
agent_headers="$TMP_DIR/agent-file.headers"
chat_completion "opendeepseek-agent" "请实际创建文件 ${DEMO_CONTAINER_FILE}，内容写入 creator-demo-ok。完成前请验证文件存在且大小大于 0，只用中文简短回复。" "$agent_body" "$agent_headers" || fail "Agent 写文件请求失败" "查看 docker compose logs hermes hermes-bridge --tail 120。"
for _ in $(seq 1 20); do
  [[ -s "$DEMO_LOCAL_FILE" ]] && break
  sleep 2
done
if [[ ! -s "$DEMO_LOCAL_FILE" ]]; then
  fail "文件未生成：$DEMO_LOCAL_FILE" "检查 HERMES_HOST_DIR 映射、Hermes file/terminal 工具和 Agent 日志。"
fi
size="$(wc -c < "$DEMO_LOCAL_FILE" | tr -d ' ')"
pass "文件存在 ${size}B"
record_step "06-agent-file"

next_step "Cron Skill"
CRON_BEFORE="$(cron_snapshot)"
cron_body="$TMP_DIR/cron.json"
cron_headers="$TMP_DIR/cron.headers"
chat_completion "opendeepseek-agent" "请实际创建一个 1 小时后的测试提醒：OpenDeepSeek creator demo cron check。请使用 cron/定时任务能力创建，并返回任务 ID。不要只口头答应。" "$cron_body" "$cron_headers" || fail "Cron 请求失败" "查看 Hermes 日志，确认 cron skill 可用。"
sleep 4
CRON_AFTER="$(cron_snapshot)"
CRON_NEW_ID="$(new_cron_id "$CRON_BEFORE" "$CRON_AFTER")"
if [[ -z "$CRON_NEW_ID" ]]; then
  fail "未检测到新的 cron 任务" "进入容器检查 /opt/data/cron/jobs.json，确认 Hermes cron skill 是否启用。"
fi
pass "任务 ID ${CRON_NEW_ID}"
record_step "07-cron"

next_step "Portal :3001"
if lsof -iTCP:3001 -sTCP:LISTEN >/dev/null 2>&1; then
  portal_code="$(http_code http://127.0.0.1:3001)"
else
  python3 onboarding/server.py >"$TMP_DIR/onboarding.log" 2>&1 &
  PORTAL_PID="$!"
  portal_code="000"
  for _ in $(seq 1 20); do
    portal_code="$(http_code http://127.0.0.1:3001)"
    [[ "$portal_code" == "200" ]] && break
    sleep 1
  done
fi
if [[ "$portal_code" != "200" ]]; then
  fail "Portal 不可访问：HTTP ${portal_code}" "运行 ./setup.sh --web，查看 onboarding/server.py 日志。"
fi
pass "HTTP 200"
record_step "08-portal"

echo
echo -e "${GREEN}🎬 全部就绪，开录！${NC}"
