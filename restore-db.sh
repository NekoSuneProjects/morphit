#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
FILE="${1:-}"
if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  echo "Usage: $0 backups/morphit-indexer-YYYYMMDDTHHMMSSZ.sql.gz" >&2
  exit 1
fi
read -rp "This will replace current Morphit DB contents. Type RESTORE to continue: " ANSWER
[ "$ANSWER" = RESTORE ] || { echo "Cancelled."; exit 1; }

docker compose stop indexer relay web
set +e
gunzip -c "$FILE" | docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U morphit_indexer -d morphit_indexer
RC=$?
set -e
docker compose up -d indexer relay web cloudflared
exit "$RC"
