#!/bin/bash
#
# Delete GitHub Repositories
# Usage: ./delete-github-repos.sh <repo1> <repo2> ...
#

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <repo1> <repo2> ..."
    exit 1
fi

for repo in "$@"; do
    echo "🗑️  Deleting repository: $repo"
    if gh repo delete "timrecursify/$repo" --yes 2>&1; then
        echo "   ✅ Deleted: $repo"
    else
        echo "   ❌ Failed to delete: $repo"
    fi
done

echo ""
echo "✅ Deletion process complete"

