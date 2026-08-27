# Morphit Raspberry Pi ARM64 — Docker + Cloudflare Tunnel

A deployment wrapper for running a Morphit instance on a **64-bit Raspberry Pi** with Docker Compose and a **Cloudflare Tunnel**, so the site can be public without forwarding ports 80/443 from your home router.

> This is an operator deployment wrapper, not an official Morphit prebuilt Docker stack. Morphit's operations documentation treats Docker as an optional/reference deployment because domains, certificates, secrets and hosting layouts differ between operators.

## Architecture

```text
Internet
   |
   v
Cloudflare HTTPS
   |
   | outbound-only tunnel
   v
cloudflared (Docker)
   |
   v
nginx/web :8080 (Docker-only)
   |                    |
   | /v1 + /rss         | /relay
   v                    v
Morphit Indexer       Morphit Relay
   |
   v
PostgreSQL
```

**There are no `ports:` mappings in `docker-compose.yml`.** PostgreSQL, indexer, relay, nginx and cloudflared share a private Docker network. You do not need router port forwarding, DMZ, UPnP mappings, or a static public IPv4 address.

## Recommended Pi

- Raspberry Pi 4/5 with a **64-bit** Raspberry Pi OS or Ubuntu.
- 4 GB RAM is a practical minimum; 8 GB is preferable.
- 2+ CPU cores.
- Use a USB 3 SSD if possible. An HDD can work but PostgreSQL/indexing will be slower.
- Avoid putting the PostgreSQL volume on a low-end microSD card for long-term operation.
- Keep at least 60–80 GB free if you have the space, even if the initial installation uses much less.

Check architecture:

```bash
uname -m
```

Expected on ARM64:

```text
aarch64
```

## 1. Extract the ZIP

```bash
unzip morphit-pi-arm64.zip
cd morphit-pi-arm64
chmod +x *.sh scripts/*.sh
```

If the folder lives on an external SSD, that is ideal. Example:

```text
/mnt/ssd/morphit-pi-arm64
```

Docker's named volumes normally live under Docker's data root. If you need the database itself guaranteed on the external SSD, move Docker's `data-root` to the SSD before starting, or change the Compose volume to a bind mount. See **SSD/HDD storage** below.

## 2. Install Docker (if needed)

For current Raspberry Pi OS/Debian/Ubuntu:

```bash
./install-docker.sh
```

Then **log out and back in** once so membership in the `docker` group applies.

Verify:

```bash
docker version
docker compose version
```

The included installer configures Docker's official Debian/Ubuntu repository rather than using an unofficial package source.

## 3. Create a Cloudflare Tunnel

Your domain must be managed in Cloudflare.

In the Cloudflare dashboard:

1. Go to **Zero Trust / Networks / Tunnels** (the exact navigation wording can change).
2. Create a **Cloudflared** tunnel, for example `morphit-home`.
3. Choose a remotely managed connector and copy its **tunnel token**.
4. Do not run a second `cloudflared service install` on the Pi; this package runs `cloudflared` as a Docker container.

Keep that token secret.

## 4. Configure Morphit

Run:

```bash
./configure.sh
```

It asks for:

- Public hostname, e.g. `morphit.example.com`
- Morphit/BLURT operator account
- Fee recipient account
- Relay account
- Cloudflare Tunnel token
- Morphit relay active private key (WIF)

It automatically generates a random 256-bit hex PostgreSQL password. Hex is intentionally used because current Morphit indexer configuration requires the password inside its PostgreSQL connection URL; URL-sensitive characters are therefore avoided.

Secrets are written to:

```text
.env
secrets/relay-active.key
```

Both are excluded by `.gitignore`. Do not share them.

## 5. Add the Cloudflare Published Application

For the tunnel you created, add a published application/hostname:

```text
Public hostname: morphit.example.com
Service type:    HTTP
Origin service:  http://web:8080
```

`web` is the Docker Compose service name. Because `cloudflared` is in the same Docker network, it can resolve that name directly.

**Do not use `localhost:8080` in Cloudflare's origin setting.** Inside the cloudflared container, `localhost` means the cloudflared container itself. Use:

```text
http://web:8080
```

Do **not** forward ports 80 or 443 on your router.

## 6. Build and start everything

The one-command path is:

```bash
./setup.sh
```

It will:

1. Verify ARM64/tools/Docker.
2. Run configuration if needed.
3. Fetch the newest Morphit release metadata.
4. Prefer a Morphit release archive if an upstream archive is attached.
5. Otherwise perform a shallow sparse checkout of the Morphit source mirror.
6. Build the Node 22 indexer/relay image.
7. Build the Morphit frontend + nginx image.
8. Start PostgreSQL, indexer, relay, web and cloudflared.

Then check:

```bash
./status.sh
```

And logs:

```bash
./logs.sh
```

Specific service:

```bash
docker compose logs -f indexer
docker compose logs -f relay
docker compose logs -f cloudflared
```

## Frontend integrity / canonical shipped build

Morphit distinguishes its canonical, prebuilt shipped frontend from an operator's local rebuild. The fetch script therefore prefers an attached release package if one is available and contains:

```text
apps/web/build/.shipped
```

If those canonical bytes are absent, the Dockerfile deliberately uses Morphit's own explicit local-test build path:

```bash
npm run build:local-test -w apps/web
```

That gives you a functioning local deployment but **is not guaranteed to be byte-identical to the canonical upstream shipped frontend**. Before presenting a fee-earning public instance as a canonical Morphit deployment, verify the current Morphit release/operator documentation and use the upstream canonical shipped package when provided.

You can see what was fetched with:

```bash
cat morphit-src/.deployment-source-info
```

The web image also contains:

```text
/var/www/morphit/.deployment-build-source
```

with either `canonical-shipped` or `local-test-rebuild`.

## No exposed home ports

The Compose file intentionally has no host port mappings. You can confirm:

```bash
docker compose ps
```

You should not see public mappings such as:

```text
0.0.0.0:5432->5432
0.0.0.0:8080->8080
0.0.0.0:8081->8081
```

Traffic path is only:

```text
Cloudflare -> cloudflared -> web -> indexer/relay
```

The connector establishes its connection outbound from your Pi.

## SSD/HDD storage

An HDD is usable, but an SSD is strongly preferable for PostgreSQL and indexing.

If Docker currently stores data on the microSD card:

```bash
docker info | grep 'Docker Root Dir'
```

For long-term operation, move Docker's data root to an SSD before creating the Morphit volumes. A typical `/etc/docker/daemon.json` is:

```json
{
  "data-root": "/mnt/ssd/docker-data"
}
```

Then:

```bash
sudo systemctl stop docker
sudo mkdir -p /mnt/ssd/docker-data
sudo rsync -aHAXx /var/lib/docker/ /mnt/ssd/docker-data/
sudo systemctl start docker
docker info | grep 'Docker Root Dir'
```

Only do this when you understand where your existing Docker data lives, especially if the Pi already hosts other applications.

## Backups

Create a database + relay-data backup:

```bash
./backup.sh
```

Files are placed in `backups/` and mode `0600`. By default the script keeps the newest 14 database backups and 14 relay-data backups.

Override retention:

```bash
BACKUP_KEEP=30 ./backup.sh
```

**Keep another encrypted copy somewhere off the Pi.** A backup on the same HDD/SSD does not protect against disk failure.

Restore a PostgreSQL backup:

```bash
./restore-db.sh backups/morphit-indexer-YYYYMMDDTHHMMSSZ.sql.gz
```

The restore script requires typing `RESTORE` and temporarily stops the public Morphit services.

## Updating Morphit

```bash
./update.sh
```

This creates a backup first, fetches the newest release/source, rebuilds images and restarts the stack.

For a specific Morphit git tag/ref:

```bash
MORPHIT_REF=vX.Y.Z ./scripts/fetch-morphit.sh
docker compose build
docker compose up -d
```

Review Morphit release notes before production updates because environment variables or migrations can change between versions.

## Useful commands

Start:

```bash
./start.sh
```

Stop without deleting data:

```bash
./stop.sh
```

Status:

```bash
./status.sh
```

Follow logs:

```bash
./logs.sh
```

Restart one service:

```bash
docker compose restart relay
```

See containers:

```bash
docker compose ps
```

Destroy containers but keep named volumes:

```bash
docker compose down
```

**Danger — deletes the database and relay named volumes:**

```bash
# DO NOT run this unless you intentionally want to erase persistent Morphit data.
docker compose down -v
```

## Security decisions in this package

- No host port mappings.
- PostgreSQL only exists on the private Docker network.
- Indexer and relay only exist on the private Docker network.
- Cloudflare terminates public HTTPS.
- Relay active private key is stored outside the image and copied to a mode-`0400` tmpfs file at runtime.
- `.env`, relay key, fetched source and backups are ignored by Git.
- Cloudflared drops Linux capabilities and runs with a read-only root filesystem.
- PostgreSQL's application role has superuser/create-db/create-role/replication privileges removed after initial database creation.
- Docker JSON logs are rotated (`10 MB x 3`) to avoid uncontrolled disk growth.

## Troubleshooting

### Cloudflare shows 502

Check:

```bash
docker compose ps
./logs.sh
```

Make sure the Cloudflare origin is exactly:

```text
http://web:8080
```

not `localhost` and not your Pi's LAN IP.

### cloudflared keeps restarting

Usually the tunnel token is invalid/expired or the `.env` value is wrong:

```bash
docker compose logs --tail=100 cloudflared
```

Re-run:

```bash
./configure.sh
```

if you need to replace the token.

### indexer won't start

```bash
docker compose logs --tail=150 postgres indexer
```

The entrypoint waits for PostgreSQL and runs current Morphit migrations before starting the indexer.

### relay says key permissions are unsafe

The host key should be:

```bash
chmod 600 secrets/relay-active.key
```

The container copies it to a private tmpfs and sets mode `0400` for the Node user.

### Pi runs out of RAM

Stop unrelated containers and consider adding an SSD-backed swap file. Avoid aggressive swapping to microSD. An 8 GB Pi is more comfortable for a public instance.

## Upstream references

Morphit canonical repository / documentation:

- https://git.agorise.net/agorise/morphit
- https://git.agorise.net/agorise/morphit/src/branch/main/docs/OPERATIONS.md

GitHub mirror used as the sparse-clone fallback:

- https://github.com/Agorise/morphit

Cloudflare Tunnel documentation:

- https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/

Docker Engine installation documentation:

- https://docs.docker.com/engine/install/

## Important operator note

Running the software does not guarantee trading activity, fee revenue, or profit. Review Morphit's current fee rules, registration requirements, legal implications, backups, key handling, and release documentation before treating the instance as production infrastructure.
