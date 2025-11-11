#!/bin/bash
#
# Daily Backup Script for Archive System
# Backs up metadata and state files to deep archive
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LOG_COMPONENT="backup"
source "$SCRIPT_DIR/lib/logger.sh" 2>/dev/null || {
    log_info() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
    log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1"; }
}

BACKUP_DIR="/mnt/ssd/archive/archived/system-backups"
METADATA_DIR="/mnt/ssd/archive/metadata"
RETENTION_DAYS=7

main() {
    log_info "Starting archive system backup" "{\"timestamp\":\"$(date -Iseconds)\"}"
    
    mkdir -p "$BACKUP_DIR" 2>/dev/null || true
    
    local backup_file="$BACKUP_DIR/system-backup-$(date +%Y-%m-%d).tar.gz"
    local start_time=$(date +%s)
    
    # Backup metadata and state files
    if tar -czf "$backup_file" -C "$METADATA_DIR" . 2>/dev/null; then
        local backup_size=$(du -sm "$backup_file" 2>/dev/null | awk '{print $1}' || echo "0")
        local backup_duration=$(($(date +%s) - start_time))
        
        log_info "Backup created successfully" "{\"file\":\"$backup_file\",\"size_mb\":$backup_size,\"duration\":$backup_duration}"
        
        # Cleanup old backups
        find "$BACKUP_DIR" -name "system-backup-*.tar.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
        
        log_info "Old backups cleaned (retention: $RETENTION_DAYS days)" "{\"retention_days\":$RETENTION_DAYS}"
    else
        log_error "Backup failed" "{\"file\":\"$backup_file\"}"
        exit 1
    fi
}

main

