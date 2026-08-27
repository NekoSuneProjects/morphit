#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

./scripts/preflight.sh

if [ ! -f .env ] || grep -q '^MORPHIT_DB_PASSWORD=CHANGE_ME' .env 2>/dev/null || [ ! -s secrets/relay-active.key ]; then
  ./configure.sh
fi

./scripts/fetch-morphit.sh

echo "Validating Compose configuration..."
docker compose config -q

echo "Building ARM64-compatible Morphit images..."
docker compose build --pull

echo "Starting Morphit stack..."
docker compose up -d

echo
./status.sh || true

echo
echo "Next: in Cloudflare Tunnel, publish your hostname to service http://web:8080"
echo "Do NOT open router ports 80/443."
