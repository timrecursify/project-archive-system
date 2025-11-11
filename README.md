# Project Archive System

Automated Git repository archiving system running on Raspberry Pi with hourly GitHub synchronization.

## Quick Overview

- **Local Machine:** Development workspace (~19GB projects)
- **Raspberry Pi:** Archive server (192.168.22.5)
  - SD Card: 15GB (37% used) - System
  - SSD: 916GB (3% used) - Archives (6.7GB)
- **GitHub:** Source of truth (50+ repos)

## Current Status

✅ **Operational** - Git sync puller running hourly  
✅ **45 repositories** being monitored  
✅ **All services healthy** - Restic + Git Sync

## Documentation

- **[docs/architecture.md](docs/architecture.md)** - System design, components, data flow
- **[docs/status.md](docs/status.md)** - Current state, health, recent changes
- **[docs/ARCHIVE_LIMITATIONS.md](docs/ARCHIVE_LIMITATIONS.md)** - Gitignored files handling & solutions

## How It Works

```
GitHub Repo (source of truth)
    ↓ [hourly cron pull]
Raspberry Pi (/mnt/ssd/archive/git/projects/)
    ↑ [manual archive]
Local Machine (~/Projects/)
```

1. **Hourly Sync:** Pi pulls updates from GitHub every hour
2. **Manual Archive:** Run script from local machine to add new projects
3. **Automatic Monitoring:** Once archived, Pi keeps it updated

**Last Updated:** 2025-11-11
