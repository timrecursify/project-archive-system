# Archive System Limitations & Solutions

**Created:** 2025-11-09

## Critical Limitation: Gitignored Files

### The Problem

The automated Pi sync system uses `git clone --mirror`, which **only archives Git-tracked files**.

**Files NOT archived by Pi automation:**
- Images/videos in gitignored folders
- Large assets not tracked in Git
- `.env` files
- Database files
- Build artifacts
- Any file listed in `.gitignore`

### The Solution

Updated `active-archive-smart.sh` (2025-11-09) now creates **BOTH**:

1. **Git Mirror** - `/mnt/ssd/archive/git/projects/{repo}.git`
   - Git-tracked files only
   - Used for automated hourly sync
   - Lightweight, fast

2. **Full Archive** - `/mnt/ssd/archive/archived/compressed/projects/{repo}-full.tar.gz`
   - **ALL files** including gitignored
   - Complete backup before deletion
   - Includes: images, videos, .env, assets, everything

### Summary

| Archive Type | Location | Contains | Use Case |
|--------------|----------|----------|----------|
| Git Mirror | `/mnt/ssd/archive/git/projects/` | Git-tracked files only | Automated sync, version control |
| Full Archive | `/mnt/ssd/archive/archived/compressed/projects/` | ALL files (including gitignored) | Complete backup before deletion |

**Both are created automatically when using `active-archive-smart.sh` from local machine.**
