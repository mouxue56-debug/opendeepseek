Config warnings:
- plugins.entries.openclaw-wechat: plugin openclaw-wechat: channel plugin manifest declares wecom without channelConfigs metadata; add openclaw.plugin.json#channelConfigs so config schema and setup surfaces work before runtime loads
- plugins.entries.openclaw-wechat: plugin openclaw-wechat: channel plugin manifest declares wecom without channelConfigs metadata; add openclaw.plugin.json#channelConfigs so config schema and setup surfaces work before runtime loads
│
◇  Config warnings ───────────────────────────────────────────────────────╮
│                                                                         │
│  - plugins.entries.openclaw-wechat: plugin openclaw-wechat: channel     │
│    plugin manifest declares wecom without channelConfigs metadata; add  │
│    openclaw.plugin.json#channelConfigs so config schema and setup       │
│    surfaces work before runtime loads                                   │
│  - plugins.entries.openclaw-wechat: plugin openclaw-wechat: channel     │
│    plugin manifest declares wecom without channelConfigs metadata; add  │
│    openclaw.plugin.json#channelConfigs so config schema and setup       │
│    surfaces work before runtime loads                                   │
│                                                                         │
├─────────────────────────────────────────────────────────────────────────╯
model.run via local
provider: coding-plan-intl
model: qwen3.6-plus
outputs: 1
## 🔴 严重问题
### 1. `.env` 键值提取未清理引号与空格导致鉴权失败
- **位置**：第 38 行 (`HERMES_KEY=...`)
- **问题**：`cut -d'=' -f2` 会保留 `.env` 中常见的值包裹引号（如 `HERMES_API_KEY="sk-xxx"`）或末尾空格，生成非法的 `Authorization: Bearer "sk-xxx"`，Hermes 鉴权必然拒绝。
- **修改**：
  ```diff
  - HERMES_KEY=$(grep "^HERMES_API_KEY=" .env | cut -d'=' -f2)
  + HERMES_KEY=$(grep -m1 "^HERMES_API_KEY=" .env | cut -d'=' -f2- | sed -E 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^["\x27]|["\x27]$//g')
  ```

### 2. 未校验执行目录导致 Docker Compose 上下文错乱
- **位置**：第 23 行 (`docker compose ps...`)
- **问题**：脚本未验证是否在 `docker-compose.yml` 所在根目录运行。若在 `scripts/` 或其他路径执行，`docker compose` 将找不到项目上下文或使用错误配置，导致容器状态检查全损。
- **修改**：
  ```diff
  + # Step 2 前添加上下文校验
  + SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  + cd "$SCRIPT_DIR/.." || exit 1
  + if [[ ! -f "docker-compose.yml" ]]; then
  +   echo -e "${RED}❌ 未找到 docker-compose.yml，请在项目根目录运行此脚本${NC}"
  +   exit 1
  + fi
  ```

## 🟠 改进建议
### 1. `.env` 检查未排除注释行与格式变体
- **位置**：第 19 行 (`grep -q "DEEPSEEK_API_KEY=" .env`)
- **问题**：会误匹配注释行（如 `# DEEPSEEK_API_KEY=...`）或带空格的格式（`DEEPSEEK_API_KEY = xxx`），导致误报配置就绪。
- **修改**：
  ```diff
  - grep -q "DEEPSEEK_API_KEY=" .env
  + grep -v '^\s*#' .env | grep -qE "^DEEPSEEK_API_KEY[[:space:]]*="
  ```

### 2. JSON 响应变量未加引号触发 Word Splitting
- **位置**：第 58 行 (`echo $CHAT_RESP | head ...`)
- **问题**：`$CHAT_RESP` 未用双引号包裹，若 API 返回内容含 `*`、`?` 或多行结构，Bash 会执行路径扩展与单词拆分，导致日志输出混乱或报错。
- **修改**：
  ```diff
  - echo $CHAT_RESP | head -c 200
  + echo "$CHAT_RESP" | head -c 200
  ```

### 3. 重复调用 `docker compose ps` 增加 I/O 与状态不一致风险
- **位置**：第 23, 28 行
- **问题**：连续两次执行外部命令获取容器列表，在容器启停瞬态期间可能返回不一致结果，且浪费性能。
- **修改**：
  ```diff
  + COMPOSE_RUNNING=$(docker compose ps --status running --format json 2>/dev/null)
    if echo "$COMPOSE_RUNNING" | grep -q opendeepseek-hermes; then
        ok "hermes 容器运行中"
    else
        fail "hermes 容器未运行（试试 docker compose up -d）"
    fi

    if echo "$COMPOSE_RUNNING" | grep -q opendeepseek-webui; then
        ok "open-webui 容器运行中"
    else
        fail "open-webui 容器未运行"
    fi
  ```

## 🟡 风格质量
### 1. `set -e` 与 Smoke Test 预期失败语义冲突
- **位置**：第 4 行 (`set -e`)
- **问题**：健康检查脚本应容忍预期内的失败（如服务未就绪）。`set -e` 虽被 `||` 绕过，但会掩盖未显式处理的中间命令退出码，降低调试透明度。建议移除，由显式 `exit` 控制流。
- **修改**：
  ```diff
  - set -e
  + # 移除 set -e，改用显式 if/else 与 exit 控制，提升 Smoke Test 容错与可读性
  ```

### 2. 依赖字符串 `grep` 解析 JSON 结构脆弱
- **位置**：第 42 行 (`grep -q '"object".*"list"' ...`)
- **问题**：OpenAI 兼容协议的 JSON 字段顺序或空格可能变更，字符串硬匹配易误判。建议收紧正则匹配核心数组标识，避免冗余检查。
- **修改**：
  ```diff
  - if echo "$MODELS_RESP" | grep -q '"object".*"list"' || echo "$MODELS_RESP" | grep -q '"data"'; then
  + if echo "$MODELS_RESP" | grep -qE '"data"\s*:\s*\['; then
  ```
