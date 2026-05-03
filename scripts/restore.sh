#!/usr/bin/env bash
# OpenDeepSeek — restore.sh
# 从 backup.sh 生成的归档恢复完整部署（配置 + 数据卷）
# 用法：./scripts/restore.sh <backup-archive.tar.gz> [--force]
# --force：跳过交互确认（CI/自动化场景使用）

set -euo pipefail

# ─── 颜色 ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()     { echo -e "${RED}[ERROR]${NC} $*" >&2; }
step()    { echo -e "\n${BOLD}${CYAN}▶ $*${NC}"; }
banner()  { echo -e "\n${BOLD}$*${NC}"; }

# ─── 临时目录 & trap 清理 ────────────────────────────────────────────────────
TMPDIR_RESTORE="/tmp/odp-restore-$$"
cleanup() {
  if [[ -d "$TMPDIR_RESTORE" ]]; then
    rm -rf "$TMPDIR_RESTORE"
    info "临时目录已清理：$TMPDIR_RESTORE"
  fi
}
trap cleanup EXIT INT TERM

# ─── 解析参数 ────────────────────────────────────────────────────────────────
ARCHIVE=""
FORCE=false

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    --*) err "未知选项：$arg"; exit 1 ;;
    *)
      if [[ -z "$ARCHIVE" ]]; then
        ARCHIVE="$arg"
      else
        err "多余的参数：$arg"
        exit 1
      fi
      ;;
  esac
done

# ─── 找到项目根目录 ──────────────────────────────────────────────────────────
# 脚本本身位于 scripts/，所以项目根是上一级
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# ═══════════════════════════════════════════════════════════════════════════════
# Phase 1 — 参数验证
# ═══════════════════════════════════════════════════════════════════════════════
step "Phase 1 — 参数验证"

if [[ -z "$ARCHIVE" ]]; then
  err "必须指定备份归档路径"
  echo ""
  echo "  用法：$0 <backup-archive.tar.gz> [--force]"
  echo ""
  echo "  可用备份："
  if [[ -d "$PROJECT_ROOT/backups" ]]; then
    ls -lh "$PROJECT_ROOT/backups/"*.tar.gz 2>/dev/null | awk '{print "    " $NF}' || echo "    （backups/ 目录下没有 .tar.gz 文件）"
  else
    echo "    （backups/ 目录不存在）"
  fi
  exit 1
fi

# 支持相对路径
if [[ "$ARCHIVE" != /* ]]; then
  ARCHIVE="$PROJECT_ROOT/$ARCHIVE"
fi

if [[ ! -f "$ARCHIVE" ]]; then
  err "文件不存在：$ARCHIVE"
  echo ""
  echo "  建议：ls $PROJECT_ROOT/backups/"
  if [[ -d "$PROJECT_ROOT/backups" ]]; then
    ls -lh "$PROJECT_ROOT/backups/"*.tar.gz 2>/dev/null || echo "  （没有找到任何 .tar.gz 备份）"
  fi
  exit 1
fi

if [[ "$ARCHIVE" != *.tar.gz ]]; then
  err "不是有效的备份归档（必须是 .tar.gz）：$ARCHIVE"
  exit 1
fi

ok "归档文件验证通过：$(basename "$ARCHIVE")  ($(du -sh "$ARCHIVE" | cut -f1))"

# ═══════════════════════════════════════════════════════════════════════════════
# Phase 2 — 安全确认
# ═══════════════════════════════════════════════════════════════════════════════
step "Phase 2 — 安全确认"

# 显示当前状态
echo ""
echo -e "${YELLOW}${BOLD}  ⚠  危险操作警告${NC}"
echo -e "${YELLOW}  此操作将永久删除以下内容并用备份数据覆盖：${NC}"
echo "    • hermes-data   卷（Hermes Agent 的持久化数据）"
echo "    • open-webui-data 卷（Open WebUI 用户数据、对话历史）"
echo "    • 当前 .env 配置"
echo "    • 当前 docker-compose.yml"
echo ""

# 当前 .env 摘要
if [[ -f "$PROJECT_ROOT/.env" ]]; then
  info "当前 .env 最后修改：$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$PROJECT_ROOT/.env" 2>/dev/null || stat --format='%y' "$PROJECT_ROOT/.env" 2>/dev/null | cut -c1-19)"
else
  warn "当前 .env 不存在"
fi

# 当前容器状态
info "当前容器状态："
docker compose ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null | sed 's/^/    /' || echo "    （无法获取容器状态）"

# 当前卷数据量
echo ""
info "当前数据卷大小："
for vol in hermes-data open-webui-data; do
  # 获取 compose project 名（目录名）
  PROJ=$(basename "$PROJECT_ROOT")
  FULL_VOL="${PROJ}_${vol}"
  SIZE=$(docker run --rm -v "${FULL_VOL}:/data" alpine du -sh /data 2>/dev/null | cut -f1 || echo "（卷不存在或为空）")
  echo "    $FULL_VOL : $SIZE"
done
echo ""

if [[ "$FORCE" == "true" ]]; then
  warn "--force 模式：跳过交互确认"
else
  echo -e "${BOLD}  此操作将覆盖当前数据，是否继续？${NC}"
  printf "  请输入 yes 继续，其他任何输入将取消：${BOLD} "
  read -r CONFIRM
  echo -e "${NC}"
  if [[ "$CONFIRM" != "yes" ]]; then
    echo "操作已取消。"
    exit 0
  fi
fi

ok "用户确认，开始恢复流程"

# ═══════════════════════════════════════════════════════════════════════════════
# Phase 3 — 解析归档元数据
# ═══════════════════════════════════════════════════════════════════════════════
step "Phase 3 — 解析归档元数据"

mkdir -p "$TMPDIR_RESTORE"
info "临时目录：$TMPDIR_RESTORE"

# 解压归档到临时目录
info "解压归档..."
tar -xzf "$ARCHIVE" -C "$TMPDIR_RESTORE"

# 找到归档根目录（tar 内可能有一层子目录）
EXTRACT_ROOT="$TMPDIR_RESTORE"
# 如果只有一个子目录，进入它
SUBDIRS=( "$TMPDIR_RESTORE"/opendeepseek-backup-* )
if [[ ${#SUBDIRS[@]} -eq 1 && -d "${SUBDIRS[0]}" ]]; then
  EXTRACT_ROOT="${SUBDIRS[0]}"
fi

ok "解压完成：$EXTRACT_ROOT"

# 读取备份元数据
META_FILE="$EXTRACT_ROOT/backup-meta.json"
if [[ -f "$META_FILE" ]]; then
  banner "  备份元数据："
  # 简单提取几个关键字段（不依赖 jq）
  BACKUP_TIME=$(grep -o '"backup_time"[[:space:]]*:[[:space:]]*"[^"]*"' "$META_FILE" | cut -d'"' -f4 || echo "未知")
  BACKUP_COMMIT=$(grep -o '"git_commit"[[:space:]]*:[[:space:]]*"[^"]*"' "$META_FILE" | cut -d'"' -f4 || echo "未知")
  HERMES_IMAGE=$(grep -o '"hermes"[[:space:]]*:[[:space:]]*"[^"]*"' "$META_FILE" | head -1 | cut -d'"' -f4 || echo "未知")
  WEBUI_IMAGE=$(grep -o '"open_webui"[[:space:]]*:[[:space:]]*"[^"]*"' "$META_FILE" | head -1 | cut -d'"' -f4 || echo "未知")

  echo "    备份时间  : $BACKUP_TIME"
  echo "    Git commit : $BACKUP_COMMIT"
  echo "    Hermes 镜像 : $HERMES_IMAGE"
  echo "    WebUI 镜像  : $WEBUI_IMAGE"

  # 镜像版本对比
  if [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
    CURRENT_HERMES=$(grep -m1 'nousresearch/hermes-agent' "$PROJECT_ROOT/docker-compose.yml" | grep -o 'v[0-9][^"]*' | head -1 || echo "未知")
    CURRENT_WEBUI=$(grep -m1 'open-webui/open-webui' "$PROJECT_ROOT/docker-compose.yml" | grep -o ':[^"]*$' | tr -d ':' | head -1 || echo "未知")

    if [[ -n "$HERMES_IMAGE" && "$HERMES_IMAGE" != "未知" ]]; then
      if echo "$HERMES_IMAGE" | grep -qF "$CURRENT_HERMES" || echo "$CURRENT_HERMES" | grep -qF "$HERMES_IMAGE"; then
        ok "Hermes 镜像版本匹配"
      else
        warn "Hermes 镜像版本不一致：备份=$HERMES_IMAGE  当前=$CURRENT_HERMES"
        warn "恢复后数据与当前镜像可能不兼容，请谨慎"
      fi
    fi
  fi
else
  warn "backup-meta.json 未找到，跳过元数据检查"
fi

# 验证必要文件存在
MISSING=()
for f in hermes-data.tar open-webui-data.tar .env docker-compose.yml; do
  [[ ! -f "$EXTRACT_ROOT/$f" ]] && MISSING+=("$f")
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
  err "归档缺少必要文件：${MISSING[*]}"
  exit 1
fi

ok "归档完整性验证通过"

# ═══════════════════════════════════════════════════════════════════════════════
# Phase 4 — 停服务 & 删旧卷
# ═══════════════════════════════════════════════════════════════════════════════
step "Phase 4 — 停服务 & 删旧卷"

info "停止所有容器..."
docker compose down --timeout 30 2>&1 | sed 's/^/    /'
ok "服务已停止"

PROJ=$(basename "$PROJECT_ROOT")
for vol in hermes-data open-webui-data; do
  FULL_VOL="${PROJ}_${vol}"
  if docker volume inspect "$FULL_VOL" &>/dev/null; then
    info "删除卷：$FULL_VOL"
    docker volume rm "$FULL_VOL"
    ok "已删除：$FULL_VOL"
  else
    info "卷不存在，跳过删除：$FULL_VOL"
  fi
done

# ═══════════════════════════════════════════════════════════════════════════════
# Phase 5 — 恢复配置文件
# ═══════════════════════════════════════════════════════════════════════════════
step "Phase 5 — 恢复配置文件"

# 备份当前配置（如果存在）到 .bak
for f in .env docker-compose.yml; do
  if [[ -f "$PROJECT_ROOT/$f" ]]; then
    cp "$PROJECT_ROOT/$f" "$PROJECT_ROOT/${f}.pre-restore.bak"
    info "当前 $f 已备份到 ${f}.pre-restore.bak"
  fi
done

# 恢复 .env（mode 600）
cp "$EXTRACT_ROOT/.env" "$PROJECT_ROOT/.env"
chmod 600 "$PROJECT_ROOT/.env"
ok "已恢复 .env (mode 600)"

# 恢复 docker-compose.yml
cp "$EXTRACT_ROOT/docker-compose.yml" "$PROJECT_ROOT/docker-compose.yml"
ok "已恢复 docker-compose.yml"

# 恢复 searxng/（可选）
if [[ -d "$EXTRACT_ROOT/searxng" ]]; then
  if [[ -d "$PROJECT_ROOT/searxng" ]]; then
    mv "$PROJECT_ROOT/searxng" "$PROJECT_ROOT/searxng.pre-restore.bak"
    info "当前 searxng/ 已备份到 searxng.pre-restore.bak/"
  fi
  cp -r "$EXTRACT_ROOT/searxng" "$PROJECT_ROOT/searxng"
  ok "已恢复 searxng/"
else
  info "备份中无 searxng/，跳过"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Phase 6 — 恢复数据卷
# ═══════════════════════════════════════════════════════════════════════════════
step "Phase 6 — 恢复数据卷"

PROJ=$(basename "$PROJECT_ROOT")

restore_volume() {
  local vol_name="$1"       # e.g. hermes-data
  local tar_file="$2"       # e.g. /tmp/.../hermes-data.tar
  local full_vol="${PROJ}_${vol_name}"

  info "创建卷：$full_vol"
  docker volume create "$full_vol" > /dev/null

  info "向卷 $full_vol 写入数据..."
  docker run --rm \
    -v "${full_vol}:/restore" \
    -v "$(dirname "$tar_file"):/source:ro" \
    alpine \
    sh -c "cd /restore && tar -xf /source/$(basename "$tar_file") --strip-components=1 2>/dev/null || tar -xf /source/$(basename "$tar_file")"

  ok "卷 $full_vol 恢复完成"
}

restore_volume "hermes-data"    "$EXTRACT_ROOT/hermes-data.tar"
restore_volume "open-webui-data" "$EXTRACT_ROOT/open-webui-data.tar"

# ═══════════════════════════════════════════════════════════════════════════════
# Phase 7 — 启服务 & 验证
# ═══════════════════════════════════════════════════════════════════════════════
step "Phase 7 — 启服务 & 验证"

info "启动服务..."
docker compose up -d 2>&1 | sed 's/^/    /'
ok "服务已启动"

# 等待容器健康
info "等待容器健康检查（最多 120 秒）..."
WAIT=0
INTERVAL=5
TIMEOUT=120
while [[ $WAIT -lt $TIMEOUT ]]; do
  HERMES_STATUS=$(docker compose ps --format json 2>/dev/null \
    | grep -o '"Health":"[^"]*"' | head -1 \
    | cut -d'"' -f4 || echo "")

  RUNNING=$(docker compose ps --status running --format json 2>/dev/null \
    | grep -c opendeepseek || echo 0)

  if [[ "$RUNNING" -ge 2 ]]; then
    ok "容器已运行（${RUNNING} 个）"
    break
  fi

  sleep $INTERVAL
  WAIT=$((WAIT + INTERVAL))
  printf "    等待中... %ds / %ds\r" "$WAIT" "$TIMEOUT"
done

if [[ $WAIT -ge $TIMEOUT ]]; then
  warn "等待超时，服务可能仍在启动中"
  docker compose ps 2>/dev/null | sed 's/^/    /'
fi

# 运行 smoke-test（如果存在）
SMOKE_SCRIPT="$PROJECT_ROOT/scripts/smoke-test.sh"
if [[ -f "$SMOKE_SCRIPT" ]]; then
  info "运行 smoke-test 验证恢复成功..."
  echo ""
  if bash "$SMOKE_SCRIPT"; then
    ok "smoke-test PASS — 恢复成功并已验证"
  else
    warn "smoke-test 有失败项 — 数据已恢复但服务可能未完全就绪"
    warn "请检查：docker compose logs"
  fi
else
  info "scripts/smoke-test.sh 不存在，跳过自动验证"
  info "请手动访问 http://localhost:3000 检查服务状态"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Phase 8 — 清理 & 完成报告
# ═══════════════════════════════════════════════════════════════════════════════
step "Phase 8 — 清理"

# 临时目录由 trap 清理（EXIT 时自动触发）

echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}   OpenDeepSeek 恢复完成${NC}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo "  归档来源 : $(basename "$ARCHIVE")"
[[ -n "${BACKUP_TIME:-}" ]] && echo "  备份时间 : $BACKUP_TIME"
[[ -n "${BACKUP_COMMIT:-}" ]] && echo "  来源 commit : $BACKUP_COMMIT"
echo ""
echo "  已恢复："
echo "    ✓ .env (mode 600)"
echo "    ✓ docker-compose.yml"
[[ -d "$PROJECT_ROOT/searxng" ]] && echo "    ✓ searxng/"
echo "    ✓ 卷 ${PROJ}_hermes-data"
echo "    ✓ 卷 ${PROJ}_open-webui-data"
echo ""
echo -e "  访问地址：${BOLD}http://localhost:3000${NC}"
echo ""

# 提示 pre-restore 备份
PRE_BAK=()
for f in .env docker-compose.yml searxng; do
  if [[ -e "$PROJECT_ROOT/${f}.pre-restore.bak" ]]; then
    PRE_BAK+=("${f}.pre-restore.bak")
  fi
done
if [[ ${#PRE_BAK[@]} -gt 0 ]]; then
  info "原配置已备份（如需回滚）："
  for b in "${PRE_BAK[@]}"; do
    echo "    $PROJECT_ROOT/$b"
  done
fi
