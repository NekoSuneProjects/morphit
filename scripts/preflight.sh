#!/usr/bin/env bash
set -euo pipefail

fail=0
for cmd in docker git curl python3 openssl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    fail=1
  fi
done

if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose plugin is missing (docker compose)." >&2
  fail=1
fi

arch="$(uname -m)"
case "$arch" in
  aarch64|arm64)
    echo "Architecture: $arch (ARM64) OK"
    ;;
  *)
    echo "WARNING: detected $arch. This package is tuned for ARM64 Raspberry Pi." >&2
    ;;
esac

if [ "$fail" -ne 0 ]; then
  echo "Run ./install-docker.sh on Raspberry Pi OS/Debian/Ubuntu, then log out/in if required." >&2
  exit 1
fi
