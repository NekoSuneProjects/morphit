# Secrets

`configure.sh` writes the Morphit relay active key to `relay-active.key` here.

Never commit, upload, paste, or share that key or your `.env` file. The compose stack
mounts the key read-only and copies it into a private tmpfs with mode `0400` before
starting the relay.
