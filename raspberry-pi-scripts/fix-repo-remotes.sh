#!/bin/bash
#
# Fix Git repository remote URLs that point to local paths
# Converts them to proper GitHub SSH URLs
#

set -e

GIT_ARCHIVE_DIR="/mnt/ssd/archive/git/projects"
GITHUB_USER="timrecursify"

echo "Fixing Git repository remote URLs..."
echo ""

fixed=0
skipped=0
failed=0

for repo in "$GIT_ARCHIVE_DIR"/*.git; do
    if [ -d "$repo" ]; then
        repo_name=$(basename "$repo" .git)
        cd "$repo"
        
        # Get current remote URL
        current_url=$(git remote get-url origin 2>/dev/null || echo "")
        
        if [ -z "$current_url" ]; then
            echo "SKIP: $repo_name - no remote configured"
            skipped=$((skipped + 1))
            continue
        fi
        
        # Check if it's a local path (starts with /Users or /home)
        if echo "$current_url" | grep -qE "^/(Users|home)"; then
            # Convert to GitHub SSH URL
            ssh_url="git@github.com:${GITHUB_USER}/${repo_name}.git"
            
            echo "FIXING: $repo_name"
            echo "  From: $current_url"
            echo "  To:   $ssh_url"
            
            if git remote set-url origin "$ssh_url" 2>&1; then
                # Verify the remote works
                if git ls-remote origin &>/dev/null; then
                    echo "  ✓ Remote verified"
                    fixed=$((fixed + 1))
                else
                    echo "  ✗ Remote verification failed"
                    failed=$((failed + 1))
                fi
            else
                echo "  ✗ Failed to set remote URL"
                failed=$((failed + 1))
            fi
            echo ""
        elif echo "$current_url" | grep -qE "^git@github.com:|^https://github.com/"; then
            # Already correct GitHub URL
            skipped=$((skipped + 1))
        else
            echo "SKIP: $repo_name - unknown URL format: $current_url"
            skipped=$((skipped + 1))
        fi
        
        cd - > /dev/null
    fi
done

echo "=========================================="
echo "Fix complete!"
echo "Fixed: $fixed repositories"
echo "Skipped: $skipped repositories"
echo "Failed: $failed repositories"
echo "=========================================="
