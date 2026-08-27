#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID:-$(id -u)}" -eq 0 ]; then
  echo "Run this as your normal sudo-capable user, not directly as root." >&2
  exit 1
fi

. /etc/os-release
case "${ID:-}" in
  ubuntu)
    REPO_OS=ubuntu
    CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
    ;;
  debian|raspbian)
    REPO_OS=debian
    CODENAME="${VERSION_CODENAME:-}"
    ;;
  *)
    echo "Unsupported OS ID '${ID:-unknown}'. Install Docker Engine + Compose plugin manually." >&2
    exit 1
    ;;
esac

if [ -z "$CODENAME" ]; then
  echo "Could not determine Debian/Ubuntu codename." >&2
  exit 1
fi

sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg git python3 openssl unzip
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL "https://download.docker.com/linux/$REPO_OS/gpg" | sudo tee /etc/apt/keyrings/docker.asc >/dev/null
sudo chmod a+r /etc/apt/keyrings/docker.asc
ARCH="$(dpkg --print-architecture)"
echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$REPO_OS $CODENAME stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"

echo
echo "Docker installed. Log out and back in once so your docker group membership takes effect."
echo "Then return here and run: ./setup.sh"
