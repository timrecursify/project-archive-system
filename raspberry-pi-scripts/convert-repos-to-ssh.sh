#!/bin/bash
#
# Convert all Git repositories from HTTPS to SSH URLs
# This allows the puller to fetch without authentication prompts
#

set -e

GIT_ARCHIVE_DIR="/mnt/ssd/archive/git/projects"

echo "Converting Git repositories from HTTPS to SSH..."
echo ""

converted=0
skipped=0

for repo in "$GIT_ARCHIVE_DIR"/*.git; do
    if [ -d "$repo" ]; then
        repo_name=$(basename "$repo" .git)
        cd "$repo"
        
        # Get current remote URL
        current_url=$(git remote get-url origin 2>/dev/null || echo "")
        
        if echo "$current_url" | grep -q "^https://github.com/"; then
            # Extract user and repo name using sed
            github_user=$(echo "$current_url" | sed 's|https://github.com/||' | sed 's|/.*||')
            github_repo=$(echo "$current_url" | sed 's|https://github.com/[^/]*/||' | sed 's|\.git$||')
            
            # Convert to SSH URL
            ssh_url="git@github.com:${github_user}/${github_repo}.git"
            
            echo "Converting $repo_name:"
            echo "  From: $current_url"
            echo "  To:   $ssh_url"
            
            git remote set-url origin "$ssh_url"
            converted=$((converted + 1))
        else
            echo "Skipping $repo_name (not HTTPS GitHub URL)"
            skipped=$((skipped + 1))
        fi
        
        echo ""
    fi
done

echo "=========================================="
echo "Conversion complete!"
echo "Converted: $converted repositories"
echo "Skipped: $skipped repositories"
echo "=========================================="

