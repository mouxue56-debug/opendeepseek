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
### 1. `.env` 生成未对变量值做引号保护，存在 Bash 注入/截断风险
- **位置**：行 124-134 (`cat > "$ENV_FILE" <<EOF` 块内赋值)
- **问题**：使用无引号 `<<EOF` 会导致 Bash 在写入时展开 `$DEEPSEEK_API_KEY` 中的 `$()`、反引号、`#` 或空格，若用户粘贴的 Key 含特殊字符，将直接破坏 `.env` 结构或执行恶意代码，导致后续容器无法读取凭证。
- **修改**：
  ```bash
  cat > "$ENV_FILE" <<EOF
  # DeepSeek API（必需）
  DEEPSEEK_API_KEY="${DEEPSEEK_API_KEY}"
  
  # 模型选择
  DEFAULT_MODEL="${DEFAULT_MODEL}"
  
  # 自动生成密钥
  HERMES_API_KEY="${HERMES_API_KEY}"
  WEBUI_SECRET_KEY="${WEBUI_SECRET_KEY}"
  
  # 中文优化模式
  ENABLE_CHINA_MODE="${ENABLE_CHINA_MODE}"
  
  # 部署模式
  WEBUI_AUTH="${WEBUI_AUTH}"
  EOF
  ```

### 2. 跳过配置时 `.env` 解析逻辑无法兼容带引号的值
- **位置**：行 162-168 (`grep "^XXX=" ... | cut -d'=' -f2 | tr -d '[:space:]'`)
- **问题**：若历史 `.env` 中值带有引号（如 `ENABLE_CHINA_MODE="true"`），`cut` 提取结果仍含双引号，导致后续 `[[ "$ENABLE_CHINA_MODE" == "true" ]]` 判断恒为假，错误跳过 SearXNG 部署并强制走 `docker compose up -d`。
- **修改**：
  ```bash
  # 替换原有 grep/cut 逻辑为安全解析函数
  _read_env_val() {
      local raw
      raw=$(grep "^$1=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2-)
      echo "${raw//[[:space:]\"\']/}"
  }
  DEFAULT_MODEL=$(_read_env_val DEFAULT_MODEL)
  DEFAULT_MODEL="${DEFAULT_MODEL:-deepseek-v4-flash}"
  ENABLE_CHINA_MODE=$(_read_env_val ENABLE_CHINA_MODE)
  ENABLE_CHINA_MODE="${ENABLE_CHINA_MODE:-false}"
  WEBUI_AUTH=$(_read_env_val WEBUI_AUTH)
  WEBUI_AUTH="${WEBUI_AUTH:-false}"
  ```

## 🟠 改进建议
### 1. 健康检查强依赖 `curl` 但未做环境预检
- **位置**：行 198、208 (`curl -fsS ...`)
- **问题**：部分精简系统（如 Alpine/WSL 基础镜像）默认无 `curl`，结合 `set -e` 会直接报错终止脚本或导致健康检查死循环，破坏“小白零门槛”目标。
- **修改**：
  ```bash
  # 在 Phase 5 前添加依赖检查
  if ! command -v curl &>/dev/null; then
      if command -v wget &>/dev/null; then
          HTTP_PROBE="wget -q --spider -O /dev/null"
      else
          warn "未找到 curl 或 wget，跳过 HTTP 健康检查。建议安装 curl 后重试"
          HTTP_PROBE="false"
      fi
  else
      HTTP_PROBE="curl -fsS"
  fi
  # 后续调用替换为: if $HTTP_PROBE http://localhost:8642/health &>/dev/null; then ...
  ```

### 2. 服务启动未校验 `docker compose` 退出码与端口冲突
- **位置**：行 180-185
- **问题**：若 3000/8642 被占用或镜像拉取失败，Docker 仍可能返回 0 但容器实际未 Running，脚本会误报成功并继续执行，增加排查成本。
- **修改**：
  ```bash
  progress "启动服务..."
  COMPOSE_CMD="docker compose ${[[ "$ENABLE_CHINA_MODE" == "true" ]] && echo '--profile full'} up -d"
  if ! eval "$COMPOSE_CMD" 2>/dev/null; then
      err "Docker Compose 启动失败，请检查端口冲突或网络"
      docker compose ps
      exit 1
  fi
  ok "服务已提交，等待容器初始化..."
  ```

## 🟡 风格质量
### 1. 健康检查超时/间隔参数硬编码
- **位置**：行 199、209 (`for i in $(seq 1 30)` / `sleep 2`)
- **问题**：魔法数字散落多处，不同性能机器（如老旧 NAS 或高性能 Mac）可能需要动态调整，硬编码降低可维护性。
- **修改**：
  ```bash
  # 顶部常量区追加
  HEALTH_MAX_RETRIES=30
  HEALTH_INTERVAL_SEC=2
  # 循环处统一替换
  for i in $(seq 1 "$HEALTH_MAX_RETRIES"); do ... sleep "$HEALTH_INTERVAL_SEC"; done
  ```

### 2. `set -e` 与异步 GUI 打开命令存在潜在竞态
- **位置**：行 255-259 (`sleep 2 && open ... &`)
- **问题**：在严格错误模式下，无头服务器执行 `open`/`xdg-open` 可能返回非零码，子 Shell 报错可能触发脚本意外退出（依赖 Bash 版本）。
- **修改**：
  ```bash
  # 脚本末尾临时放宽错误检查
  set +e
  if command -v open &>/dev/null; then
      ( sleep 2 && open http://localhost:3000 2>/dev/null ) &
  elif command -v xdg-open &>/dev/null; then
      ( sleep 2 && xdg-open http://localhost:3000 2>/dev/null ) &
  fi
  set -e
  ```
