#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

docker compose ps

echo
if docker compose exec -T web wget -qO- http://127.0.0.1:8080/healthz >/dev/null 2>&1; then
  echo "Internal web health: OK"
else
  echo "Internal web health: NOT READY"
fi

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
  if [ -n "${MORPHIT_HOSTNAME:-}" ]; then
    echo "Public URL: https://${MORPHIT_HOSTNAME}"
    if curl -fsS --max-time 10 "https://${MORPHIT_HOSTNAME}/v1/health" >/dev/null 2>&1; then
      echo "Public /v1/health: OK"
    else
      echo "Public /v1/health: not reachable yet (check Cloudflare route/tunnel and indexer sync)"
    fi
  fi
fi
