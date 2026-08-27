#!/bin/sh
set -eu

SOURCE_KEY=/run/host-secrets/relay-active.key
RUNTIME_KEY=/run/morphit/relay-active.key

if [ ! -s "$SOURCE_KEY" ]; then
  echo "ERROR: relay active key is missing. Run ./configure.sh." >&2
  exit 1
fi

install -d -m 0700 -o node -g node /run/morphit
install -m 0400 -o node -g node "$SOURCE_KEY" "$RUNTIME_KEY"
install -d -m 0700 -o node -g node /var/lib/morphit-relay

echo "Starting Morphit relay..."
exec gosu node npm run start -w apps/relay
