# Local Machine Archive Scripts

These scripts run on your local Mac (`~/Projects/.archive/scripts/`) to archive projects to the Raspberry Pi.

## Main Scripts

- **`active-archive-smart.sh`** - Main archiving script
  - Fetches latest from GitHub
  - Creates bare Git mirror → Pi `/mnt/ssd/archive/git/projects/{repo}.git`
  - Creates full tar.gz → Pi `/mnt/ssd/archive/archived/compressed/projects/{repo}-full.tar.gz`
  - Rsyncs both to Pi over SSH
  - Verifies archive integrity

- **`sync-and-archive-active.sh`** - Single project archiver
- **`active-archive-repos.sh`** - Multi-repo archiver
- **`delete-github-repos.sh`** - Cleanup GitHub repos

## Usage

```bash
# Archive a project before deleting
cd ~/Projects/<project>
~/Projects/.archive/scripts/active-archive-smart.sh <project>
```
