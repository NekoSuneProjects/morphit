#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT_DIR/morphit-src"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FORGEJO_API="https://git.agorise.net/api/v1/repos/agorise/morphit/releases/latest"
GITHUB_MIRROR="https://github.com/Agorise/morphit.git"
REF="${MORPHIT_REF:-}"
RELEASE_JSON="$TMP/release.json"
SOURCE_TYPE=""

if curl -fsSL "$FORGEJO_API" -o "$RELEASE_JSON"; then
  if [ -z "$REF" ]; then
    REF="$(python3 - "$RELEASE_JSON" <<'PY'
import json,sys
try:
    d=json.load(open(sys.argv[1],encoding='utf-8'))
    print(d.get('tag_name') or '')
except Exception:
    print('')
PY
)"
  fi

  # Prefer an explicitly attached Morphit release archive because it may contain
  # the canonical shipped frontend that source archives intentionally omit.
  ASSET_URL="$(python3 - "$RELEASE_JSON" <<'PY'
import json,re,sys
try:
    d=json.load(open(sys.argv[1],encoding='utf-8'))
except Exception:
    print(''); raise SystemExit
assets=d.get('assets') or []
for a in assets:
    name=(a.get('name') or '').lower()
    url=a.get('browser_download_url') or ''
    if 'morphit' in name and re.search(r'\.(tar\.gz|tgz|zip)$',name) and not re.search(r'(sha|checksum|sig)',name):
        print(url); break
else:
    print('')
PY
)"

  if [ -n "$ASSET_URL" ]; then
    echo "Trying Morphit release asset: $ASSET_URL"
    case "$ASSET_URL" in
      *.zip)
        if command -v unzip >/dev/null 2>&1; then
          curl -fL "$ASSET_URL" -o "$TMP/release.zip"
          mkdir -p "$TMP/release"
          unzip -q "$TMP/release.zip" -d "$TMP/release"
        fi
        ;;
      *)
        curl -fL "$ASSET_URL" -o "$TMP/release.tar.gz"
        mkdir -p "$TMP/release"
        tar -xzf "$TMP/release.tar.gz" -C "$TMP/release"
        ;;
    esac

    if [ -d "$TMP/release" ]; then
      CANDIDATE="$(find "$TMP/release" -type f -name package.json -print | while read -r p; do d="$(dirname "$p")"; if [ -d "$d/apps/web" ] && [ -d "$d/apps/indexer" ] && [ -d "$d/apps/relay" ]; then printf '%s\n' "$d"; break; fi; done)"
      if [ -n "$CANDIDATE" ]; then
        rm -rf "$DEST"
        mkdir -p "$DEST"
        cp -a "$CANDIDATE"/. "$DEST"/
        SOURCE_TYPE="release-asset"
      fi
    fi
  fi
fi

if [ -z "$REF" ]; then
  REF="main"
fi

if [ -z "$SOURCE_TYPE" ]; then
  echo "Fetching Morphit $REF using a shallow sparse checkout..."
  CLONE_DIR="$TMP/repo"
  if ! git clone --filter=blob:none --depth 1 --branch "$REF" --no-checkout "$GITHUB_MIRROR" "$CLONE_DIR"; then
    echo "Tag/ref '$REF' was unavailable on the mirror; falling back to main." >&2
    rm -rf "$CLONE_DIR"
    REF="main"
    git clone --filter=blob:none --depth 1 --branch main --no-checkout "$GITHUB_MIRROR" "$CLONE_DIR"
  fi
  git -C "$CLONE_DIR" sparse-checkout init --cone
  git -C "$CLONE_DIR" sparse-checkout set apps packages scripts ops
  git -C "$CLONE_DIR" checkout
  rm -rf "$DEST"
  mkdir -p "$DEST"
  cp -a "$CLONE_DIR"/. "$DEST"/
  rm -rf "$DEST/.git"
  SOURCE_TYPE="sparse-source"
fi

if [ ! -f "$DEST/package.json" ] || [ ! -f "$DEST/package-lock.json" ] || [ ! -d "$DEST/apps/indexer" ] || [ ! -d "$DEST/apps/relay" ] || [ ! -d "$DEST/apps/web" ]; then
  echo "ERROR: downloaded Morphit source/package is incomplete." >&2
  exit 1
fi

cat > "$DEST/.deployment-source-info" <<INFO
ref=$REF
source_type=$SOURCE_TYPE
fetched_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
canonical_web_build=$([ -f "$DEST/apps/web/build/.shipped" ] && echo yes || echo no)
INFO

echo "Morphit source ready: $DEST"
cat "$DEST/.deployment-source-info"
if [ ! -f "$DEST/apps/web/build/.shipped" ]; then
  echo "NOTE: canonical shipped frontend bytes are absent. Docker will use Morphit's local-test web build fallback." >&2
fi
