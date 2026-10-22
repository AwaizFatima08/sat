#!/usr/bin/env bash
#
# backup.sh — three-layer backup for Module Up: Digital SAT Prep
#
#   Layer 1: local copy    -> /mnt/storage/project_backups/sat_backup/
#   Layer 2: Google Drive  -> https://drive.google.com/drive/folders/1S3n2DY9KGQtPM4ubQodVsUfSeGj1tRrH
#   Layer 3: GitHub        -> https://github.com/AwaizFatima08/sat (PUBLIC repo)
#
# Run:  bash /mnt/storage/projects/sat/scripts/backup.sh
#
# Layer 2 skips .git/: Drive throttles thousands of tiny object files, and GitHub plus Layer 1 hold the history.
# Layer 3 refuses to push if it finds untracked or uncommitted files, so stray files never reach the public repo.

set -uo pipefail

PROJECT_DIR="/mnt/storage/projects/sat"
LOCAL_BACKUP_ROOT="/mnt/storage/project_backups/sat_backup"
GDRIVE_REMOTE="gdrive"
GDRIVE_FOLDER_ID="1S3n2DY9KGQtPM4ubQodVsUfSeGj1tRrH"
GIT_REMOTE_URL="https://github.com/AwaizFatima08/sat.git"
KEEP_LOCAL_BACKUPS=10

TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"
LOG_FILE="$PROJECT_DIR/scripts/backup.log"
EXCLUDES="$PROJECT_DIR/scripts/backup_exclude.txt"

log(){ echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "=== Starting SAT backup: $TIMESTAMP ==="
cd "$PROJECT_DIR" || { log "FATAL: $PROJECT_DIR not found"; exit 1; }

# ---- Layer 1: local ----
log "Layer 1: local backup"
mkdir -p "$LOCAL_BACKUP_ROOT"
DEST="$LOCAL_BACKUP_ROOT/sat_$TIMESTAMP"
if rsync -a --exclude-from="$EXCLUDES" "$PROJECT_DIR/" "$DEST/"; then
  log "  OK — copied to $DEST"
else
  log "  ERROR — local rsync failed"
fi
( cd "$LOCAL_BACKUP_ROOT" && ls -1dt sat_*/ 2>/dev/null | tail -n +$((KEEP_LOCAL_BACKUPS + 1)) | while read -r old; do
    log "  pruning old local backup: $old"; rm -rf "${old:?}"; done )

# ---- Layer 2: Google Drive ----
log "Layer 2: Google Drive backup"
if ! command -v rclone >/dev/null 2>&1 || ! rclone listremotes 2>/dev/null | grep -q "^${GDRIVE_REMOTE}:"; then
  log "  SKIPPED — rclone or the '$GDRIVE_REMOTE' remote is not configured"
else
  if rclone copy "$PROJECT_DIR" "${GDRIVE_REMOTE}:" \
      --drive-root-folder-id "$GDRIVE_FOLDER_ID" \
      --exclude ".git/**" --exclude-from "$EXCLUDES" \
      --update --checksum --tpslimit 4 --retries 5 --low-level-retries 20 --log-file="$LOG_FILE" --log-level INFO; then
    log "  OK — project synced to Google Drive folder ($GDRIVE_FOLDER_ID)"
  else
    log "  ERROR — rclone sync failed (see log)"
  fi
fi

# ---- Layer 3: GitHub ----
log "Layer 3: GitHub push"
git remote get-url origin >/dev/null 2>&1 || git remote add origin "$GIT_REMOTE_URL"
UNTRACKED="$(git ls-files --others --exclude-standard)"
if [ -n "$UNTRACKED" ]; then
  log "  SKIPPED — untracked files present; commit or gitignore them first:"
  echo "$UNTRACKED" | sed 's/^/      /' | tee -a "$LOG_FILE"
elif ! git diff --quiet || ! git diff --cached --quiet; then
  log "  SKIPPED — uncommitted changes present; commit them with a descriptive message first"
else
  BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  if git push -u origin "$BRANCH" >>"$LOG_FILE" 2>&1; then
    log "  OK — pushed $BRANCH to $GIT_REMOTE_URL"
  else
    log "  ERROR — git push failed (check gh auth / network)"
  fi
fi

log "=== Backup finished: $TIMESTAMP ==="
