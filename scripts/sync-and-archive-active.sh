#!/bin/bash
#
# Sync Git and Archive Active Project
# Syncs latest Git changes and archives as active project
#
# Usage: ./sync-and-archive-active.sh <project-name>

set -e

PROJECT_NAME="$1"

if [ -z "$PROJECT_NAME" ]; then
    echo "Usage: $0 <project-name>"
    exit 1
fi

PROJECT_PATH="$HOME/Projects/$PROJECT_NAME"

if [ ! -d "$PROJECT_PATH" ]; then
    echo "❌ Project not found: $PROJECT_PATH"
    exit 1
fi

echo "🔄 Syncing Git repository for: $PROJECT_NAME"

cd "$PROJECT_PATH"

# Check if Git repo exists
if [ ! -d ".git" ]; then
    echo "❌ No Git repository found"
    exit 1
fi

# Get current branch
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
echo "📌 Current branch: $CURRENT_BRANCH"

# Fetch latest from remote
echo "📥 Fetching latest from remote..."
git fetch --all --prune

# Pull latest changes
echo "⬇️  Pulling latest changes..."
git pull origin "$CURRENT_BRANCH" || echo "⚠️  Pull may have conflicts, check manually"

# Show latest commits
echo "📝 Latest commits:"
git log --oneline -5

# Show remote URL
REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
if [ -n "$REMOTE" ]; then
    echo "🔗 Remote: $REMOTE"
else
    echo "⚠️  No remote configured"
fi

echo "✅ Git sync complete"

# Now archive as active
echo ""
echo "📦 Archiving as active project..."
"$HOME/Projects/.archive/scripts/migrate-to-pi.sh" "$PROJECT_NAME" active

echo "✅ Complete: $PROJECT_NAME synced and archived"

