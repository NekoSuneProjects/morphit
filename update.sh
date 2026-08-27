#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

echo "Creating a backup before updating..."
./backup.sh

echo "Fetching latest Morphit release/source..."
./scripts/fetch-morphit.sh

docker compose config -q
docker compose build --pull
docker compose up -d --remove-orphans
./status.sh || true
