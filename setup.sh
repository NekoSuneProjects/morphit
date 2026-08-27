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

echo "Building Morphit images for this host architecture (AMD64 or ARM64)..."
docker compose build --pull

echo "Starting Morphit stack..."
docker compose up -d

echo
./status.sh || true

echo
echo "Multi-arch GHCR images are also published for linux/amd64 and linux/arm64."
echo "Next: in Cloudflare Tunnel, publish your hostname to service http://web:8080"
echo "Do NOT open router ports 80/443."
