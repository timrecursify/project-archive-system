#!/bin/bash
#
# Smart Active Archive - Uses local projects when available, syncs with GitHub first
# Creates BOTH Git mirror AND full directory archive (includes gitignored files)
#

set -e

PI_HOST="raspberry-pi"
PI_ARCHIVE="/mnt/ssd/archive/git/projects"
PI_FULL_ARCHIVE="/mnt/ssd/archive/archived/compressed/projects"
PROJECTS_DIR="$HOME/Projects"

# Name mapping function
get_local_name() {
    case "$1" in
        "Astropal") echo "Astropal_io" ;;
        "biopilot_frontend") echo "biopilot.io" ;;
        "FDM") echo "Findom" ;;
        "MacroApex"|"macroapex") echo "MacroApex" ;;
        "PPP_Newsletter_Bot") echo "PPP_Newsletter_Bot" ;;
        "ppp-salesmagic-connector") echo "PPP_salesmagic_connector" ;;
        "s4c") echo "S4C" ;;
        "salesmagic") echo "SalesMagic" ;;
        "ppp_google") echo "PPP_Google_Landings" ;;
        "PPP_Universal") echo "PPP_Universal_Page" ;;
        "PPP_wiki") echo "PPP_Wiki_Page" ;;
        "reshoringhq") echo "Reshoring HQ" ;;
        "lofi-engine") echo "LoFi Radio" ;;
        "phone2clip_frontend") echo "phone2clip" ;;
        "USGChat") echo "USG" ;;
        "voss-intelligence") echo "Voss Intelligence" ;;
        *) echo "$1" ;;
    esac
}

archive_repo() {
    local github_repo="$1"
    local local_name=$(get_local_name "$github_repo")
    local local_path="$PROJECTS_DIR/$local_name"
    
    echo "📦 Processing: $github_repo"
    
    # Check if exists locally (with or without Git)
    if [ -d "$local_path" ]; then
        has_git=false
        if [ -d "$local_path/.git" ]; then
            has_git=true
        fi
        echo "   ✅ Found locally as: $local_name"
        
        if [ "$has_git" = true ]; then
        echo "   🔄 Syncing with GitHub..."
        cd "$local_path"
        
        # Fetch and pull latest
        git fetch --all --prune 2>&1 | grep -E "(Fetching|Already|error)" || true
        CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
        git pull origin "$CURRENT_BRANCH" 2>&1 | grep -E "(Already|Updating|error)" || true
        else
            echo "   ⚠️  No Git repository - archiving all local files"
            cd "$local_path"
        fi
        
        echo "   🧹 Cleaning dependencies (keeping source files)..."
        find . -type d \( -name "node_modules" -o -name "venv" -o -name ".venv" -o -name ".wrangler" -o -name "__pycache__" -o -name ".next" -o -name "dist" -o -name "build" \) -exec rm -rf {} + 2>/dev/null || true
        
        # Create bare mirror from local (Git-tracked files only) - if Git repo exists
        if [ "$has_git" = true ]; then
        echo "   📤 Creating Git mirror on Pi..."
        TEMP_MIRROR="/tmp/${github_repo}.git"
        rm -rf "$TEMP_MIRROR"
        git clone --mirror "$local_path" "$TEMP_MIRROR" 2>&1 | grep -v "Cloning" || true
        
        ssh "$PI_HOST" "mkdir -p $PI_ARCHIVE"
        rsync -av --delete "$TEMP_MIRROR/" "$PI_HOST:$PI_ARCHIVE/${github_repo}.git/" 2>&1 | tail -2
        
        rm -rf "$TEMP_MIRROR"
        else
            echo "   ⚠️  Skipping Git mirror (no Git repository)"
        fi
        
        # Create FULL directory archive (includes ALL files, even gitignored)
        echo "   📦 Creating full directory archive (includes gitignored files)..."
        TEMP_ARCHIVE="/tmp/${github_repo}-full.tar.gz"
        rm -f "$TEMP_ARCHIVE"
        
        # Create archive excluding only build artifacts, but INCLUDING images/videos/assets
        tar -czf "$TEMP_ARCHIVE" \
            --exclude='.git' \
            --exclude='node_modules' \
            --exclude='venv' \
            --exclude='.venv' \
            --exclude='.wrangler' \
            --exclude='__pycache__' \
            --exclude='.next' \
            --exclude='dist' \
            --exclude='build' \
            --exclude='.DS_Store' \
            -C "$local_path" . 2>&1 | grep -v "^tar:" || true
        
        if [ -f "$TEMP_ARCHIVE" ]; then
            archive_size=$(du -sh "$TEMP_ARCHIVE" | awk '{print $1}')
            echo "   📊 Archive size: $archive_size"
            
            ssh "$PI_HOST" "mkdir -p $PI_FULL_ARCHIVE"
            scp "$TEMP_ARCHIVE" "$PI_HOST:$PI_FULL_ARCHIVE/${github_repo}-full.tar.gz" 2>&1 | tail -1
            
            rm -f "$TEMP_ARCHIVE"
            echo "   ✅ Full archive created (includes gitignored files)"
        else
            echo "   ⚠️  Full archive creation skipped (no files to archive)"
        fi
        
    else
        echo "   ❌ Not found locally, cloning from GitHub..."
        REMOTE="https://github.com/timrecursify/$github_repo.git"
        TEMP_MIRROR="/tmp/${github_repo}.git"
        rm -rf "$TEMP_MIRROR"
        
        git clone --mirror "$REMOTE" "$TEMP_MIRROR" 2>&1 | grep -E "(Cloning|done|error)" || true
        
        echo "   📤 Transferring Git mirror to Pi..."
        ssh "$PI_HOST" "mkdir -p $PI_ARCHIVE"
        rsync -av --delete "$TEMP_MIRROR/" "$PI_HOST:$PI_ARCHIVE/${github_repo}.git/" 2>&1 | tail -2
        
        echo "   ⚠️  Full archive skipped (not available locally - only Git mirror created)"
        echo "   💡 To include gitignored files, archive from local machine"
        
        rm -rf "$TEMP_MIRROR"
    fi
    
    echo "   ✅ Archived: $github_repo"
    echo ""
}

# Process all repos
for repo in "$@"; do
    archive_repo "$repo"
done

echo "✅ Active archive complete"
echo ""
echo "📋 Archive Summary:"
echo "   - Git mirrors: /mnt/ssd/archive/git/projects/ (Git-tracked files only)"
echo "   - Full archives: /mnt/ssd/archive/archived/compressed/projects/ (ALL files including gitignored)"
