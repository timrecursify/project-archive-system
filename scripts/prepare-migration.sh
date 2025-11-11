#!/bin/bash
#
# Prepare Project Migration Script
# Prepares projects for migration to Raspberry Pi deep archive
#
# Usage: ./prepare-migration.sh <project-name> <archive-type>
# Archive types: active, deep, other
#

set -e

PROJECT_NAME="$1"
ARCHIVE_TYPE="${2:-deep}"

if [ -z "$PROJECT_NAME" ]; then
    echo "Usage: $0 <project-name> [archive-type]"
    echo "Archive types: active, deep, other"
    exit 1
fi

ARCHIVE_ROOT="$HOME/Projects/.archive"
PROJECT_PATH="$HOME/Projects/$PROJECT_NAME"

if [ ! -d "$PROJECT_PATH" ]; then
    echo "❌ Project not found: $PROJECT_PATH"
    exit 1
fi

echo "📦 Preparing project: $PROJECT_NAME"
echo "Archive type: $ARCHIVE_TYPE"

# Step 1: Check Git status
if [ -d "$PROJECT_PATH/.git" ]; then
    echo "✅ Git repository found"
    cd "$PROJECT_PATH"
    REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
    if [ -n "$REMOTE" ]; then
        echo "   Remote: $REMOTE"
    else
        echo "   ⚠️  No remote configured"
    fi
else
    echo "⚠️  No Git repository found"
fi

# Step 2: Remove dependencies
echo "🧹 Cleaning dependencies..."
cd "$PROJECT_PATH"
find . -type d -name "node_modules" -exec rm -rf {} + 2>/dev/null && echo "   ✅ Removed node_modules" || true
find . -type d \( -name "venv" -o -name ".venv" \) -exec rm -rf {} + 2>/dev/null && echo "   ✅ Removed venv" || true
find . -type d -name ".wrangler" -exec rm -rf {} + 2>/dev/null && echo "   ✅ Removed .wrangler" || true
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null && echo "   ✅ Removed __pycache__" || true
find . -type d -name ".next" -exec rm -rf {} + 2>/dev/null && echo "   ✅ Removed .next" || true
find . -type d -name "dist" -exec rm -rf {} + 2>/dev/null && echo "   ✅ Removed dist" || true
find . -type d -name "build" -exec rm -rf {} + 2>/dev/null && echo "   ✅ Removed build" || true

# Step 3: Calculate size
SIZE=$(du -sh "$PROJECT_PATH" | cut -f1)
echo "📊 Project size: $SIZE"

# Step 4: Create archive based on type
case "$ARCHIVE_TYPE" in
    active)
        echo "📁 Preparing for active archive (Git sync)"
        TARGET="$ARCHIVE_ROOT/git/projects/$PROJECT_NAME.git"
        if [ -d "$PROJECT_PATH/.git" ] && [ -n "$REMOTE" ]; then
            echo "   Creating bare repository mirror..."
            git clone --mirror "$PROJECT_PATH" "$TARGET" 2>/dev/null || echo "   ⚠️  Mirror creation skipped"
        fi
        ;;
    deep)
        echo "📁 Preparing for deep archive (compressed)"
        TARGET="$ARCHIVE_ROOT/archived/compressed/projects/$PROJECT_NAME"
        mkdir -p "$TARGET"
        echo "   Ready for compression"
        ;;
    other)
        echo "📁 Preparing for other archive (non-project)"
        TARGET="$ARCHIVE_ROOT/archived/compressed/other/$PROJECT_NAME"
        mkdir -p "$TARGET"
        echo "   Ready for compression"
        ;;
esac

echo "✅ Preparation complete: $PROJECT_NAME"
echo "   Target: $TARGET"
echo "   Size: $SIZE"

