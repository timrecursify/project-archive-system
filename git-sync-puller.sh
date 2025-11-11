#!/bin/bash
#
# Git Repository Sync Puller (Cron-based)
# Periodically checks all Git repositories for updates and syncs them
# Production-grade logging with USB storage compliance
#

set -e

# Source logging library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LOG_COMPONENT="git-sync-puller"
source "$SCRIPT_DIR/lib/logger.sh" 2>/dev/null || {
    # Fallback if logger not available
    log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
    log_info() { log "$@"; }
    log_warn() { log "$@"; }
    log_error() { log "$@"; }
}

GIT_ARCHIVE_DIR="/mnt/ssd/archive/git/projects"
STATE_FILE="/mnt/ssd/archive/metadata/puller-state.json"

sync_repo() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path" .git)
    local start_time=$(date +%s)
    
    cd "$repo_path" || return 1
    
    # Check if remote exists
    if ! git remote get-url origin &>/dev/null; then
        log_warn "SKIP: $repo_name - no remote configured" "{\"repo\":\"$repo_name\",\"reason\":\"no_remote\"}"
        return 0
    fi
    
    # Get current HEAD before fetch
    local old_head=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    
    # Fetch latest changes with timeout
    local fetch_output=$(timeout 30 git fetch --all --prune 2>&1)
    local fetch_result=$?
    local fetch_duration=$(($(date +%s) - start_time))
    
    if [ $fetch_result -eq 0 ] || [ $fetch_result -eq 124 ]; then
        # Success or timeout (both are acceptable for fetch)
        # For bare repos, fetch updates refs/heads/* directly
        
        # Get remote URL for ls-remote
        local remote_url=$(git remote get-url origin 2>/dev/null || echo "")
        
        # Try to detect main branch using ls-remote (works for bare repos)
        local main_branch=""
        local remote_commit=""
        
        for branch in main master; do
            remote_commit=$(git ls-remote origin "refs/heads/$branch" 2>/dev/null | awk '{print $1}' | head -1)
            if [ -n "$remote_commit" ] && [ "$remote_commit" != "" ]; then
                main_branch="$branch"
                break
            fi
        done
        
        if [ -z "$main_branch" ] || [ -z "$remote_commit" ]; then
            log_info "OK: $repo_name - synced (no main/master branch)" "{\"repo\":\"$repo_name\",\"duration\":$fetch_duration,\"status\":\"synced_no_branch\"}"
            return 0
        fi
        
        # Get local HEAD commit (for bare repos, HEAD points to refs/heads/main)
        local local_commit=$(git rev-parse HEAD 2>/dev/null || echo "")
        
        # Also try to get from refs/heads/main directly (bare repo structure)
        if [ -z "$local_commit" ] || [ "$local_commit" = "unknown" ]; then
            local_commit=$(git rev-parse "refs/heads/$main_branch" 2>/dev/null || echo "")
        fi
        
        if [ -n "$remote_commit" ] && [ -n "$local_commit" ] && [ "$local_commit" != "$remote_commit" ]; then
            # New commits detected
            local commit_count=$(git rev-list --count "$local_commit..$remote_commit" 2>/dev/null || echo "?")
            log_info "UPDATED: $repo_name - $commit_count new commit(s)" "{\"repo\":\"$repo_name\",\"commits\":$commit_count,\"duration\":$fetch_duration,\"branch\":\"$main_branch\",\"status\":\"updated\"}"
            
            # Update HEAD to point to the latest commit (for bare repos)
            git update-ref HEAD "$remote_commit" 2>/dev/null || true
            git update-ref "refs/heads/$main_branch" "$remote_commit" 2>/dev/null || true
            
            return 2  # Return code 2 for updated
        else
            log_info "OK: $repo_name - no updates" "{\"repo\":\"$repo_name\",\"duration\":$fetch_duration,\"status\":\"unchanged\"}"
            return 0
        fi
    else
        log_error "ERROR: $repo_name - fetch failed or timed out" "{\"repo\":\"$repo_name\",\"duration\":$fetch_duration,\"error\":\"fetch_failed\",\"exit_code\":$fetch_result}"
        return 1
    fi
}

# Main execution
main() {
    local start_time=$(date +%s)
    
    log_info "Git Sync Puller - Starting" "{\"component\":\"git-sync-puller\",\"start_time\":\"$(date -Iseconds)\"}"
    
    # Check if git archive directory exists
    if [ ! -d "$GIT_ARCHIVE_DIR" ]; then
        log_error "Git archive directory not found: $GIT_ARCHIVE_DIR" "{\"path\":\"$GIT_ARCHIVE_DIR\",\"error\":\"directory_missing\"}"
        exit 1
    fi
    
    # Count repositories
    local repo_count=$(find "$GIT_ARCHIVE_DIR" -maxdepth 1 -type d -name "*.git" 2>/dev/null | wc -l)
    log_info "Checking $repo_count repositories" "{\"repo_count\":$repo_count}"
    
    # Sync all repositories
    local updated=0
    local failed=0
    local unchanged=0
    local skipped=0
    
    for repo in "$GIT_ARCHIVE_DIR"/*.git; do
        if [ -d "$repo" ]; then
            sync_repo "$repo"
            local sync_result=$?
            
            case $sync_result in
                0) unchanged=$((unchanged + 1)) ;;
                1) failed=$((failed + 1)) ;;
                2) updated=$((updated + 1)) ;;
                *) unchanged=$((unchanged + 1)) ;;
            esac
        fi
    done
    
    local total_duration=$(($(date +%s) - start_time))
    local summary_json=$(jq -n \
        --arg updated "$updated" \
        --arg unchanged "$unchanged" \
        --arg failed "$failed" \
        --arg duration "$total_duration" \
        --arg repo_count "$repo_count" \
        '{
            updated: ($updated | tonumber),
            unchanged: ($unchanged | tonumber),
            failed: ($failed | tonumber),
            total: ($repo_count | tonumber),
            duration_seconds: ($duration | tonumber)
        }' 2>/dev/null || echo "{\"updated\":$updated,\"unchanged\":$unchanged,\"failed\":$failed,\"duration\":$total_duration}")
    
    log_info "Summary: $updated updated, $unchanged unchanged, $failed failed" "$summary_json"
    
    # Update state file
    mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true
    echo "$summary_json" | jq --arg ts "$(date -Iseconds)" '. + {last_run: $ts}' > "$STATE_FILE" 2>/dev/null || true
}

# Run main function
main
