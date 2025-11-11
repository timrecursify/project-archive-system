# Project Archive System - Architecture

## Overview

Automated project archiving system running on Raspberry Pi with SSD storage. Archives Git repositories and compressed projects from local machine to Pi, with automatic GitHub synchronization.

## System Components

### 1. Storage Architecture

```
Raspberry Pi (192.168.22.5)
├── SD Card (/dev/mmcblk0p2) - 15GB
│   └── System & Scripts (4.9GB used)
└── SSD (/dev/sda1) - 916GB
    └── /mnt/ssd/archive/ - Main archive directory
        ├── git/projects/        - Bare Git mirrors (45 repos, 100% synced)
        ├── archived/            - Compressed projects (1.9GB)
        │   ├── borg/           - Borg backups
        │   └── compressed/     - Tar archives
        ├── archive.old/         - Historical archives (3.9GB)
        ├── logs/               - System logs
        └── metadata/           - Project metadata
```

### 2. Integrated Archive System Architecture

```
GitHub (Source of Truth)
    ↓ [hourly: 0 * * * *]
/usr/local/bin/archive-scripts/github-auto-sync.sh (SD Card)
    ├─ NEW repos → Clone to active archive
    ├─ DELETED repos → Archive to deep storage
    └─ EXISTING repos → Skip (handled by puller)
    ↓
Active Archive (/mnt/ssd/archive/git/projects/) - SSD
    ↑ [hourly: 5 * * * *]
/usr/local/bin/archive-scripts/git-sync-puller.sh (SD Card)
    ├─ git fetch --all --prune
    ├─ Detect new commits
    └─ Update refs
    ↑
Local Machine (Mac)
    ↓ [manual archive]
active-archive-smart.sh
    └─ rsync over SSH
```

**Key Architecture:**
- **Scripts:** SD Card (`/usr/local/bin/archive-scripts/`) - Fast, reliable execution
- **Data:** SSD (`/mnt/ssd/archive/`) - Large capacity storage
- **Logs:** SSD (`/mnt/ssd/logs/`) - USB storage compliant

**Integrated Sync Flow:**
1. **Auto-Discovery (Hourly :00):** `github-auto-sync.sh`
   - Fetches all GitHub repos via `gh CLI`
   - Compares with local archive
   - Clones new repos automatically
   - Archives deleted repos to deep storage
   
2. **Sync Updates (Hourly :05):** `git-sync-puller.sh`
   - Syncs all existing repos
   - Fetches latest commits
   - Detects and logs updates

3. **Health Monitoring (Every 15 min):** `health-check.sh`
   - Checks disk space
   - Verifies last run times
   - Monitors repository counts

4. **Daily Backup (2 AM):** `backup-archive-system.sh`
   - Backs up metadata and state files
   - 7-day retention

### 3. Archive Types & Storage

**Active Archive (Git Mirrors):**
- **Location:** `/mnt/ssd/archive/git/projects/`
- **Format:** Bare Git repositories (`.git` directories)
- **Content:** Git-tracked files only
- **Sync:** Hourly automatic sync from GitHub
- **Purpose:** Active version control mirroring
- **Count:** 45 repositories (100% synced)

**Deep Archive (Compressed):**
- **Location:** `/mnt/ssd/archive/archived/compressed/projects/`
- **Format:** `{repo-name}.tar.gz` (gzip compression)
- **Content:** Bare Git repository (Git-tracked files only)
- **Trigger:** Repository deleted from GitHub (automatic)
- **Purpose:** Long-term storage of deleted repositories
- **Retention:** Indefinite (no automatic deletion)
- **Count:** 66+ archived repositories

**Full Archive (Complete Backup):**
- **Location:** `/mnt/ssd/archive/archived/compressed/projects/`
- **Format:** `{repo-name}-full.tar.gz` (gzip compression)
- **Content:** Complete project directory (ALL files including gitignored)
- **Trigger:** Manual archiving via `active-archive-smart.sh` before local deletion
- **Purpose:** Complete backup including assets, images, videos, .env files
- **Excludes:** `node_modules`, `venv`, `.wrangler`, `__pycache__`, `.next`, `dist`, `build`, `.DS_Store`

**Key Differences:**
| Archive Type | Contains Gitignored Files | Sync Frequency | Use Case |
|--------------|---------------------------|----------------|----------|
| Active (Git Mirror) | ❌ No | Hourly | Active repos on GitHub |
| Deep Archive | ❌ No | N/A (static) | Deleted repos |
| Full Archive | ✅ Yes | N/A (static) | Complete backup before deletion |

### 4. Archive Scripts (Local → Pi)

**Local Machine Scripts** (`~/Projects/.archive/scripts/`):
- `active-archive-smart.sh` - Main archiving script
  - Fetches latest from GitHub
  - Creates bare Git mirror → `/mnt/ssd/archive/git/projects/{repo}.git`
  - Creates full tar.gz → `/mnt/ssd/archive/archived/compressed/projects/{repo}-full.tar.gz`
  - Rsyncs both to Pi over SSH
  - Verifies archive integrity
- `sync-and-archive-active.sh` - Single project archiver
- `active-archive-repos.sh` - Multi-repo archiver

**Raspberry Pi Scripts** (`/usr/local/bin/archive-scripts/`):
- `github-auto-sync.sh` - Auto-discovery and deep archiving
  - Detects new repos → clones to active archive
  - Detects deleted repos → creates deep archive (`{repo}.tar.gz`)
  - Runs hourly at :00
- `git-sync-puller.sh` - Syncs active archives from GitHub
  - Fetches latest commits for all active repos
  - Updates refs in bare repositories
  - Runs hourly at :05

### 5. Authentication

**SSH Keys:**
- Mac → Pi: Standard SSH key in `~/.ssh/config`
- Pi → GitHub: `~/.ssh/id_ed25519` (added to GitHub account)

**Git URLs:**
- Converted from HTTPS to SSH for passwordless fetch
- Format: `git@github.com:timrecursify/repo-name.git`

### 6. Services

**Systemd Services:**
- `restic-rest.service` - Restic backup server
- ~~`github-webhook.service`~~ - Removed (webhooks rejected)

**Cron Jobs:**
- `*/5 * * * * /usr/local/bin/monitor.sh` - System monitoring
- `0 * * * * /usr/local/bin/archive-scripts/github-auto-sync.sh` - Auto-discovery (new/deleted repos)
- `5 * * * * /usr/local/bin/archive-scripts/git-sync-puller.sh` - Sync updates (existing repos)
- `*/15 * * * * /usr/local/bin/archive-scripts/health-check.sh` - Health monitoring
- `0 2 * * * /usr/local/bin/archive-scripts/backup-archive-system.sh` - Daily backups

## Network Configuration

- Pi IP: `192.168.22.5`
- SSH Access: `ssh raspberry-pi` (configured in SSH config)
- No external exposure required

## New Project Handling

### ✅ FULLY AUTOMATED - No Manual Intervention Required

**Current Behavior:**
The `github-auto-sync.sh` script automatically detects and archives all GitHub repositories.

**How It Works:**
1. Runs hourly at :00 (`0 * * * *`)
2. Fetches all GitHub repos via `gh repo list timrecursify`
3. Compares with local archive at `/mnt/ssd/archive/git/projects/`
4. **NEW repos** → Automatically clones as bare mirror
5. **DELETED repos** → Automatically archives to `/mnt/ssd/archive/archived/compressed/projects/`
6. Existing repos → Handled by `git-sync-puller.sh` (runs at :05)

**Result:**
- Create repo on GitHub → Auto-archived within 1 hour ✅
- Delete repo on GitHub → Auto-moved to deep storage within 1 hour ✅
- Push to repo → Auto-synced within 1 hour ✅

**No manual steps needed** - completely automated!

## Key Design Decisions

### Why Cron Puller vs Webhooks?

**Chosen: Cron-based Puller**
- ✅ No internet exposure needed
- ✅ No per-repo webhook configuration
- ✅ Works behind firewall
- ✅ Simple and reliable
- ✅ Automatic for all repos

**Rejected: GitHub Webhooks**
- ❌ Requires exposing Pi to internet
- ❌ Need webhook config for every repo
- ❌ Complex port forwarding/tunneling
- ❌ Security concerns

### Repository Authentication

**Chosen: SSH Keys**
- Passwordless access
- Secure authentication
- Standard Git workflow

**Converted: HTTPS → SSH**
- All GitHub repos converted to SSH URLs
- Allows `git fetch` without authentication prompts

## Data Flow Diagrams

### Archive Creation Flow
```
Developer Machine
    ↓
git fetch/pull (sync with GitHub)
    ↓
Create bare mirror
    ↓
Remove node_modules, .env, etc
    ↓
rsync to Pi over SSH
    ↓
Pi: /mnt/ssd/archive/git/projects/
```

### Complete Automated Flow
```
Hourly :00 - Auto-Discovery
    ↓
github-auto-sync.sh
    ├── Fetch all GitHub repos (gh CLI)
    ├── Compare with local archive
    ├── Clone new repos → /mnt/ssd/archive/git/projects/
    └── Archive deleted repos → /mnt/ssd/archive/archived/compressed/
    ↓
Hourly :05 - Sync Updates
    ↓
git-sync-puller.sh
    ↓
For each *.git in /mnt/ssd/archive/git/projects/
    ├── Check if remote exists
    ├── git fetch --all --prune (30s timeout)
    ├── Compare HEAD vs origin/main
    ├── Log: UPDATED / OK / ERROR (structured JSON)
    └── Continue to next repo
    ↓
Summary: X updated, Y unchanged, Z failed
    ↓
State saved to /mnt/ssd/archive/metadata/puller-state.json
```

## Deep Archiving Process

### Automated Deep Archiving (GitHub Deletion)

**Trigger:** Repository deleted from GitHub  
**Script:** `github-auto-sync.sh`  
**Schedule:** Hourly at :00 (`0 * * * *`)

**Process:**
1. Script detects repo exists locally but not on GitHub
2. Creates compressed archive: `tar -czf {repo}.tar.gz -C /mnt/ssd/archive/git/projects/ {repo}.git`
3. Verifies archive integrity: `tar -tzf {repo}.tar.gz`
4. Logs archive creation with size and compression ratio
5. Removes original bare repo: `rm -rf {repo}.git`
6. Archive stored in `/mnt/ssd/archive/archived/compressed/projects/`

**Compression Standards:**
- Format: `tar.gz` (GNU tar with gzip compression)
- Compression level: Default (level 6)
- Verification: Always verify after creation
- Naming: `{repo-name}.tar.gz` (exact GitHub repo name)

### Manual Full Archiving (Local Deletion)

**Trigger:** Manual execution before deleting local project  
**Script:** `active-archive-smart.sh` (on local Mac)

**Process:**
1. User runs: `active-archive-smart.sh {repo-name}`
2. Script fetches latest from GitHub
3. Creates bare Git mirror → `/mnt/ssd/archive/git/projects/{repo}.git`
4. Creates full tar.gz → `/mnt/ssd/archive/archived/compressed/projects/{repo}-full.tar.gz`
   - Includes ALL files (even gitignored)
   - Excludes: `node_modules`, `venv`, build artifacts
5. Rsyncs both to Pi over SSH
6. Verifies archive integrity
7. User can safely delete local project

**When to Use:**
- Before deleting project from local machine
- Project has important gitignored files (images, videos, .env)
- Want complete backup including all assets

## Disaster Recovery

### Archive Recovery Procedures

**Restore Deep Archive (Git-Tracked Files Only):**
```bash
# Extract archive
tar -xzf /mnt/ssd/archive/archived/compressed/projects/{repo}.tar.gz -C /tmp/

# Clone from extracted bare repo
git clone /tmp/{repo}.git {repo}
```

**Restore Full Archive (All Files):**
```bash
# Extract archive
tar -xzf /mnt/ssd/archive/archived/compressed/projects/{repo}-full.tar.gz -C /tmp/

# Copy to local machine
scp -r raspberry-pi:/tmp/{repo} ~/Projects/
```

### SSD Failure Recovery

**Scenario 1: Raspberry Pi SSD Failure**
1. **Active Archives:** Re-clone from GitHub (all repos are on GitHub)
2. **Deep Archives:** Restore from Restic backup (if archived Pi SSD)
3. **Full Archives:** Restore from Restic backup (if archived Pi SSD)

**Scenario 2: GitHub Repository Deleted**
1. **Deep Archive:** Restore from `/mnt/ssd/archive/archived/compressed/projects/{repo}.tar.gz`
2. **Full Archive:** Restore from `/mnt/ssd/archive/archived/compressed/projects/{repo}-full.tar.gz` (if exists)

**Scenario 3: Local Project Deleted**
1. **Git Mirror:** Clone from Pi: `git clone raspberry-pi:/mnt/ssd/archive/git/projects/{repo}.git`
2. **Full Archive:** Extract from Pi: `tar -xzf /mnt/ssd/archive/archived/compressed/projects/{repo}-full.tar.gz`

### Integration with Restic Backups

**Restic Backups:**
- Purpose: Production data backup (VPS → Pi)
- Location: `/mnt/ssd/backups/home/data/restic/`
- Content: Databases, configs, application data
- **Separate from project archives**

**Project Archives:**
- Purpose: Git repository and project code backup
- Location: `/mnt/ssd/archive/`
- Content: Source code, Git history, project assets
- **Separate from Restic backups**

**Key Difference:**
- Restic = Production data backup (databases, configs, logs)
- Archive System = Source code and project backup (Git repos, code, assets)

## Monitoring & Logging

**Production Logging Architecture (USB Storage Compliant):**

```
/mnt/ssd/logs/applications/
├── git-sync-puller/
│   ├── git-sync-puller-YYYY-MM-DD.log (structured JSON)
│   └── cron.log
├── github-auto-sync/
│   ├── github-auto-sync-YYYY-MM-DD.log (structured JSON)
│   └── cron.log
├── health-check/
│   └── cron.log
└── backup/
    └── cron.log

/mnt/ssd/logs/centralized/
└── archive-system-YYYY-MM-DD.jsonl (all logs aggregated)

/mnt/ssd/logs/security/
└── github-api-audit-YYYY-MM-DD.log (API access logs)
```

**State Files:**
- `/mnt/ssd/archive/metadata/github-sync-state.json` - Auto-sync state
- `/mnt/ssd/archive/metadata/puller-state.json` - Puller state
- `/mnt/ssd/archive/metadata/system-health.json` - Health status

**Log Rotation:**
- Application logs: 30 days retention
- Security logs: 90 days retention
- Daily compression
- Configured in `/etc/logrotate.d/archive-system`

**Health Checks:**
```bash
# View logs
tail -f /mnt/ssd/logs/applications/git-sync-puller/git-sync-puller-$(date +%Y-%m-%d).log
tail -f /mnt/ssd/logs/applications/github-auto-sync/github-auto-sync-$(date +%Y-%m-%d).log

# Check state
cat /mnt/ssd/archive/metadata/puller-state.json | jq .
cat /mnt/ssd/archive/metadata/github-sync-state.json | jq .
cat /mnt/ssd/archive/metadata/system-health.json | jq .

# Disk usage
df -h / && df -h /mnt/ssd

# Archive counts
echo "Active archives: $(ls -1 /mnt/ssd/archive/git/projects/*.git 2>/dev/null | wc -l)"
echo "Deep archives: $(ls -1 /mnt/ssd/archive/archived/compressed/projects/*.tar.gz 2>/dev/null | grep -v -- '-full.tar.gz' | wc -l)"
echo "Full archives: $(ls -1 /mnt/ssd/archive/archived/compressed/projects/*-full.tar.gz 2>/dev/null | wc -l)"

# Cron jobs
crontab -l

# Manual tests
/usr/local/bin/archive-scripts/git-sync-puller.sh
/usr/local/bin/archive-scripts/github-auto-sync.sh
/usr/local/bin/archive-scripts/health-check.sh

# Verify archive integrity (sample)
cd /mnt/ssd/archive/archived/compressed/projects/
tar -tzf $(ls *.tar.gz | head -1) > /dev/null && echo "✅ Sample archive OK" || echo "❌ Sample archive CORRUPTED"
```

## Related Documentation

- **[DEEP_ARCHIVING_STANDARDS.md](./DEEP_ARCHIVING_STANDARDS.md)** - Complete deep archiving standards and procedures
- **[ARCHIVE_SYSTEM_STATUS.md](./ARCHIVE_SYSTEM_STATUS.md)** - Current system status and metrics
- **[backup-restore.md](../../../rules/bundles/deep/backup-restore.md)** - Restic backup procedures (separate system)
- **[RASPBERRY_PI_INFRASTRUCTURE.md](./RASPBERRY_PI_INFRASTRUCTURE.md)** - Complete Pi infrastructure reference

