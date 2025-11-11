#!/bin/bash
#
# Verify Reshoring HQ Archive
#

echo "🔍 Verifying Reshoring HQ Archive Status"
echo "========================================"
echo ""

# Check local Git status
echo "📌 Local Git Status:"
cd "/Users/timvoss/Projects/Reshoring HQ" 2>/dev/null || { echo "❌ Project not found"; exit 1; }
echo "Current branch: $(git branch --show-current)"
echo "Latest commit: $(git log -1 --oneline)"
echo "Remote: $(git remote get-url origin)"
echo ""

# Check Pi archive
echo "📦 Raspberry Pi Archive Status:"
if ssh raspberry-pi "test -d '/archive/git/projects/Reshoring HQ.git'" 2>/dev/null; then
    echo "✅ Archive exists on Pi"
    ssh raspberry-pi "du -sh '/archive/git/projects/Reshoring HQ.git'"
    ssh raspberry-pi "cd '/archive/git/projects/Reshoring HQ.git' && git log -1 --oneline"
else
    echo "❌ Archive not found on Pi"
fi

echo ""
echo "✅ Verification complete"

