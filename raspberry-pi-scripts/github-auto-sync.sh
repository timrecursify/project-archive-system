#!/bin/bash
#
# GitHub Auto-Sync - Automated Repository Management
# Production-grade logging with USB storage compliance
#
# Features:
# - Auto-detects all GitHub repositories
# - Auto-clones new repos to active archive
# - Auto-archives deleted repos to deep storage
# - Maintains state and logs all actions
#

set -e

# Source logging library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LOG_COMPONENT="github-auto-sync"
source "$SCRIPT_DIR/lib/logger.sh" 2>/dev/null || {
    # Fallback if logger not available
    log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
    log_info() { log "$@"; }
    log_warn() { log "$@"; }
    log_error() { log "$@"; }
    log_security() { log_warn "SECURITY: $@"; }
}

# Configuration
GITHUB_USER="timrecursify"
ACTIVE_ARCHIVE="/mnt/ssd/archive/git/projects"
DEEP_ARCHIVE="/mnt/ssd/archive/archived/compressed/projects"
STATE_FILE="/mnt/ssd/archive/metadata/github-sync-state.json"
CACHE_FILE="/tmp/github-repos-cache.json"
CACHE_TTL=300  # 5 minutes

# Ensure directories exist
mkdir -p "$ACTIVE_ARCHIVE" "$DEEP_ARCHIVE" "$(dirname "$STATE_FILE")" 2>/dev/null || true

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    log_error "GitHub CLI not installed" "{\"error\":\"gh_not_found\",\"fix\":\"sudo apt install gh\"}"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    log_error "Not authenticated with GitHub" "{\"error\":\"not_authenticated\",\"fix\":\"gh auth login\"}"
    exit 1
fi

# Fetch GitHub repository list (with caching)
fetch_github_repos() {
    # Check cache validity
    if [ -f "$CACHE_FILE" ]; then
        local cache_age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null) ))
        if [ "$cache_age" -lt "$CACHE_TTL" ]; then
            log_info "Using cached GitHub repo list" "{\"cache_age_seconds\":$cache_age,\"cache_ttl\":$CACHE_TTL}"
            cat "$CACHE_FILE"
            return 0
        fi
    fi
    
    log_info "Fetching GitHub repository list" "{\"user\":\"$GITHUB_USER\",\"cache_ttl\":$CACHE_TTL}"
    log_security "github_api_access" "Fetching repository list" "{\"user\":\"$GITHUB_USER\",\"operation\":\"list_repos\"}"
    
    local fetch_start=$(date +%s)
    gh repo list "$GITHUB_USER" \
        --limit 1000 \
        --json name,sshUrl,isArchived,isPrivate,updatedAt \
        --jq '.[] | select(.isArchived == false)' > "$CACHE_FILE" 2>&1
    
    local fetch_result=$?
    local fetch_duration=$(($(date +%s) - fetch_start))
    
    if [ $fetch_result -ne 0 ]; then
        log_error "Failed to fetch GitHub repositories" "{\"user\":\"$GITHUB_USER\",\"exit_code\":$fetch_result,\"duration\":$fetch_duration}"
        return 1
    fi
    
    local repo_count=$(jq -s 'length' "$CACHE_FILE" 2>/dev/null || echo "0")
    log_info "Found $repo_count active repositories on GitHub" "{\"repo_count\":$repo_count,\"duration\":$fetch_duration}"
    
    cat "$CACHE_FILE"
}

# Get list of local repositories
get_local_repos() {
    find "$ACTIVE_ARCHIVE" -maxdepth 1 -type d -name "*.git" -exec basename {} .git \; | sort
}

# Get list of deep archived repositories
get_archived_repos() {
    find "$DEEP_ARCHIVE" -maxdepth 1 -type f -name "*.tar.gz" -exec basename {} .tar.gz \; | sort
}

# Clone new repository
clone_repo() {
    local repo_name="$1"
    local repo_url="$2"
    local repo_path="$ACTIVE_ARCHIVE/${repo_name}.git"
    local start_time=$(date +%s)
    
    log_info "CLONING: $repo_name" "{\"repo\":\"$repo_name\",\"url\":\"$repo_url\",\"operation\":\"clone\"}"
    log_security "github_repo_clone" "Cloning repository" "{\"repo\":\"$repo_name\",\"url\":\"$repo_url\"}"
    
    if git clone --mirror "$repo_url" "$repo_path" 2>&1 | grep -v "^Cloning"; then
        local clone_duration=$(($(date +%s) - start_time))
        local repo_size=$(du -sm "$repo_path" 2>/dev/null | awk '{print $1}' || echo "0")
        log_info "CLONED: $repo_name" "{\"repo\":\"$repo_name\",\"duration\":$clone_duration,\"size_mb\":$repo_size,\"status\":\"success\"}"
        return 0
    else
        local clone_duration=$(($(date +%s) - start_time))
        log_error "CLONE FAILED: $repo_name" "{\"repo\":\"$repo_name\",\"duration\":$clone_duration,\"status\":\"failed\"}"
        return 1
    fi
}

# Archive deleted repository to deep storage
archive_repo() {
    local repo_name="$1"
    local repo_path="$ACTIVE_ARCHIVE/${repo_name}.git"
    local archive_path="$DEEP_ARCHIVE/${repo_name}.tar.gz"
    local start_time=$(date +%s)
    
    # Skip if already archived
    if [ -f "$archive_path" ]; then
        log_info "SKIPPING: $repo_name (already in deep archive)" "{\"repo\":\"$repo_name\",\"reason\":\"already_archived\"}"
        rm -rf "$repo_path" 2>/dev/null || true
        return 0
    fi
    
    log_info "ARCHIVING: $repo_name → deep storage" "{\"repo\":\"$repo_name\",\"operation\":\"archive\",\"source\":\"$repo_path\",\"destination\":\"$archive_path\"}"
    
    # Get repo size before archiving
    local repo_size=$(du -sm "$repo_path" 2>/dev/null | awk '{print $1}' || echo "0")
    
    # Create compressed archive
    if tar -czf "$archive_path" -C "$ACTIVE_ARCHIVE" "${repo_name}.git" 2>&1 | grep -v "^tar"; then
        # Verify archive
        if tar -tzf "$archive_path" &> /dev/null; then
            local archive_size=$(du -sm "$archive_path" 2>/dev/null | awk '{print $1}' || echo "0")
            local archive_duration=$(($(date +%s) - start_time))
            local compression_ratio=$(echo "scale=2; $archive_size / $repo_size" | bc 2>/dev/null || echo "0")
            
            rm -rf "$repo_path"
            log_info "ARCHIVED: $repo_name (deleted from GitHub)" "{\"repo\":\"$repo_name\",\"duration\":$archive_duration,\"original_size_mb\":$repo_size,\"archive_size_mb\":$archive_size,\"compression_ratio\":$compression_ratio,\"status\":\"success\"}"
            return 0
        else
            log_error "ARCHIVE VERIFICATION FAILED: $repo_name" "{\"repo\":\"$repo_name\",\"archive_path\":\"$archive_path\"}"
            rm -f "$archive_path"
            return 1
        fi
    else
        local archive_duration=$(($(date +%s) - start_time))
        log_error "ARCHIVE FAILED: $repo_name" "{\"repo\":\"$repo_name\",\"duration\":$archive_duration,\"status\":\"failed\"}"
        return 1
    fi
}

# Initialize state file if doesn't exist
if [ ! -f "$STATE_FILE" ]; then
    echo '{"last_run": null, "repos_cloned": 0, "repos_archived": 0}' > "$STATE_FILE"
fi

# Main execution
main() {
    local start_time=$(date +%s)
    
    log_info "GitHub Auto-Sync - Starting" "{\"component\":\"github-auto-sync\",\"start_time\":\"$(date -Iseconds)\"}"
    
    # Fetch GitHub repos
    local github_repos=$(fetch_github_repos)
    if [ $? -ne 0 ]; then
        log_error "Failed to fetch GitHub repositories - aborting" "{\"error\":\"fetch_failed\"}"
        exit 1
    fi
    
    local github_names=$(echo "$github_repos" | jq -r '.name' 2>/dev/null | sort | grep -v '^$')
    local github_count=$(echo "$github_names" | grep -c . 2>/dev/null | tr -d '\n' || echo "0")
    github_count=$(echo "$github_count" | tr -d '\n')
    github_count=${github_count:-0}
    
    # Get local repos
    local local_repos=$(get_local_repos)
    local local_count=$(echo "$local_repos" | grep -c . 2>/dev/null | tr -d '\n' || echo "0")
    local_count=$(echo "$local_count" | tr -d '\n')
    local_count=${local_count:-0}
    
    # Get archived repos
    local archived_repos=$(get_archived_repos)
    local archived_count=$(echo "$archived_repos" | grep -c . 2>/dev/null | tr -d '\n' || echo "0")
    archived_count=$(echo "$archived_count" | tr -d '\n')
    archived_count=${archived_count:-0}
    
    log_info "Repository counts" "{\"github\":$github_count,\"local\":$local_count,\"archived\":$archived_count}"
    
    # Find new repositories (on GitHub but not local)
    local new_repos=$(comm -23 <(echo "$github_names") <(echo "$local_repos") 2>/dev/null | grep -v '^$')
    local new_count=$(echo "$new_repos" | grep -c . 2>/dev/null | tr -d '\n' || echo "0")
    new_count=$(echo "$new_count" | tr -d '\n')
    new_count=${new_count:-0}
    
    # Find deleted repositories (local but not on GitHub and not archived)
    local deleted_repos=$(comm -23 <(echo "$local_repos") <(echo "$github_names") 2>/dev/null | grep -v '^$')
    local deleted_count=$(echo "$deleted_repos" | grep -c . 2>/dev/null | tr -d '\n' || echo "0")
    deleted_count=$(echo "$deleted_count" | tr -d '\n')
    deleted_count=${deleted_count:-0}
    
    log_info "Operations needed" "{\"new_repos\":$new_count,\"deleted_repos\":$deleted_count}"
    
    # Clone new repositories
    local cloned=0
    if [ -n "$new_repos" ] && [ "$new_count" -gt 0 ]; then
        log_info "Cloning new repositories" "{\"count\":$new_count}"
        
        while IFS= read -r repo_name; do
            if [ -z "$repo_name" ]; then continue; fi
            
            # Get SSH URL from GitHub data
            local ssh_url=$(echo "$github_repos" | jq -r "select(.name == \"$repo_name\") | .sshUrl" 2>/dev/null)
            
            if [ -n "$ssh_url" ] && [ "$ssh_url" != "null" ]; then
                if clone_repo "$repo_name" "$ssh_url"; then
                    cloned=$((cloned + 1))
                fi
            else
                log_warn "No SSH URL found for $repo_name" "{\"repo\":\"$repo_name\"}"
            fi
        done <<< "$new_repos"
    fi
    
    # Archive deleted repositories
    local archived=0
    if [ -n "$deleted_repos" ] && [ "$deleted_count" -gt 0 ]; then
        log_info "Archiving deleted repositories" "{\"count\":$deleted_count}"
        
        while IFS= read -r repo_name; do
            if [ -z "$repo_name" ]; then continue; fi
            
            if archive_repo "$repo_name"; then
                archived=$((archived + 1))
            fi
        done <<< "$deleted_repos"
    fi
    
    # Update state
    local total_duration=$(($(date +%s) - start_time))
    local total_cloned=$(jq -r '.repos_cloned // 0' "$STATE_FILE" 2>/dev/null || echo "0")
    local total_archived=$(jq -r '.repos_archived // 0' "$STATE_FILE" 2>/dev/null || echo "0")
    
    local state_json=$(jq -n \
        --arg date "$(date -Iseconds)" \
        --arg cloned "$((total_cloned + cloned))" \
        --arg archived "$((total_archived + archived))" \
        --arg github_total "$github_count" \
        --arg local_total "$local_count" \
        --arg archived_total "$archived_count" \
        --arg duration "$total_duration" \
        '{
            last_run: $date,
            repos_cloned: ($cloned | tonumber),
            repos_archived: ($archived | tonumber),
            github_repos_total: ($github_total | tonumber),
            active_archive_count: ($local_total | tonumber),
            deep_archive_count: ($archived_total | tonumber),
            duration_seconds: ($duration | tonumber)
        }' 2>/dev/null || echo "{\"last_run\":\"$(date -Iseconds)\",\"repos_cloned\":$((total_cloned + cloned)),\"repos_archived\":$((total_archived + archived))}")
    
    echo "$state_json" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE" 2>/dev/null || true
    
    # Ensure all variables are integers for arithmetic (strip any whitespace/newlines)
    github_count=$(echo "$github_count" | tr -d '[:space:]')
    new_count=$(echo "$new_count" | tr -d '[:space:]')
    cloned=$(echo "$cloned" | tr -d '[:space:]')
    archived=$(echo "$archived" | tr -d '[:space:]')
    
    github_count=${github_count:-0}
    new_count=${new_count:-0}
    cloned=${cloned:-0}
    archived=${archived:-0}
    
    local active_count=$((github_count - new_count + cloned - archived))
    log_info "Summary: $cloned cloned | $archived archived | $active_count active" "{\"cloned\":$cloned,\"archived\":$archived,\"active\":$active_count,\"duration\":$total_duration}"
}

# Run main function
main

