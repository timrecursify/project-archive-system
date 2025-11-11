#!/bin/bash
#
# Archive System Health Check
# Monitors system health and sends alerts if issues detected
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LOG_COMPONENT="health-check"
source "$SCRIPT_DIR/lib/logger.sh" 2>/dev/null || {
    log_info() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
    log_warn() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $1"; }
    log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1"; }
}

ACTIVE_ARCHIVE="/mnt/ssd/archive/git/projects"
DEEP_ARCHIVE="/mnt/ssd/archive/archived/compressed/projects"
STATE_FILE="/mnt/ssd/archive/metadata/github-sync-state.json"
PULLER_STATE="/mnt/ssd/archive/metadata/puller-state.json"
HEALTH_FILE="/mnt/ssd/archive/metadata/system-health.json"

check_disk_space() {
    local usage=$(df -h /mnt/ssd | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$usage" -gt 90 ]; then
        log_warn "Disk space critical" "{\"usage_percent\":$usage,\"threshold\":90}"
        return 1
    elif [ "$usage" -gt 80 ]; then
        log_warn "Disk space warning" "{\"usage_percent\":$usage,\"threshold\":80}"
    else
        log_info "Disk space OK" "{\"usage_percent\":$usage}"
    fi
    return 0
}

check_last_runs() {
    local auto_sync_last=$(jq -r '.last_run // "never"' "$STATE_FILE" 2>/dev/null || echo "never")
    local puller_last=$(jq -r '.last_run // "never"' "$PULLER_STATE" 2>/dev/null || echo "never")
    
    if [ "$auto_sync_last" != "never" ]; then
        local auto_sync_age=$(($(date +%s) - $(date -d "$auto_sync_last" +%s 2>/dev/null || echo 0)))
        if [ $auto_sync_age -gt 7200 ]; then  # 2 hours
            log_warn "Auto-sync last run too old" "{\"last_run\":\"$auto_sync_last\",\"age_seconds\":$auto_sync_age}"
        fi
    fi
    
    if [ "$puller_last" != "never" ]; then
        local puller_age=$(($(date +%s) - $(date -d "$puller_last" +%s 2>/dev/null || echo 0)))
        if [ $puller_age -gt 7200 ]; then  # 2 hours
            log_warn "Puller last run too old" "{\"last_run\":\"$puller_last\",\"age_seconds\":$puller_age}"
        fi
    fi
    
    log_info "Last runs checked" "{\"auto_sync\":\"$auto_sync_last\",\"puller\":\"$puller_last\"}"
}

check_repo_counts() {
    local active_count=$(find "$ACTIVE_ARCHIVE" -maxdepth 1 -type d -name "*.git" 2>/dev/null | wc -l)
    local archived_count=$(find "$DEEP_ARCHIVE" -maxdepth 1 -type f -name "*.tar.gz" 2>/dev/null | wc -l)
    
    log_info "Repository counts" "{\"active\":$active_count,\"archived\":$archived_count}"
}

main() {
    log_info "Health check starting" "{\"timestamp\":\"$(date -Iseconds)\"}"
    
    local issues=0
    
    check_disk_space || issues=$((issues + 1))
    check_last_runs
    check_repo_counts
    
    local health_json=$(jq -n \
        --arg ts "$(date -Iseconds)" \
        --arg issues "$issues" \
        '{
            timestamp: $ts,
            status: (if ($issues | tonumber) == 0 then "healthy" else "warning" end),
            issues: ($issues | tonumber)
        }' 2>/dev/null || echo "{\"timestamp\":\"$(date -Iseconds)\",\"status\":\"unknown\",\"issues\":$issues}")
    
    mkdir -p "$(dirname "$HEALTH_FILE")" 2>/dev/null || true
    echo "$health_json" > "$HEALTH_FILE"
    
    log_info "Health check complete" "$health_json"
}

main

