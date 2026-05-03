#!/usr/bin/env bash
# OpenDeepSeek Update Script — 一行命令安全升级
# 用法：./scripts/update.sh [--force] [--no-backup]
# --force      跳过所有确认提示
# --no-backup  跳过自动备份（不推荐）

set -euo pipefail

# ─── 颜色 ───────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()      { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
header()  { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════════════${NC}"; echo -e "${BOLD}${CYAN}  $*${NC}"; echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════${NC}"; }
divider() { echo -e "${CYAN}──────────────────────────────────────────────────${NC}"; }

# ─── 标志位 ─────────────────────────────────────────────────────────────
FORCE=false
NO_BACKUP=false
ROLLBACK_FILE="/tmp/odp-update-rollback.json"

for arg in "$@"; do
  case "$arg" in
    --force)     FORCE=true ;;
    --no-backup) NO_BACKUP=true ;;
    *)           error "未知参数：$arg"; echo "用法：$0 [--force] [--no-backup]"; exit 1 ;;
  esac
done

# ─── 工具函数 ────────────────────────────────────────────────────────────
ask_confirm() {
  # ask_confirm "提示" [default_yes]
  local prompt="$1"
  local default="${2:-no}"
  if [[ "$FORCE" == "true" ]]; then
    info "(--force) 自动确认：$prompt"
    return 0
  fi
  if [[ "$default" == "yes" ]]; then
    read -r -p "$(echo -e "${YELLOW}${prompt} [Y/n] ${NC}")" ans
    ans="${ans:-Y}"
  else
    read -r -p "$(echo -e "${YELLOW}${prompt} [y/N] ${NC}")" ans
    ans="${ans:-N}"
  fi
  [[ "$ans" =~ ^[Yy]$ ]]
}

ask_explicit() {
  # ask_explicit "提示" "expected_input"
  local prompt="$1"
  local expected="$2"
  if [[ "$FORCE" == "true" ]]; then
    info "(--force) 自动跳过：$prompt"
    return 0
  fi
  read -r -p "$(echo -e "${YELLOW}${prompt} (输入 '${expected}' 确认，其他取消)：${NC}")" ans
  [[ "$ans" == "$expected" ]]
}

cleanup_rollback() {
  [[ -f "$ROLLBACK_FILE" ]] && rm -f "$ROLLBACK_FILE"
}

# ─── Phase 9: 回退 ──────────────────────────────────────────────────────
do_rollback() {
  header "Phase 9: 回退"
  if [[ ! -f "$ROLLBACK_FILE" ]]; then
    error "回退文件不存在：$ROLLBACK_FILE，无法自动回退"
    return 1
  fi

  local old_commit new_commit
  old_commit=$(python3 -c "import json,sys; d=json.load(open('$ROLLBACK_FILE')); print(d['commit'])" 2>/dev/null || \
               node -e "const d=require('$ROLLBACK_FILE'); console.log(d.commit)" 2>/dev/null || \
               grep -o '"commit":"[^"]*"' "$ROLLBACK_FILE" | cut -d'"' -f4)
  new_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")

  divider
  echo -e "  当前版本：${RED}${new_commit:0:12}${NC}"
  echo -e "  回退目标：${GREEN}${old_commit:0:12}${NC}"
  divider

  if ! ask_confirm "确认回退到 ${old_commit:0:12}？" "yes"; then
    warn "用户取消回退，当前状态可能不稳定"
    return 1
  fi

  info "正在 git reset --hard ${old_commit:0:12} ..."
  git reset --hard "$old_commit"

  info "正在重启容器..."
  docker compose down
  docker compose up -d

  info "等待 90 秒让容器健康..."
  sleep 90

  info "验证回退后状态..."
  if bash scripts/smoke-test.sh; then
    ok "回退成功，系统恢复到 ${old_commit:0:12}"
    cleanup_rollback
    return 0
  else
    error "回退后 smoke-test 仍然失败，请手动检查"
    return 1
  fi
}

# ─── 主流程 ─────────────────────────────────────────────────────────────
header "OpenDeepSeek 升级脚本"
echo -e "  模式：$([ "$FORCE" == "true" ] && echo "${YELLOW}--force (跳过确认)${NC}" || echo "交互")"
echo -e "  备份：$([ "$NO_BACKUP" == "true" ] && echo "${YELLOW}--no-backup (跳过)${NC}" || echo "启用")"
echo ""

# ─── Phase 1: 预检 ──────────────────────────────────────────────────────
header "Phase 1: 预检"

# 检查在项目根目录
if [[ ! -f "docker-compose.yml" ]] || [[ ! -f "setup.sh" ]]; then
  error "请在项目根目录运行此脚本（需包含 docker-compose.yml 和 setup.sh）"
  error "当前目录：$(pwd)"
  exit 1
fi
ok "在项目根目录：$(pwd)"

# 检查 git remote
if ! git remote get-url origin &>/dev/null; then
  error "git remote 'origin' 不存在，无法拉取更新"
  exit 1
fi
ok "git remote origin：$(git remote get-url origin)"

# 检查 git 工作目录
GIT_STATUS=$(git status --porcelain 2>/dev/null)
if [[ -n "$GIT_STATUS" ]]; then
  warn "有未提交的本地修改："
  git status --short
  divider
  if ask_confirm "是否 git stash 暂存本地修改后继续？"; then
    git stash push -m "odp-update-stash-$(date +%Y%m%d-%H%M%S)"
    ok "已暂存本地修改（git stash）"
    STASHED=true
  else
    warn "保留本地修改，继续升级（可能导致 merge conflict）"
    STASHED=false
  fi
else
  ok "git 工作目录干净"
  STASHED=false
fi

# 检查容器在跑
RUNNING=$(docker compose ps --status running --format json 2>/dev/null | grep -c "opendeepseek" || echo "0")
if [[ "$RUNNING" -eq 0 ]]; then
  warn "未检测到正在运行的 OpenDeepSeek 容器"
  warn "（升级仍可继续，但将无法验证服务状态）"
else
  ok "检测到 ${RUNNING} 个正在运行的容器"
fi

# ─── Phase 2: 自动备份 ──────────────────────────────────────────────────
header "Phase 2: 自动备份"

if [[ "$NO_BACKUP" == "true" ]]; then
  warn "--no-backup：跳过自动备份（不推荐）"
elif [[ -f "scripts/backup.sh" ]]; then
  info "运行 scripts/backup.sh ..."
  if bash scripts/backup.sh; then
    ok "备份完成"
  else
    error "备份失败"
    if ! ask_explicit "备份失败，是否仍然继续升级？" "continue"; then
      error "用户取消，升级已中止"
      exit 1
    fi
    warn "用户确认继续（无备份）"
  fi
else
  info "scripts/backup.sh 不存在，跳过备份步骤"
  warn "建议创建 scripts/backup.sh 以保护数据"
fi

# ─── Phase 3: 记录当前状态 ───────────────────────────────────────────────
header "Phase 3: 记录当前状态（防回退快照）"

CURRENT_COMMIT=$(git rev-parse HEAD)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
CURRENT_IMAGES=$(docker compose images --format json 2>/dev/null || docker compose images 2>/dev/null || echo "[]")
SNAPSHOT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > "$ROLLBACK_FILE" <<EOF
{
  "timestamp": "${SNAPSHOT_TIME}",
  "commit": "${CURRENT_COMMIT}",
  "branch": "${CURRENT_BRANCH}",
  "images": $(echo "$CURRENT_IMAGES" | python3 -c "import sys,json; data=sys.stdin.read(); print(json.dumps(data))" 2>/dev/null || echo '"(see docker compose images)"')
}
EOF

ok "快照已写入：${ROLLBACK_FILE}"
info "  commit：${CURRENT_COMMIT:0:12} (${CURRENT_BRANCH})"

# ─── Phase 4: 拉最新代码 ─────────────────────────────────────────────────
header "Phase 4: 拉最新代码"

info "正在 git fetch origin ..."
git fetch origin

AHEAD=$(git log origin/main..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
BEHIND=$(git log HEAD..origin/main --oneline 2>/dev/null | wc -l | tr -d ' ')

if [[ "$AHEAD" -gt 0 ]]; then
  echo ""
  warn "本地领先 origin/main ${AHEAD} 个提交（这些提交不在远端）："
  git log origin/main..HEAD --oneline --decorate | head -20
fi

if [[ "$BEHIND" -gt 0 ]]; then
  echo ""
  info "以下 ${BEHIND} 个提交即将从 origin/main 拉取："
  git log HEAD..origin/main --oneline --decorate | head -20
else
  ok "已经是最新版本，无新提交"
fi

divider
if [[ "$BEHIND" -eq 0 ]] && [[ "$AHEAD" -eq 0 ]]; then
  if ! ask_confirm "代码已是最新，是否仍重新拉取镜像并重启服务？"; then
    info "用户取消，无需更新"
    cleanup_rollback
    exit 0
  fi
else
  if ! ask_confirm "看到上面的更新内容，是否继续升级？"; then
    info "用户取消升级"
    cleanup_rollback
    [[ "$STASHED" == "true" ]] && git stash pop && info "已恢复 stash"
    exit 0
  fi
fi

# 分支检查
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  warn "当前分支是 '${CURRENT_BRANCH}'，而非 'main'"
  if ask_confirm "是否切换到 main 分支后继续？" "yes"; then
    git checkout main
    git fetch origin
    CURRENT_BRANCH="main"
    ok "已切换到 main"
  else
    warn "保持在 ${CURRENT_BRANCH} 分支继续"
  fi
fi

# ─── Phase 5: 应用更新 ───────────────────────────────────────────────────
header "Phase 5: 应用更新（git pull）"

info "正在 git pull origin ${CURRENT_BRANCH} ..."
if ! git pull origin "$CURRENT_BRANCH"; then
  error "git pull 失败（可能有 merge conflict）"
  error "正在回退到 Phase 3 快照..."
  git reset --hard "$CURRENT_COMMIT"
  ok "代码已回退到 ${CURRENT_COMMIT:0:12}"
  [[ "$STASHED" == "true" ]] && git stash pop && info "已恢复 stash"
  cleanup_rollback
  exit 1
fi

NEW_COMMIT=$(git rev-parse HEAD)
ok "代码已更新：${CURRENT_COMMIT:0:12} → ${NEW_COMMIT:0:12}"
git log -1 --pretty=format:"  提交：%h %s (%an, %ar)" HEAD
echo ""

# ─── Phase 6: 拉新镜像 ───────────────────────────────────────────────────
header "Phase 6: 拉新镜像（docker compose pull）"

info "正在拉取最新镜像..."
if docker compose pull; then
  ok "镜像拉取完成"
else
  warn "部分镜像拉取失败（将使用本地已有镜像继续）"
fi

# ─── Phase 7: 滚动重启 ───────────────────────────────────────────────────
header "Phase 7: 滚动重启"

info "正在停止容器（docker compose down）..."
docker compose down

info "正在启动容器（docker compose up -d）..."
docker compose up -d

info "等待 90 秒让容器健康..."
for i in $(seq 1 18); do
  sleep 5
  printf "  [%ds/90s] 等待中...\r" $((i * 5))
done
echo ""
ok "等待完毕，容器应已就绪"

# ─── Phase 8: 验证 ───────────────────────────────────────────────────────
header "Phase 8: 验证（smoke-test）"

if bash scripts/smoke-test.sh; then
  SMOKE_OK=true
  ok "smoke-test 全部 PASS — 升级成功！"
else
  SMOKE_OK=false
  error "smoke-test 有失败项"
fi

# ─── 失败处理 ────────────────────────────────────────────────────────────
if [[ "$SMOKE_OK" == "false" ]]; then
  divider
  warn "升级后验证失败，是否回退到旧版本？"
  echo -e "  旧 commit：${GREEN}${CURRENT_COMMIT:0:12}${NC}"
  echo -e "  新 commit：${RED}${NEW_COMMIT:0:12}${NC}"
  divider

  if ask_confirm "是否回退？" "yes"; then
    if do_rollback; then
      ok "系统已回退到旧版本"
    else
      error "回退失败，请手动检查系统状态"
      error "  快照文件：${ROLLBACK_FILE}"
      error "  旧 commit：${CURRENT_COMMIT}"
      exit 1
    fi
  else
    warn "用户选择不回退，系统保留新版本（可能不稳定）"
    warn "如需手动回退：git reset --hard ${CURRENT_COMMIT} && docker compose down && docker compose up -d"
  fi

  [[ "$STASHED" == "true" ]] && git stash pop 2>/dev/null && info "已恢复 stash"
  cleanup_rollback
  exit 1
fi

# ─── Phase 10: 清理 ──────────────────────────────────────────────────────
header "Phase 10: 清理"

cleanup_rollback
ok "临时文件已清理"

[[ "$STASHED" == "true" ]] && git stash pop && ok "已恢复暂存的本地修改（git stash pop）"

# ─── 最终状态报告 ────────────────────────────────────────────────────────
header "升级完成"
echo ""
echo -e "  ${GREEN}${BOLD}OpenDeepSeek 升级成功！${NC}"
echo ""
info "新版本信息："
git log -1 --pretty=format:"  %h %s%n  作者：%an  时间：%ar%n  完整：%H" HEAD
echo ""
info "运行中的容器："
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || docker compose ps
echo ""
ok "访问地址：http://localhost:3000"
echo ""
