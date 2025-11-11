#!/bin/bash
#
# Create Auto-Sync Script for Raspberry Pi
# Sets up automatic GitHub sync via webhook or cron
#

PI_HOST="berryuno@192.168.22.5"
PI_ARCHIVE="/archive"

cat > /tmp/auto-sync.sh << 'AUTO_SYNC_SCRIPT'
#!/bin/bash
#
# Auto-Sync Script - Syncs GitHub repositories to Raspberry Pi
# Can be triggered via webhook or cron
#

ARCHIVE_ROOT="/archive"
GIT_DIR="$ARCHIVE_ROOT/git/projects"
LOG_FILE="$ARCHIVE_ROOT/logs/auto-sync.log"

# List of repositories to sync (can be configured)
REPOS=(
    "timrecursify/desaas"
    "timrecursify/desaas-frontend"
    # Add more repos as needed
)

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

sync_repo() {
    local repo_name="$1"
    local github_url="https://github.com/${repo_name}.git"
    local repo_path="${GIT_DIR}/${repo_name##*/}.git"
    
    log "Syncing repository: $repo_name"
    
    if [ -d "$repo_path" ]; then
        cd "$repo_path"
        git remote set-url origin "$github_url" 2>/dev/null
        git fetch --all --prune >> "$LOG_FILE" 2>&1
        log "Updated: $repo_name"
    else
        git clone --mirror "$github_url" "$repo_path" >> "$LOG_FILE" 2>&1
        log "Cloned: $repo_name"
    fi
}

# Sync all configured repositories
for repo in "${REPOS[@]}"; do
    sync_repo "$repo"
done

log "Auto-sync completed"
AUTO_SYNC_SCRIPT

echo "📤 Uploading auto-sync script to Raspberry Pi..."
scp /tmp/auto-sync.sh "$PI_HOST:$PI_ARCHIVE/scripts/auto-sync.sh"
ssh "$PI_HOST" "chmod +x $PI_ARCHIVE/scripts/auto-sync.sh"
rm /tmp/auto-sync.sh

echo "✅ Auto-sync script created on Raspberry Pi"
echo "   Location: $PI_ARCHIVE/scripts/auto-sync.sh"
echo ""
echo "To enable cron-based sync, run on Pi:"
echo "  echo '*/5 * * * * $PI_ARCHIVE/scripts/auto-sync.sh' | crontab -"

