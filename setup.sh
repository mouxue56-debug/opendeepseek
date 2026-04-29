#!/bin/bash
set -e

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
    info "是否启用中文优化模式？（启用 SearXNG 搜索引擎 + zh-CN 本地化）"
    read -rp "[Y/n，默认 Y]: " CHINA_MODE
    case "${CHINA_MODE:-Y}" in
        [Nn]*)
            ENABLE_CHINA_MODE="false"
            ;;
        *)
            ENABLE_CHINA_MODE="true"
            ;;
    esac
    if [[ "$ENABLE_CHINA_MODE" == "true" ]]; then
        ok "中文优化模式: 已启用"
    else
        info "中文优化模式: 未启用"
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

    cat > "$ENV_FILE" <<EOF
# OpenDeepSeek 环境配置
# 生成时间：$(date '+%Y-%m-%d %H:%M:%S')

# DeepSeek API（必需）
DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY}

# 模型选择
DEFAULT_MODEL=${DEFAULT_MODEL}

# 自动生成密钥
HERMES_API_KEY=${HERMES_API_KEY}
WEBUI_SECRET_KEY=${WEBUI_SECRET_KEY}

# 中文优化模式
ENABLE_CHINA_MODE=${ENABLE_CHINA_MODE}

# 部署模式（家庭模式 false 跳过登录；团队模式 true 启用 RBAC）
WEBUI_AUTH=${WEBUI_AUTH}
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
    docker compose --profile full up -d
else
    info "启动核心服务（Hermes + Open WebUI）"
    docker compose up -d
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
