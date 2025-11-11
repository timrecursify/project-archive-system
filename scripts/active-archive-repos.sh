#!/bin/bash
#
# Active Archive Repositories to Raspberry Pi
# Syncs Git repositories to Pi as bare mirrors
# Clones locally first, then transfers to Pi
#

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <repo1> <repo2> ..."
    exit 1
fi

PI_HOST="raspberry-pi"
PI_ARCHIVE="/archive/git/projects"
LOCAL_TEMP="/tmp/git-mirrors"

mkdir -p "$LOCAL_TEMP"

for repo in "$@"; do
    echo "📦 Archiving repository: $repo"
    
    REMOTE="https://github.com/timrecursify/$repo.git"
    LOCAL_MIRROR="$LOCAL_TEMP/$repo.git"
    
    # Check if already exists on Pi
    if ssh "$PI_HOST" "test -d '$PI_ARCHIVE/$repo.git'" 2>/dev/null; then
        echo "   ✅ Already archived on Pi, skipping..."
        continue
    fi
    
    # Clone mirror locally
    echo "   Cloning mirror locally..."
    cd "$LOCAL_TEMP"
    if [ -d "$LOCAL_MIRROR" ]; then
        rm -rf "$LOCAL_MIRROR"
    fi
    git clone --mirror "$REMOTE" "$repo.git" 2>&1 | grep -E "(Cloning|done|error)" || true
    
    # Transfer to Pi
    echo "   Transferring to Pi..."
    ssh "$PI_HOST" "mkdir -p $PI_ARCHIVE"
    rsync -av --delete "$LOCAL_MIRROR/" "$PI_HOST:$PI_ARCHIVE/$repo.git/" 2>&1 | tail -3
    
    # Cleanup local mirror immediately
    rm -rf "$LOCAL_MIRROR"
    
    echo "   ✅ Archived: $repo"
    echo ""
done

echo ""
echo "✅ Active archive complete"

