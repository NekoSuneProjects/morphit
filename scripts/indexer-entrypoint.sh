#!/bin/sh
set -eu

echo "Waiting for PostgreSQL..."
until pg_isready -h postgres -p 5432 -U morphit_indexer -d morphit_indexer >/dev/null 2>&1; do
  sleep 2
done

echo "Running Morphit indexer migrations..."
gosu node npm run migrate -w apps/indexer

echo "Starting Morphit indexer..."
exec gosu node npm run start -w apps/indexer
