#!/usr/bin/env bash
# OpenDeepSeek 一键远程安装
# 用法：curl -fsSL https://raw.githubusercontent.com/yourusername/opendeepseek/main/install.sh | bash
# 或：bash <(curl -fsSL https://raw.githubusercontent.com/yourusername/opendeepseek/main/install.sh)

set -euo pipefail

# ============================================================
# 颜色 / 输出工具
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { printf "${CYAN}  >>>${NC} %s\n" "$*"; }
ok()    { printf "${GREEN}  [ok]${NC} %s\n" "$*"; }
warn()  { printf "${YELLOW}  [!]${NC}  %s\n" "$*"; }
err()   { printf "${RED}  [ERR]${NC} %s\n" "$*" >&2; }
die()   { err "$*"; exit 1; }
hr()    { printf "${BLUE}%s${NC}\n" "──────────────────────────────────────────────────────"; }

# ============================================================
# 清理钩子
# ============================================================
INSTALL_DIR=""
CLEANUP_ON_EXIT=0

_cleanup() {
  if [[ "$CLEANUP_ON_EXIT" -eq 1 && -n "$INSTALL_DIR" && -d "$INSTALL_DIR" ]]; then
    warn "安装中止，清理残留目录: $INSTALL_DIR"
    rm -rf "$INSTALL_DIR"
  fi
}
trap _cleanup EXIT

# ============================================================
# Phase 1: 横幅
# ============================================================
printf "\n"
printf "${BOLD}${BLUE}"
printf "  ██████╗ ██████╗ ███████╗███╗   ██╗██████╗ ███████╗███████╗██████╗ \n"
printf " ██╔═══██╗██╔══██╗██╔════╝████╗  ██║██╔══██╗██╔════╝██╔════╝██╔══██╗\n"
printf " ██║   ██║██████╔╝█████╗  ██╔██╗ ██║██║  ██║█████╗  █████╗  ██████╔╝\n"
printf " ██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║██║  ██║██╔══╝  ██╔══╝  ██╔═══╝ \n"
printf " ╚██████╔╝██║     ███████╗██║ ╚████║██████╔╝███████╗███████╗██║     \n"
printf "  ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝╚═════╝ ╚══════╝╚══════╝╚═╝     \n"
printf "${NC}"
printf "${CYAN}         DeepSeek AI  •  Open WebUI  •  一键部署${NC}\n"
printf "\n"
hr

# ============================================================
# Phase 1: 检测 OS
# ============================================================
printf "\n"
info "检测系统环境..."

OS_TYPE=""
DISTRO=""
PKG_INSTALL=""

case "$(uname -s)" in
  Darwin)
    OS_TYPE="macos"
    PKG_INSTALL="brew install"
    ok "macOS 已识别"
    ;;
  Linux)
    # WSL2 检测
    if grep -qi "microsoft" /proc/version 2>/dev/null; then
      OS_TYPE="wsl2"
      info "WSL2 环境已识别，按 Linux 路径继续"
    else
      OS_TYPE="linux"
    fi

    if command -v apt-get &>/dev/null; then
      DISTRO="debian"
      PKG_INSTALL="sudo apt-get install -y"
    elif command -v dnf &>/dev/null; then
      DISTRO="fedora"
      PKG_INSTALL="sudo dnf install -y"
    elif command -v yum &>/dev/null; then
      DISTRO="centos"
      PKG_INSTALL="sudo yum install -y"
    elif command -v pacman &>/dev/null; then
      DISTRO="arch"
      PKG_INSTALL="sudo pacman -S --noconfirm"
    else
      DISTRO="unknown"
      PKG_INSTALL="your-package-manager install"
    fi
    ok "Linux ($DISTRO) 已识别"
    ;;
  *)
    die "不支持的操作系统: $(uname -s)。仅支持 macOS / Linux / WSL2。"
    ;;
esac

# ============================================================
# Phase 1: 检测必备工具
# ============================================================
info "检测必备工具..."

MISSING_TOOLS=()

check_tool() {
  local tool="$1"
  if command -v "$tool" &>/dev/null; then
    ok "$tool 已安装"
  else
    err "$tool 未找到"
    MISSING_TOOLS+=("$tool")
  fi
}

check_tool git
check_tool curl

# docker 单独检测
if command -v docker &>/dev/null; then
  ok "docker 已安装"
else
  err "docker 未找到"
  MISSING_TOOLS+=("docker")
fi

# docker compose（插件形式）
if docker compose version &>/dev/null 2>&1; then
  ok "docker compose 已可用"
elif docker-compose version &>/dev/null 2>&1; then
  ok "docker-compose (standalone) 已可用"
else
  err "docker compose 不可用"
  MISSING_TOOLS+=("docker-compose")
fi

if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
  printf "\n"
  err "以下工具缺失，请先安装后重新运行：\n"
  for tool in "${MISSING_TOOLS[@]}"; do
    case "$tool" in
      git)
        if [[ "$OS_TYPE" == "macos" ]]; then
          printf "  git:           brew install git\n"
        else
          printf "  git:           $PKG_INSTALL git\n"
        fi
        ;;
      curl)
        if [[ "$OS_TYPE" == "macos" ]]; then
          printf "  curl:          brew install curl\n"
        else
          printf "  curl:          $PKG_INSTALL curl\n"
        fi
        ;;
      docker|docker-compose)
        if [[ "$OS_TYPE" == "macos" ]]; then
          printf "  docker:        brew install --cask docker  (或访问 https://www.docker.com/products/docker-desktop)\n"
        else
          printf "  docker:        curl -fsSL https://get.docker.com | sh\n"
          printf "  docker compose: sudo apt-get install docker-compose-plugin  (Debian/Ubuntu)\n"
        fi
        ;;
    esac
  done
  printf "\n"
  info "排错文档：https://docs.docker.com/get-started/get-docker/"
  exit 1
fi

# ============================================================
# Phase 2: 选择安装位置
# ============================================================
printf "\n"
hr
info "配置安装目录..."

DEFAULT_DIR="$HOME/opendeepseek"
printf "\n"
read -rp "  安装到哪里？ [默认: $DEFAULT_DIR]: " INPUT_DIR
INSTALL_DIR="${INPUT_DIR:-$DEFAULT_DIR}"
# 展开波浪号
INSTALL_DIR="${INSTALL_DIR/#\~/$HOME}"

if [[ -d "$INSTALL_DIR" ]]; then
  warn "目录已存在: $INSTALL_DIR"
  printf "\n"
  printf "  请选择操作：\n"
  printf "    1) 覆盖（删除后重新 clone）[默认]\n"
  printf "    2) 更新（git pull origin main）\n"
  printf "    3) 退出\n"
  printf "\n"
  read -rp "  请输入选项 [1/2/3，默认 1]: " DIR_CHOICE

  case "${DIR_CHOICE:-1}" in
    2)
      info "更新现有安装..."
      cd "$INSTALL_DIR"
      if git pull origin main; then
        ok "代码已更新"
        cd "$INSTALL_DIR"
        exec ./setup.sh
      else
        die "git pull 失败。请检查网络或手动处理冲突后重试。"
      fi
      ;;
    3)
      info "已退出，未做任何更改。"
      exit 0
      ;;
    1|"")
      info "删除旧目录 $INSTALL_DIR ..."
      rm -rf "$INSTALL_DIR"
      ;;
    *)
      warn "无效选项，默认覆盖"
      rm -rf "$INSTALL_DIR"
      ;;
  esac
fi

# 从此处开始，若退出则清理
CLEANUP_ON_EXIT=1

# ============================================================
# Phase 3: Clone 项目（含中国镜像 fallback）
# ============================================================
printf "\n"
hr
info "克隆项目..."

REPO_URL="https://github.com/yourusername/opendeepseek.git"
MIRROR_URLS=(
  "https://ghproxy.com/https://github.com/yourusername/opendeepseek.git"
  "https://gitclone.com/github.com/yourusername/opendeepseek.git"
)

_try_clone() {
  local url="$1"
  info "尝试 clone: $url"
  if git clone --depth=1 "$url" "$INSTALL_DIR" 2>&1; then
    return 0
  fi
  return 1
}

CLONED=0

# 先检测 github.com 连通性
if ping -c 1 -W 3 github.com &>/dev/null 2>&1 || ping -c 1 -t 3 github.com &>/dev/null 2>&1; then
  if _try_clone "$REPO_URL"; then
    CLONED=1
  fi
fi

# 若 clone 失败，依次尝试镜像
if [[ "$CLONED" -eq 0 ]]; then
  warn "直连 GitHub 失败，尝试国内镜像..."
  for mirror in "${MIRROR_URLS[@]}"; do
    if _try_clone "$mirror"; then
      CLONED=1
      break
    fi
    warn "镜像 $mirror 也失败，尝试下一个..."
  done
fi

if [[ "$CLONED" -eq 0 ]]; then
  err "所有 clone 来源均失败。"
  printf "\n"
  info "排错建议："
  printf "  1. 检查网络：ping github.com\n"
  printf "  2. 配置代理：export https_proxy=http://your-proxy:port\n"
  printf "  3. 手动 clone 后运行：cd $INSTALL_DIR && ./setup.sh\n"
  printf "  4. 帮助文档：https://github.com/yourusername/opendeepseek#installation\n"
  exit 1
fi

ok "项目已 clone 到 $INSTALL_DIR"

# clone 成功，取消自动清理（setup.sh 接管后续）
CLEANUP_ON_EXIT=0

# ============================================================
# Phase 4: 跑 setup.sh
# ============================================================
printf "\n"
hr
info "启动配置向导..."
printf "\n"

cd "$INSTALL_DIR"

if [[ ! -f "./setup.sh" ]]; then
  die "setup.sh 未找到，项目可能不完整。请到 $INSTALL_DIR 手动检查。"
fi

chmod +x ./setup.sh
./setup.sh

# ============================================================
# Phase 5: 完成提示（若 setup.sh 本身不打印，则此处兜底）
# ============================================================
printf "\n"
hr
printf "${GREEN}${BOLD}"
printf "  OpenDeepSeek 安装完成！\n"
printf "${NC}"
printf "\n"
printf "  ${CYAN}访问地址${NC}    http://localhost:3000\n"
printf "  ${CYAN}Hermes API${NC}  http://localhost:8642\n"
printf "\n"
printf "  ${YELLOW}常用命令：${NC}\n"
printf "    cd $INSTALL_DIR\n"
printf "    docker compose logs -f        # 查看日志\n"
printf "    docker compose down           # 停止服务\n"
printf "    docker compose restart        # 重启服务\n"
printf "\n"
printf "  ${CYAN}文档：${NC} https://github.com/yourusername/opendeepseek\n"
hr
printf "\n"
