#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# OpenDeepSeek — Backup Script
# Usage: ./scripts/backup.sh
# Output: backups/opendeepseek-backup-YYYY-MM-DD-HHMMSS.tar.gz
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

STEP=0
TOTAL=7

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
    echo -e "${GREEN}✓${NC}  $1"
}

err() {
    echo -e "${RED}✗${NC}  $1" >&2
}

die() {
    err "$1"
    exit 1
}

PAUSED=false

cleanup() {
    if [ "$PAUSED" = true ]; then
        warn "Restoring containers (unpause)..."
        docker compose unpause 2>/dev/null || true
        PAUSED=false
    fi
}
trap cleanup EXIT INT TERM

# ============================================================
# Phase 1: Detect environment
# ============================================================
progress "Detecting environment..."

# Must run from project root
[ -f "docker-compose.yml" ] || die "docker-compose.yml not found. Run this script from the project root directory."

# Docker daemon must be running
docker info > /dev/null 2>&1 || die "Docker daemon is not running. Start Docker and try again."
ok "Docker daemon is running"

# Check if containers are running (to decide whether to pause)
RUNNING_CONTAINERS=$(docker compose ps --status running --quiet 2>/dev/null | wc -l | tr -d ' ')
if [ "$RUNNING_CONTAINERS" -gt 0 ]; then
    info "Found $RUNNING_CONTAINERS running container(s) — pausing for consistent snapshot..."
    docker compose pause
    PAUSED=true
    ok "Containers paused"
else
    info "No running containers — proceeding without pause"
fi

# ============================================================
# Phase 2: Create backup directory and filename
# ============================================================
progress "Preparing backup destination..."

mkdir -p backups

TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
BACKUP_NAME="opendeepseek-backup-${TIMESTAMP}"
BACKUP_ARCHIVE="backups/${BACKUP_NAME}.tar.gz"
STAGING_DIR=$(mktemp -d)
STAGE="${STAGING_DIR}/${BACKUP_NAME}"
mkdir -p "${STAGE}/volumes" "${STAGE}/config"

info "Archive will be: ${BACKUP_ARCHIVE}"

# ============================================================
# Phase 3: Backup Docker volumes
# ============================================================
progress "Backing up Docker volumes..."

# Derive project name from current directory name (Docker Compose default)
PROJECT_NAME=$(basename "$(pwd)")

backup_volume() {
    local vol_short="$1"   # e.g. hermes-data
    local vol_full="${PROJECT_NAME}_${vol_short}"

    # Check if the volume exists (try project-prefixed name first, then bare name)
    if docker volume inspect "${vol_full}" > /dev/null 2>&1; then
        VOLUME_ID="${vol_full}"
    elif docker volume inspect "${vol_short}" > /dev/null 2>&1; then
        VOLUME_ID="${vol_short}"
    else
        # Last-resort: search by substring
        VOLUME_ID=$(docker volume ls --format "{{.Name}}" | grep "${vol_short}" | head -1)
        if [ -z "${VOLUME_ID}" ]; then
            warn "Volume '${vol_short}' not found — skipping"
            return
        fi
    fi

    info "Archiving volume: ${VOLUME_ID}"
    docker run --rm \
        -v "${VOLUME_ID}:/source:ro" \
        -v "${STAGE}/volumes:/backup" \
        alpine \
        tar czf "/backup/${vol_short}.tar.gz" -C /source .
    ok "Volume '${vol_short}' backed up"
}

backup_volume "hermes-data"
backup_volume "open-webui-data"

# ============================================================
# Phase 4: Backup configuration files
# ============================================================
progress "Backing up configuration files..."

# .env (preserve permissions)
if [ -f ".env" ]; then
    cp ".env" "${STAGE}/config/.env"
    chmod 600 "${STAGE}/config/.env"
    ok ".env backed up (mode 600)"
else
    warn ".env not found — skipping"
fi

# docker-compose.yml
cp "docker-compose.yml" "${STAGE}/config/docker-compose.yml"
ok "docker-compose.yml backed up"

# searxng directory
if [ -d "searxng" ]; then
    cp -r "searxng" "${STAGE}/config/searxng"
    ok "searxng/ backed up"
else
    info "searxng/ not found — skipping"
fi

# ============================================================
# Phase 5: Write metadata
# ============================================================
progress "Writing backup metadata..."

GIT_HASH=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
COMPOSE_PS=$(docker compose ps 2>/dev/null || echo "unavailable")
IMAGE_TAGS=$(docker compose config 2>/dev/null \
    | grep '^\s*image:' \
    | sed 's/.*image:[[:space:]]*//' \
    | sort -u \
    | tr '\n' ',' \
    | sed 's/,$//' \
    || echo "unavailable")

cat > "${STAGE}/backup-meta.json" <<EOF
{
  "backup_time": "${TIMESTAMP}",
  "backup_name": "${BACKUP_NAME}",
  "project_name": "${PROJECT_NAME}",
  "git_commit": "${GIT_HASH}",
  "git_branch": "${GIT_BRANCH}",
  "image_tags": "${IMAGE_TAGS}",
  "compose_ps": $(echo "${COMPOSE_PS}" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo "\"${COMPOSE_PS}\""),
  "volumes_backed_up": ["hermes-data", "open-webui-data"],
  "restore_command": "./scripts/restore.sh ${BACKUP_ARCHIVE}"
}
EOF
ok "backup-meta.json written"

# ============================================================
# Phase 6: Create final archive
# ============================================================
progress "Creating archive..."

# Use -C so paths inside the tarball are relative (no leading /)
tar czf "${BACKUP_ARCHIVE}" -C "${STAGING_DIR}" "${BACKUP_NAME}"
rm -rf "${STAGING_DIR}"

# ============================================================
# Phase 7: Resume services + report
# ============================================================
progress "Finalizing..."

if [ "$PAUSED" = true ]; then
    docker compose unpause
    PAUSED=false
    ok "Containers resumed"
fi

# Compute archive size (macOS + Linux compatible)
if command -v du > /dev/null 2>&1; then
    ARCHIVE_SIZE=$(du -sh "${BACKUP_ARCHIVE}" | cut -f1)
else
    ARCHIVE_SIZE="unknown"
fi

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Backup complete!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo -e "  Archive : ${CYAN}${BACKUP_ARCHIVE}${NC}"
echo -e "  Size    : ${ARCHIVE_SIZE}"
echo -e "  Git     : ${GIT_HASH}"
echo ""
echo -e "  To restore:"
echo -e "    ${YELLOW}./scripts/restore.sh ${BACKUP_ARCHIVE}${NC}"
echo ""
