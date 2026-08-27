#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
mkdir -p backups
chmod 700 backups
TS="$(date -u +%Y%m%dT%H%M%SZ)"
DB_FILE="backups/morphit-indexer-${TS}.sql.gz"
RELAY_FILE="backups/morphit-relay-${TS}.tar.gz"

echo "Backing up PostgreSQL -> $DB_FILE"
docker compose exec -T postgres pg_dump --clean --if-exists -U morphit_indexer -d morphit_indexer | gzip -9 > "$DB_FILE"
chmod 600 "$DB_FILE"

echo "Backing up relay data -> $RELAY_FILE"
docker compose exec -T relay tar -czf - -C /var/lib morphit-relay > "$RELAY_FILE"
chmod 600 "$RELAY_FILE"

KEEP="${BACKUP_KEEP:-14}"
find backups -maxdepth 1 -type f -name 'morphit-indexer-*.sql.gz' -printf '%T@ %p\n' | sort -nr | tail -n "+$((KEEP+1))" | cut -d' ' -f2- | xargs -r rm -f
find backups -maxdepth 1 -type f -name 'morphit-relay-*.tar.gz' -printf '%T@ %p\n' | sort -nr | tail -n "+$((KEEP+1))" | cut -d' ' -f2- | xargs -r rm -f

echo "Backup complete. Keep an additional encrypted copy off the Pi."
