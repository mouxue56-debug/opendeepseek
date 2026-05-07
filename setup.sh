#!/bin/bash
set -e

# 解析参数：
#   --web       浏览器图形界面引导（推荐小白）
#   --advanced  命令行完整询问（5 项配置）
#   默认        命令行极简（只问 API Key）
SETUP_MODE="simple"
if [[ "${1:-}" == "--advanced" || "${1:-}" == "-a" ]]; then
    SETUP_MODE="advanced"
elif [[ "${1:-}" == "--web" || "${1:-}" == "-w" ]]; then
    SETUP_MODE="web"
fi

compose_up() {
    local profile_args=()
    if [[ "${1:-}" == "full" ]]; then
        profile_args=(--profile full)
    fi

    # hermes-bridge is local glue code. Rebuild it on start so users do not run
    # a stale cached image after pulling fixes.
    docker compose "${profile_args[@]}" build hermes-bridge
    docker compose "${profile_args[@]}" up -d
}

if [[ "${1:-}" == "verify" || "${1:-}" == "--verify" ]]; then
    if ! command -v python3 &>/dev/null; then
        echo "❌ verify 需要 python3"
        exit 1
    fi
    exec python3 scripts/verify_config.py
fi

if [[ "${1:-}" == "verify-live" || "${1:-}" == "--verify-live" ]]; then
    if ! command -v python3 &>/dev/null; then
        echo "❌ verify-live 需要 python3"
        exit 1
    fi
    exec python3 scripts/provider-live-check.py
fi

if [[ "${1:-}" == "doctor" || "${1:-}" == "--doctor" ]]; then
    if ! command -v python3 &>/dev/null; then
        echo "❌ doctor 需要 python3"
        exit 1
    fi
    exec python3 scripts/doctor.py
fi

if [[ "${1:-}" == "doctor-cn" || "${1:-}" == "--doctor-cn" ]]; then
    if ! command -v python3 &>/dev/null; then
        echo "❌ doctor-cn 需要 python3"
        exit 1
    fi
    exec python3 scripts/doctor.py --cn
fi

if [[ "${1:-}" == "report" || "${1:-}" == "--report" ]]; then
    if ! command -v python3 &>/dev/null; then
        echo "❌ report 需要 python3"
        exit 1
    fi
    exec python3 scripts/doctor.py --report
fi

if [[ "${1:-}" == "fix" || "${1:-}" == "--fix" ]]; then
    if ! command -v python3 &>/dev/null; then
        echo "❌ fix 需要 python3"
        exit 1
    fi
    exec python3 scripts/doctor.py --fix
fi

if [[ "${1:-}" == "start" || "${1:-}" == "start-lite" || "${1:-}" == "--start" ]]; then
    echo "启动 OpenDeepSeek 轻量核心服务（不含 SearXNG full profile）..."
    compose_up
    exit $?
fi

if [[ "${1:-}" == "start-full" || "${1:-}" == "--start-full" ]]; then
    echo "启动 OpenDeepSeek 完整服务（含 SearXNG，低内存电脑可能变卡）..."
    compose_up full
    exit $?
fi

if [[ "${1:-}" == "stop" || "${1:-}" == "down" || "${1:-}" == "--stop" ]]; then
    echo "停止 OpenDeepSeek 容器（不删除聊天记录和 volume）..."
    exec docker compose down
fi

if [[ "${1:-}" == "stats" || "${1:-}" == "--stats" ]]; then
    exec docker stats --no-stream
fi

# Web 模式：启动浏览器 onboarding wizard
if [[ "$SETUP_MODE" == "web" ]]; then
    if ! command -v python3 &>/dev/null; then
        echo "❌ Web 模式需要 python3（macOS/Linux 自带）"
        echo "请改用命令行模式: ./setup.sh"
        exit 1
    fi
    if [[ ! -f "onboarding/server.py" ]]; then
        echo "❌ onboarding/server.py 不存在，请确保完整克隆了项目"
        exit 1
    fi

    echo ""
    echo "启动 OpenDeepSeek Web 安装向导..."
    echo "   浏览器会自动打开 http://localhost:3001"
    echo "   按 Ctrl+C 取消"
    echo ""

    # 自动开浏览器
    if command -v open &>/dev/null; then
        ( sleep 2 && open http://localhost:3001 ) &
    elif command -v xdg-open &>/dev/null; then
        ( sleep 2 && xdg-open http://localhost:3001 2>/dev/null ) &
    fi

    # 启动 onboarding server（阻塞）— 它会处理 API key 输入 + 启动 docker compose
    exec python3 onboarding/server.py
fi

# ============================================================
# OpenDeepSeek — One-Click Setup
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

STEP=0
TOTAL=6

progress() {
    STEP=$((STEP + 1))
    echo -e "${BLUE}[${STEP}/${TOTAL}]${NC} $1"
}

info() {
    echo -e "${CYAN}ℹ${NC}  $1"
}

warn() {
    echo -e "${YELLOW}⚠${NC}  $1"
}

ok() {
    echo -e "${GREEN}✅${NC} $1"
}

err() {
    echo -e "${RED}❌${NC} $1"
}

# ============================================================
# Phase 1: Environment Check
# ============================================================
progress "检查 Docker 环境..."

if ! command -v docker &>/dev/null; then
    err "Docker 未安装"
    echo ""
    info "安装提示："
    echo "  • macOS:    brew install --cask docker"
    echo "  • Linux:    curl -fsSL https://get.docker.com | sh"
    echo ""
    err "请先安装 Docker 后重新运行本脚本"
    exit 1
fi
ok "Docker 已安装"

if ! docker compose version &>/dev/null; then
    err "Docker Compose (plugin) 不可用"
    echo ""
    info "请确保 Docker Desktop ≥ 4.x 或 Docker Engine ≥ 20.10"
    err "Docker Compose 插件缺失"
    exit 1
fi
ok "Docker Compose 可用"

# ============================================================
# Phase 2: Interactive Configuration
# ============================================================
progress "配置参数..."

if [[ "$SETUP_MODE" == "simple" ]]; then
    info "极简模式：只需输入 API Key（其他自动智能默认）"
    info "高级模式：./setup.sh --advanced（保留所有询问）"
fi

info "默认采用'家庭单用户模式'：访问 http://localhost:3000 无需注册即可使用"
info "如需团队多用户模式（含登录注册），稍后选择部署模式时选 2"

ENV_FILE=".env"
if [[ -f "$ENV_FILE" ]]; then
    warn "检测到已存在的 .env 文件"
    read -rp "是否重新配置？ [y/N]: " REUSE
    if [[ ! "$REUSE" =~ ^[Yy]$ ]]; then
        info "保留现有配置，跳过配置阶段"
        SKIP_CONFIG=1
    else
        info "将重新生成 .env"
    fi
fi

if [[ -z "$SKIP_CONFIG" ]]; then
    if [[ "$SETUP_MODE" == "simple" ]]; then
        # ── 极简模式：只问 API key ──
        echo ""
        info "正在配置（默认家庭模式 + 中文界面 + 轻量核心服务 + DeepSeek V4 Flash）"
        info "如需调整，下次跑 ./setup.sh --advanced"
        echo ""
        info "请粘贴你的 DeepSeek API Key（platform.deepseek.com 注册免费获取）"
        read -rsp "API Key: " DEEPSEEK_API_KEY
        echo ""
        if [[ -z "$DEEPSEEK_API_KEY" ]]; then
            err "API Key 不能为空"
            exit 1
        fi
        ok "API Key 已接收"

        # 智能默认
        DEFAULT_MODEL="deepseek-v4-flash"
        ENABLE_CHINA_MODE="false"
        ADD_IM_PLACEHOLDER=0
        WEBUI_AUTH="false"
        DEPLOY_MODE_LABEL="家庭单用户"
        ok "已自动选择：家庭单用户模式（零门槛访问）+ 轻量核心服务 + DeepSeek V4 Flash"
    else
        # ── 高级模式：保留现有 5 问题完整流程 ──

        # 1. DeepSeek API Key
        echo ""
        info "请输入 DeepSeek API Key（获取地址：https://platform.deepseek.com/api_keys）"
        read -rsp "DeepSeek API Key: " DEEPSEEK_API_KEY
        echo ""
        if [[ -z "$DEEPSEEK_API_KEY" ]]; then
            err "DeepSeek API Key 不能为空"
            exit 1
        fi
        ok "API Key 已接收"

        # 2. Model selection
        echo ""
        info "选择默认模型："
        echo "  1) deepseek-v4-flash（推荐，便宜快速）"
        echo "  2) deepseek-v4-pro（推理更强）"
        read -rp "请输入选项 [1/2，默认 1]: " MODEL_CHOICE
        case "${MODEL_CHOICE:-1}" in
            2)
                DEFAULT_MODEL="deepseek-v4-pro"
                ;;
            1|"")
                DEFAULT_MODEL="deepseek-v4-flash"
                ;;
            *)
                warn "无效选项，使用默认模型 deepseek-v4-flash"
                DEFAULT_MODEL="deepseek-v4-flash"
                ;;
        esac
        ok "默认模型: ${DEFAULT_MODEL}"

        # 3. China mode
        echo ""
        info "是否启动联网搜索服务 SearXNG？（会额外占内存；低内存电脑建议先不开）"
        read -rp "[y/N，默认 N]: " CHINA_MODE
        case "${CHINA_MODE:-N}" in
            [Yy]*)
                ENABLE_CHINA_MODE="true"
                ;;
            *)
                ENABLE_CHINA_MODE="false"
                ;;
        esac
        if [[ "$ENABLE_CHINA_MODE" == "true" ]]; then
            ok "联网搜索服务: 将随 full profile 启动"
        else
            info "联网搜索服务: 默认不启动，需要时可运行 ./setup.sh start-full"
        fi

        # 4. Deploy mode
        echo ""
        info "选择部署模式："
        echo "  1) 家庭单用户（推荐，零登录门槛）"
        echo "  2) 团队多用户（需注册管理员账号）"
        read -rp "请输入选项 [1/2，默认 1]: " DEPLOY_MODE_CHOICE
        case "${DEPLOY_MODE_CHOICE:-1}" in
            2)
                WEBUI_AUTH="true"
                DEPLOY_MODE_LABEL="团队多用户"
                ;;
            *)
                WEBUI_AUTH="false"
                DEPLOY_MODE_LABEL="家庭单用户"
                ;;
        esac
        ok "部署模式: ${DEPLOY_MODE_LABEL}"

        # 5. IM placeholder
        echo ""
        info "OpenDeepSeek 支持把 Agent 接入钉钉/飞书/企微/邮件/QQ Bot/Matrix"
        info "（需要后续在 .env 里配置 Bot Token）"
        read -rp "是否现在添加 IM 配置占位模板？ [y/N，默认 N]: " IM_MODE
        if [[ "$IM_MODE" =~ ^[Yy]$ ]]; then
            ADD_IM_PLACEHOLDER=1
            ok "IM 占位配置将写入 .env"
        else
            ADD_IM_PLACEHOLDER=0
            info "IM 配置跳过（后续可手动添加）"
        fi
    fi

    # ============================================================
    # Phase 3: Generate .env
    # ============================================================
    progress "生成 .env 配置文件..."

    # Generate random keys
    if command -v openssl &>/dev/null; then
        HERMES_API_KEY=$(openssl rand -hex 32)
        WEBUI_SECRET_KEY=$(openssl rand -hex 32)
    else
        HERMES_API_KEY=$(head -c 32 /dev/urandom | base64 | tr -d '=+/')
        WEBUI_SECRET_KEY=$(head -c 32 /dev/urandom | base64 | tr -d '=+/')
    fi

    HERMES_HOST_DIR="${HOME}"

    cat > "$ENV_FILE" <<EOF
# OpenDeepSeek 环境配置
# 生成时间：$(date '+%Y-%m-%d %H:%M:%S')

# DeepSeek API（必需）
DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY}
DEEPSEEK_API_BASE=https://api.deepseek.com

# LLM Provider：Open WebUI 永远连接 Smart Bridge；Bridge/Hermes 决定背后 Provider。
OPDS_LLM_PROVIDER=deepseek
OPDS_LLM_BASE_URL=https://api.deepseek.com
OPDS_LLM_API_KEY=${DEEPSEEK_API_KEY}
OPDS_LLM_MODEL=${DEFAULT_MODEL}
OPDS_LLM_PRO_MODEL=deepseek-v4-pro
OPDS_CUSTOM_LLM_BASE_URL=
OPDS_CUSTOM_LLM_API_KEY=
OPDS_CUSTOM_LLM_MODEL=
OPDS_CUSTOM_LLM_PRO_MODEL=
HERMES_INFERENCE_PROVIDER=deepseek
CUSTOM_MODEL_BASE_URL=
CUSTOM_MODEL_API_KEY=
CUSTOM_MODEL_NAME=

# 模型选择
DEFAULT_MODEL=${DEFAULT_MODEL}

# 速度优先：关闭 Open WebUI 额外标题/标签/追问生成，避免一次对话触发多轮 hermes-agent。
ENABLE_TITLE_GENERATION=false
ENABLE_TAGS_GENERATION=false
ENABLE_FOLLOW_UP_GENERATION=false
ENABLE_CODE_INTERPRETER=false
ENABLE_RAG_HYBRID_SEARCH=false
ENABLE_LIGHTWEIGHT_ROUTING=true
HERMES_AGENT_MAX_TOKENS=32768
HERMES_AGENT_STREAM=false
HERMES_PROGRESS_STREAM=true
HERMES_MAX_ITERATIONS=24
HERMES_API_TIMEOUT=300
HERMES_API_CALL_STALE_TIMEOUT=120
IMAGE_BRIDGE_TIMEOUT=600
OPDS_REALTIME_SEARCH_ENABLED=true
OPDS_REALTIME_SEARCH_URL=http://searxng:8080/search?q={query}&format=json
OPDS_REALTIME_SEARCH_TIMEOUT=4
OPDS_REALTIME_SEARCH_MAX_RESULTS=6
OPDS_DELEGATE_OPENWEBUI_NATIVE_TOOLS=true
ENABLE_RAG_WEB_SEARCH=${ENABLE_CHINA_MODE}
HERMES_CPUS=1.5
HERMES_MEMORY_LIMIT=1280m
WEBUI_CPUS=1.0
WEBUI_MEMORY_LIMIT=1024m
BRIDGE_CPUS=0.5
BRIDGE_MEMORY_LIMIT=256m
SEARXNG_CPUS=0.5
SEARXNG_MEMORY_LIMIT=384m
OPDS_SHARED_MEMORY_PATH=/host/OpenDeepSeek-Memory/profile.md
OPDS_MEMORY_SNAPSHOT_MAX_CHARS=4000
OPDS_HOST_DISPLAY_PREFIX=${HERMES_HOST_DIR}

# 自动生成密钥
HERMES_API_KEY=${HERMES_API_KEY}
WEBUI_SECRET_KEY=${WEBUI_SECRET_KEY}

# 中文优化模式
ENABLE_CHINA_MODE=${ENABLE_CHINA_MODE}

# 部署模式（家庭模式 false 跳过登录；团队模式 true 启用 RBAC）
WEBUI_AUTH=${WEBUI_AUTH}

# 真 Agent 文件系统权限
# 容器内路径 /host 会指向这里；例如你的桌面是 /host/Desktop
# 如果想收窄权限，把它改成某个专用文件夹，例如 ./agent-files
HERMES_HOST_DIR=${HERMES_HOST_DIR}
EOF

    if [[ "$ADD_IM_PLACEHOLDER" -eq 1 ]]; then
        cat >> "$ENV_FILE" <<'EOF'

# IM 桥接（可选，按需取消注释填入）
# DINGTALK_CLIENT_ID=
# DINGTALK_CLIENT_SECRET=
# FEISHU_APP_ID=
# FEISHU_APP_SECRET=
# WECOM_BOT_ID=
# WECOM_SECRET=
# EMAIL_ADDRESS=
# EMAIL_PASSWORD=
# EMAIL_IMAP_HOST=
# EMAIL_SMTP_HOST=
# QQ_APP_ID=
# QQ_CLIENT_SECRET=
EOF
    fi

    ok ".env 已生成"
else
    # Read existing values for display
    if [[ -f "$ENV_FILE" ]]; then
        DEFAULT_MODEL=$(grep "^DEFAULT_MODEL=" "$ENV_FILE" | cut -d'=' -f2 | tr -d '[:space:]')
        DEFAULT_MODEL="${DEFAULT_MODEL:-deepseek-v4-flash}"
        ENABLE_CHINA_MODE=$(grep "^ENABLE_CHINA_MODE=" "$ENV_FILE" | cut -d'=' -f2 | tr -d '[:space:]')
        ENABLE_CHINA_MODE="${ENABLE_CHINA_MODE:-false}"
        WEBUI_AUTH=$(grep "^WEBUI_AUTH=" "$ENV_FILE" | cut -d'=' -f2 | tr -d '[:space:]')
        WEBUI_AUTH="${WEBUI_AUTH:-false}"
    fi
fi

# ============================================================
# Phase 4: Start Services
# ============================================================
progress "启动服务..."

if [[ "$ENABLE_CHINA_MODE" == "true" ]]; then
    info "使用 --profile full 启动（含 SearXNG）"
    compose_up full
else
    info "启动核心服务（Hermes + Open WebUI）"
    compose_up
fi

ok "服务已启动"

# ============================================================
# Phase 5: Health Check
# ============================================================
progress "等待服务就绪..."

# Wait for Hermes (max 60s)
info "检查 Hermes 服务 (http://localhost:8642/health)..."
HERMES_READY=0
for i in $(seq 1 30); do
    if curl -fsS http://localhost:8642/health &>/dev/null; then
        HERMES_READY=1
        break
    fi
    sleep 2
done

if [[ "$HERMES_READY" -eq 1 ]]; then
    ok "Hermes 就绪"
    # 🔧 修复 Hermes config.yaml 默认 model（首次启动后）
    # Hermes 镜像默认 model 是 anthropic/claude-opus-4.6，但 DeepSeek 只接受 v4-flash/v4-pro
    if [[ -x "scripts/hermes-fix-model.sh" ]]; then
        info "应用 Hermes 默认 model 修复（首次启动需要）..."
        ./scripts/hermes-fix-model.sh "${DEFAULT_MODEL:-deepseek-v4-flash}" || warn "model 修复脚本失败，请手动运行 ./scripts/hermes-fix-model.sh"
    fi
else
    warn "Hermes 在 60 秒内未就绪，请稍后手动检查"
fi

# Wait for Open WebUI (max 30s)
info "检查 Open WebUI (http://localhost:3000)..."
WEBUI_READY=0
for i in $(seq 1 15); do
    if curl -fsS http://localhost:3000 &>/dev/null; then
        WEBUI_READY=1
        break
    fi
    sleep 2
done

if [[ "$WEBUI_READY" -eq 1 ]]; then
    ok "Open WebUI 就绪"
else
    warn "Open WebUI 在 30 秒内未就绪，请稍后手动检查"
fi

# ============================================================
# Phase 6: Access Information
# ============================================================
progress "部署完成"

echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}     🚀 OpenDeepSeek 已成功启动${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}本地访问${NC}    http://localhost:3000"
echo -e "  ${CYAN}Hermes API${NC}  http://localhost:8642"

# Tailscale check
if command -v tailscale &>/dev/null; then
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || true)
    if [[ -n "$TAILSCALE_IP" ]]; then
        echo -e "  ${CYAN}远程访问${NC}  http://${TAILSCALE_IP}:3000  (Tailscale)"
    fi
fi

echo ""
if [[ "${WEBUI_AUTH:-false}" == "false" ]]; then
    echo -e "  ${CYAN}访问方式${NC}    无需登录，打开浏览器直接使用"
else
    echo -e "  ${YELLOW}首次访问需注册管理员账号${NC}"
fi
echo ""
if [[ "$SETUP_MODE" == "simple" ]]; then
    echo -e "  ${YELLOW}下次想调整模式？${NC}  ./setup.sh --advanced"
    echo ""
fi
echo -e "${GREEN}──────────────────────────────────────────────────────${NC}"
echo -e "${GREEN}常用命令${NC}"
echo -e "${GREEN}──────────────────────────────────────────────────────${NC}"
echo ""
echo "  查看日志      docker compose logs -f"
echo "  停止服务      docker compose down"
echo "  重启服务      docker compose restart"
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"

# 自动开浏览器（macOS / Linux）
if command -v open &>/dev/null; then
    info "自动打开浏览器..."
    sleep 2 && open http://localhost:3000 &
elif command -v xdg-open &>/dev/null; then
    info "自动打开浏览器..."
    sleep 2 && xdg-open http://localhost:3000 &>/dev/null &
fi
