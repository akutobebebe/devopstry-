#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

git pull --ff-only origin main
sudo docker build -t devops-playground .
sudo docker rm -f devops-app 2>/dev/null || true
sudo docker run -d \
  --name devops-app \
  --restart unless-stopped \
  -p 8080:8080 \
  devops-playground

for attempt in {1..15}; do
  if curl --fail --silent http://127.0.0.1:8080/health; then
    printf '\n'
    exit 0
  fi
  sleep 1
done

echo "The app did not become healthy. Recent container logs:" >&2
sudo docker logs --tail 50 devops-app >&2
exit 1
