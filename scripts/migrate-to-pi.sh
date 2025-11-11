#!/bin/bash
#
# Migrate Project to Raspberry Pi
# Transfers prepared projects to Raspberry Pi deep archive
#
# Usage: ./migrate-to-pi.sh <project-name> <archive-type>
#

set -e

PROJECT_NAME="$1"
ARCHIVE_TYPE="${2:-deep}"

if [ -z "$PROJECT_NAME" ]; then
    echo "Usage: $0 <project-name> [archive-type]"
    echo "Archive types: active, deep, other"
    exit 1
fi

PI_HOST="raspberry-pi"
PI_ARCHIVE="/archive"
LOCAL_ARCHIVE="$HOME/Projects/.archive"
PROJECT_PATH="$HOME/Projects/$PROJECT_NAME"

if [ ! -d "$PROJECT_PATH" ]; then
    echo "❌ Project not found: $PROJECT_PATH"
    exit 1
fi

echo "🚀 Migrating project to Raspberry Pi: $PROJECT_NAME"
echo "Archive type: $ARCHIVE_TYPE"

# Check Pi connectivity
echo "🔍 Checking Pi connectivity..."
if ! ssh -o ConnectTimeout=5 "$PI_HOST" "echo 'Connected'" 2>/dev/null; then
    echo "❌ Cannot connect to Raspberry Pi"
    echo "   Host: $PI_HOST"
    echo "   Please verify SSH access"
    exit 1
fi

echo "✅ Pi connection verified"

# Prepare project first
echo "📦 Preparing project..."
"$LOCAL_ARCHIVE/scripts/prepare-migration.sh" "$PROJECT_NAME" "$ARCHIVE_TYPE"

# Migrate based on type
case "$ARCHIVE_TYPE" in
    active)
        echo "📤 Syncing Git repository to Pi..."
        if [ -d "$PROJECT_PATH/.git" ]; then
            REMOTE=$(cd "$PROJECT_PATH" && git remote get-url origin 2>/dev/null || echo "")
            if [ -n "$REMOTE" ]; then
                ssh "$PI_HOST" "mkdir -p $PI_ARCHIVE/git/projects"
                ssh "$PI_HOST" "cd $PI_ARCHIVE/git/projects && git clone --mirror '$REMOTE' '$PROJECT_NAME.git' 2>/dev/null || (cd '$PROJECT_NAME.git' && git remote set-url origin '$REMOTE' && git fetch --all --prune)"
                echo "✅ Git repository synced"
            fi
        fi
        ;;
    deep|other)
        COMPRESSED_DIR="projects"
        [ "$ARCHIVE_TYPE" = "other" ] && COMPRESSED_DIR="other"
        
        echo "📤 Compressing and transferring to Pi..."
        TEMP_TAR="/tmp/${PROJECT_NAME}.tar.gz"
        cd "$HOME/Projects"
        tar -czf "$TEMP_TAR" "$PROJECT_NAME" 2>/dev/null
        
        ssh "$PI_HOST" "mkdir -p $PI_ARCHIVE/archived/compressed/$COMPRESSED_DIR"
        scp "$TEMP_TAR" "$PI_HOST:$PI_ARCHIVE/archived/compressed/$COMPRESSED_DIR/${PROJECT_NAME}.tar.gz"
        rm "$TEMP_TAR"
        echo "✅ Project compressed and transferred (kept as tar.gz for restore)"
        ;;
esac

echo "✅ Migration complete: $PROJECT_NAME → Raspberry Pi"

