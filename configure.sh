#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

if [ ! -f .env ]; then
  cp .env.example .env
fi

read -rp "Public Morphit hostname (example: morphit.example.com): " HOSTNAME
HOSTNAME="${HOSTNAME#https://}"
HOSTNAME="${HOSTNAME#http://}"
HOSTNAME="${HOSTNAME%/}"
if [[ ! "$HOSTNAME" =~ ^[A-Za-z0-9.-]+$ ]] || [[ "$HOSTNAME" != *.* ]]; then
  echo "That does not look like a valid hostname." >&2
  exit 1
fi

read -rp "Morphit/BLURT operator account: " OPERATOR
if [ -z "$OPERATOR" ]; then echo "Operator account is required." >&2; exit 1; fi
read -rp "Fee recipient account [$OPERATOR]: " FEE
FEE="${FEE:-$OPERATOR}"
read -rp "Relay account [$OPERATOR]: " RELAY_ACCOUNT
RELAY_ACCOUNT="${RELAY_ACCOUNT:-$OPERATOR}"

read -rsp "Cloudflare Tunnel token: " CF_TOKEN
echo
if [ -z "$CF_TOKEN" ]; then echo "Cloudflare Tunnel token is required." >&2; exit 1; fi

read -rsp "Morphit relay active private key (WIF): " RELAY_KEY
echo
if [ -z "$RELAY_KEY" ]; then echo "Relay active key is required." >&2; exit 1; fi

DB_PASSWORD="$(openssl rand -hex 32)"

python3 - "$ROOT_DIR/.env" "$HOSTNAME" "$OPERATOR" "$FEE" "$RELAY_ACCOUNT" "$DB_PASSWORD" "$CF_TOKEN" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
vals={
'MORPHIT_HOSTNAME':sys.argv[2],
'MORPHIT_OPERATOR_ACCOUNT':sys.argv[3],
'MORPHIT_FEE_RECIPIENT':sys.argv[4],
'MORPHIT_RELAY_ACCOUNT':sys.argv[5],
'MORPHIT_DB_PASSWORD':sys.argv[6],
'CLOUDFLARE_TUNNEL_TOKEN':sys.argv[7],
}
lines=p.read_text(encoding='utf-8').splitlines()
out=[]
seen=set()
for line in lines:
    if '=' in line and not line.lstrip().startswith('#'):
        k=line.split('=',1)[0]
        if k in vals:
            out.append(f'{k}={vals[k]}')
            seen.add(k)
            continue
    out.append(line)
for k,v in vals.items():
    if k not in seen:
        out.append(f'{k}={v}')
p.write_text('\n'.join(out)+'\n',encoding='utf-8')
PY

umask 077
printf '%s\n' "$RELAY_KEY" > secrets/relay-active.key
chmod 600 .env secrets/relay-active.key
unset RELAY_KEY CF_TOKEN DB_PASSWORD

echo
echo "Configuration saved securely to .env and secrets/relay-active.key"
echo "Cloudflare origin service for this tunnel must be: http://web:8080"
