#!/bin/bash
set -e

echo "🔄 Syncing Reshoring HQ Git and Archiving..."
echo "=============================================="

cd "/Users/timvoss/Projects/Reshoring HQ"

# Sync Git
echo ""
echo "📥 Fetching latest from GitHub..."
git fetch --all --prune

echo "⬇️  Pulling latest changes..."
git pull origin main

echo "📝 Latest commit:"
git log -1 --oneline

REMOTE=$(git remote get-url origin)
echo "🔗 Remote: $REMOTE"

# Archive to Pi
echo ""
echo "📤 Archiving to Raspberry Pi..."
ssh raspberry-pi "mkdir -p /archive/git/projects"

if ssh raspberry-pi "test -d '/archive/git/projects/Reshoring HQ.git'"; then
    echo "   Updating existing archive..."
    ssh raspberry-pi "cd '/archive/git/projects/Reshoring HQ.git' && git remote set-url origin '$REMOTE' && git fetch --all --prune"
else
    echo "   Creating new archive..."
    ssh raspberry-pi "cd /archive/git/projects && git clone --mirror '$REMOTE' 'Reshoring HQ.git'"
fi

# Verify
echo ""
echo "✅ Verification:"
if ssh raspberry-pi "test -d '/archive/git/projects/Reshoring HQ.git'"; then
    echo "   ✅ Archive exists on Pi"
    ssh raspberry-pi "du -sh '/archive/git/projects/Reshoring HQ.git'"
    ssh raspberry-pi "cd '/archive/git/projects/Reshoring HQ.git' && git log -1 --oneline"
else
    echo "   ❌ Archive not found"
    exit 1
fi

echo ""
echo "✅ Complete! Reshoring HQ synced and archived."

