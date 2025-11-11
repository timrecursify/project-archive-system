#!/bin/bash
#
# Production-Grade Logging Library
# Compliant with CLAUDE.md standards - USB Storage Mandate
#

LOG_BASE="/mnt/ssd/logs/applications"
COMPONENT="${LOG_COMPONENT:-unknown}"

# Ensure log directories exist
mkdir -p "$LOG_BASE/$COMPONENT" "/mnt/ssd/logs/centralized" "/mnt/ssd/logs/security" 2>/dev/null || true

log() {
    local level="$1"
    shift
    local message="$1"
    shift
    local data_json="${1:-{}}"
    
    # Ensure data_json is valid JSON (if not, wrap it)
    if ! echo "$data_json" | jq . >/dev/null 2>&1; then
        data_json="{}"
    fi
    
    # Create structured log entry
    local log_entry
    if command -v jq >/dev/null 2>&1; then
        log_entry=$(jq -n \
            --arg ts "$(date -Iseconds)" \
            --arg lvl "$level" \
            --arg msg "$message" \
            --arg comp "$COMPONENT" \
            --arg host "$(hostname)" \
            --arg env "production" \
            --argjson data "$data_json" \
            '{
                timestamp: $ts,
                level: $lvl,
                message: $msg,
                component: $comp,
                host: $host,
                environment: $env,
                data: $data
            }' 2>/dev/null)
    fi
    
    # If jq fails or not available, create simple JSON
    if [ -z "$log_entry" ]; then
        log_entry="{\"timestamp\":\"$(date -Iseconds)\",\"level\":\"$level\",\"message\":\"$message\",\"component\":\"$COMPONENT\",\"host\":\"$(hostname)\",\"environment\":\"production\",\"data\":$data_json}"
    fi
    
    local log_file="$LOG_BASE/$COMPONENT/$COMPONENT-$(date +%Y-%m-%d).log"
    local centralized_file="/mnt/ssd/logs/centralized/archive-system-$(date +%Y-%m-%d).jsonl"
    
    # Write to component log (append, don't fail if directory missing)
    echo "$log_entry" >> "$log_file" 2>/dev/null || true
    
    # Write to centralized log
    echo "$log_entry" >> "$centralized_file" 2>/dev/null || true
    
    # Console output with timestamp
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >&2
}

log_info() {
    log "info" "$@"
}

log_warn() {
    log "warn" "$@"
}

log_error() {
    log "error" "$@"
}

log_debug() {
    if [ "${LOG_DEBUG:-0}" = "1" ]; then
        log "debug" "$@"
    fi
}

# Security event logging (separate from application logs)
log_security() {
    local event_type="$1"
    shift
    local message="$1"
    shift
    local data_json="${1:-{}}"
    
    local security_entry
    security_entry=$(jq -n \
        --arg ts "$(date -Iseconds)" \
        --arg type "$event_type" \
        --arg msg "$message" \
        --arg comp "$COMPONENT" \
        --arg host "$(hostname)" \
        --argjson data "$data_json" \
        '{
            timestamp: $ts,
            event_type: $type,
            message: $msg,
            component: $comp,
            host: $host,
            data: $data
        }' 2>/dev/null)
    
    if [ -z "$security_entry" ]; then
        security_entry="{\"timestamp\":\"$(date -Iseconds)\",\"event_type\":\"$event_type\",\"message\":\"$message\",\"component\":\"$COMPONENT\",\"host\":\"$(hostname)\",\"data\":$data_json}"
    fi
    
    local security_file="/mnt/ssd/logs/security/github-api-audit-$(date +%Y-%m-%d).log"
    echo "$security_entry" >> "$security_file" 2>/dev/null || true
    
    log_warn "SECURITY: $message" "$data_json"
}

