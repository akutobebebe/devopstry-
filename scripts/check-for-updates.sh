#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

git fetch --quiet origin main

current_commit="$(git rev-parse HEAD)"
latest_commit="$(git rev-parse FETCH_HEAD)"

if [[ "$current_commit" == "$latest_commit" ]]; then
  echo "No new commit; deployment skipped."
  exit 0
fi

echo "New commit found; deploying."
"$PROJECT_DIR/scripts/deploy.sh"
