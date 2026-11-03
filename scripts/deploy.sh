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

curl --fail --retry 10 --retry-delay 1 --retry-connrefused \
  http://127.0.0.1:8080/health
