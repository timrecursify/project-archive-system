# Raspberry Pi Archive Scripts

These scripts run on the Raspberry Pi (`/usr/local/bin/archive-scripts/`) on the SD card for fast, reliable execution.

## Scripts

- **`github-auto-sync.sh`** - Auto-discovery (runs hourly at :00)
  - Detects new repos on GitHub → clones to active archive
  - Detects deleted repos → moves to deep archive
  
- **`git-sync-puller.sh`** - Sync updates (runs hourly at :05)
  - Fetches latest commits for all active archives
  - Updates refs in bare repositories

- **`health-check.sh`** - Health monitoring (runs every 15 minutes)
  - Checks disk space
  - Verifies last run times
  - Monitors repository counts

- **`backup-archive-system.sh`** - Daily backups (runs at 2 AM)
  - Backs up metadata and state files
  - 7-day retention

- **`convert-repos-to-ssh.sh`** - Convert HTTPS → SSH URLs (one-time use)
- **`fix-repo-remotes.sh`** - Fix incorrect remote URLs

## Installation

Copy to Raspberry Pi:
```bash
scp -r raspberry-pi-scripts/* raspberry-pi:/usr/local/bin/archive-scripts/
```
